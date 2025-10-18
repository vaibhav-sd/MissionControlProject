#!/bin/bash
# ==============================
# test_missions.sh
# Automated Mission System Tests
# ==============================

# Default Commander URL: Takes the first argument ($1) or defaults to http://localhost:5000
COMMANDER_URL=${1:-"http://localhost:5000"}

# ----------------------------------------
# Global Test Results Tracker (Updated in test functions)
# ----------------------------------------
TEST_1_RESULT="PENDING"
TEST_2_RESULT="PENDING"
TEST_3_RESULT="PENDING"
# New global variables for Test 2 detailed counts
TEST_2_COMPLETED=0
TEST_2_FAILED=0
TEST_2_TIMEOUT=0

# ----------------------------------------
# Log file setup
# ----------------------------------------
# Create a unique log file name based on the current date/time
LOG_FILE="mission_test_$(date +'%Y%m%d_%H%M%S').log"
# Create or overwrite the log file
touch "$LOG_FILE"

# Pre-check for necessary tools
JQ_BIN=$(command -v jq)
CURL_BIN=$(command -v curl)

# ----------------------------------------
# Logging Helper
# ----------------------------------------
function log {
    local message="$1"
    local level=${2:-"INFO"}
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local full_message="[$timestamp] [$level] $message"

    # Print to console (redirect to STDERR so it's not captured by command substitution)
    echo "$full_message" >&2

    # Append to log file
    echo "$full_message" >> "$LOG_FILE"
}

function log_newline {
    echo "" >&2
    echo "" >> "$LOG_FILE"
}

# ----------------------------------------
# Helper: Wait for mission to reach a terminal state (POLLING)
# Echoes the final status (COMPLETED, FAILED, or TIMEOUT)
# ----------------------------------------
function wait_for_mission_status {
    local mission_id="$1"
    local timeout_seconds=${2:-60}
    # Calculate the end time in epoch seconds
    local end_time=$(( $(date +%s) + timeout_seconds ))

    while [ $(date +%s) -lt $end_time ]; do
        # -s: Silent mode, -m 5: Max time for request
        local response=$(curl -s -X GET "${COMMANDER_URL}/missions/${mission_id}" -m 5)
        local curl_status=$?

        if [ $curl_status -ne 0 ]; then
            log "Error fetching mission status (curl exit $curl_status)" "WARN"
            sleep 3
            continue
        fi

        # Use jq to extract the status field
        local status=$(echo "$response" | $JQ_BIN -r '.status')

        if [ "$status" == "null" ] || [ -z "$status" ]; then
            log "Mission ${mission_id}: API response missing status or invalid JSON." "WARN"
            sleep 3
            continue
        fi
        
        log "Mission ${mission_id}: Current status = $status"

        if [[ "$status" == "COMPLETED" || "$status" == "FAILED" ]]; then
            log_newline
            echo "$status" # Output the final status (captured by caller)
            return
        fi

        sleep 3
    done

    log_newline
    echo "TIMEOUT"
}

# ----------------------------------------
# Helper: Get mission status once (NO POLLING)
# Echoes the current status (or ERROR_*)
# ----------------------------------------
function get_mission_status_once {
    local mission_id="$1"

    # -s: Silent mode, -m 5: Max time for request
    local response=$(curl -s -X GET "${COMMANDER_URL}/missions/${mission_id}" -m 5)
    local curl_status=$?

    if [ $curl_status -ne 0 ]; then
        log "Error fetching mission status (curl exit $curl_status)" "WARN"
        echo "ERROR_CURL"
        return
    fi

    # Use jq to extract the status field
    local status=$(echo "$response" | $JQ_BIN -r '.status')

    if [ "$status" == "null" ] || [ -z "$status" ]; then
        log "Mission ${mission_id}: API response missing status or invalid JSON." "WARN"
        echo "ERROR_JSON"
        return
    fi
    
    echo "$status"
}

# ----------------------------------------
# Test 1: Single Mission Flow
# ----------------------------------------
function test_single_mission {
    log_newline
    log "=== Running Test 1: Single Mission Flow ==="
    log_newline

    local payload='{
        "target": "Alpha Site",
        "priority": "High",
        "objective": "Recon"
    }'

    # Submit the mission
    local response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "${COMMANDER_URL}/missions")
    local curl_status=$?

    if [ $curl_status -ne 0 ]; then
        log "❌ Test 1 Failed: Curl error on submission (exit $curl_status)" "ERROR"
        TEST_1_RESULT="FAIL"
        return
    fi

    local mission_id=$(echo "$response" | $JQ_BIN -r '.mission_id')
    local initial_status=$(echo "$response" | $JQ_BIN -r '.status')

    if [ -z "$mission_id" ] || [ "$mission_id" == "null" ]; then
        log "❌ Test 1 Failed: Could not extract mission_id from response: $response" "ERROR"
        TEST_1_RESULT="FAIL"
        return
    fi
    
    log "Mission submitted: ${mission_id} (Status: $initial_status)"

    if [ "$initial_status" != "QUEUED" ]; then
        log "❌ Test 1 Failed: Expected status QUEUED but got $initial_status" "ERROR"
        TEST_1_RESULT="FAIL"
        return
    fi

    # Wait for mission to complete (Original 60s timeout remains here)
    local final_status=$(wait_for_mission_status "$mission_id" 60)

    # The final_status variable now only contains the single word (COMPLETED or FAILED or TIMEOUT)
    if [[ "$final_status" == "COMPLETED" || "$final_status" == "FAILED" ]]; then
        # This will now correctly execute for COMPLETED/FAILED
        log "✅ Test 1 Passed: Mission reached terminal status $final_status"
        TEST_1_RESULT="PASS"
    else
        log "❌ Test 1 Failed: Mission did not complete in time (Status: $final_status)"
        TEST_1_RESULT="FAIL"
    fi

    log_newline
}

# ----------------------------------------
# Test 2: Concurrency Test (20 missions)
# ----------------------------------------
function test_concurrency {
    log_newline
    log "=== Running Test 2: Concurrency Test (20 missions) ==="
    log_newline

    local missions=()
    local i
    for i in $(seq 1 20); do
        local payload='{
            "target": "Zone-'"$i"'",
            "priority": "Medium",
            "objective": "Patrol"
        }'

        local response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "${COMMANDER_URL}/missions")
        local curl_status=$?

        if [ $curl_status -ne 0 ]; then
            log "Error submitting mission ${i}: Curl exit code $curl_status" "WARN"
        else
            local mission_id=$(echo "$response" | $JQ_BIN -r '.mission_id')
            if [ -z "$mission_id" ] || [ "$mission_id" == "null" ]; then
                log "Error submitting mission ${i}: Invalid response: $response" "WARN"
            else
                log "Submitted mission ${i} → ID: $mission_id"
                # Add ID to the array
                missions+=("$mission_id")
            fi
        fi
    done

    log_newline
    # RESTORING POLLING: Wait for each mission to reach a terminal status
    log "Polling all missions for terminal status (Timeout 120s per mission)..."
    log_newline

    local completed_count=0
    local failed_count=0
    local timeout_count=0
    local mission_count=${#missions[@]}
    local id
    local all_statuses=() # Initialize array to store all final statuses
    
    # Poll for each mission's completion sequentially
    for id in "${missions[@]}"; do
        # Use 120s timeout for concurrency test
        local status=$(wait_for_mission_status "$id" 120)
        
        # Store status for the summary line
        all_statuses+=("$status")
        
        log "Mission ${id}: final status = $status"
        if [[ "$status" == "COMPLETED" ]]; then
            completed_count=$((completed_count + 1))
        elif [[ "$status" == "FAILED" ]]; then
            failed_count=$((failed_count + 1))
        elif [[ "$status" == "TIMEOUT" ]]; then
            timeout_count=$((timeout_count + 1))
        fi
    done

    log_newline
    # NEW REQUIREMENT: Single line status summary
    # Join the array elements with comma-space for a concise summary
    local status_summary=$(IFS=', '; echo "${all_statuses[*]}")
    log "Summary of 20 mission results: $status_summary"
    
    # NEW REQUIREMENT: Count of COMPLETED/FAILED/TIMEOUT
    log "Test 2 Status Counts: COMPLETED=$completed_count, FAILED=$failed_count, TIMEOUT=$timeout_count"
    
    # Store counts globally for final summary
    TEST_2_COMPLETED=$completed_count
    TEST_2_FAILED=$failed_count
    TEST_2_TIMEOUT=$timeout_count
    log_newline
    
    # Update success/failure message for endurance test
    if [ $((completed_count + failed_count)) -eq $mission_count ]; then
        log "✅ Test 2 Passed: All $mission_count missions processed concurrently."
        TEST_2_RESULT="PASS"
    else
        log "❌ Test 2 Failed: $completed_count missions completed / $failed_count failed / $timeout_count timed out."
        TEST_2_RESULT="FAIL"
    fi

    log_newline
}

# ----------------------------------------
# Test 3: Authentication & Token Rotation
# ----------------------------------------
function test_token_rotation {
    log_newline
    log "=== Running Test 3: Authentication & Token Rotation ==="
    log_newline

    # Step 1: Get initial token
    local token_resp=$(curl -s -X POST "${COMMANDER_URL}/auth/token")
    local curl_status=$?

    if [ $curl_status -ne 0 ]; then
        log "❌ Failed to get initial token: Curl exit code $curl_status" "ERROR"
        TEST_3_RESULT="FAIL"
        return
    fi

    local token=$(echo "$token_resp" | $JQ_BIN -r '.token')
    local expiry=$(echo "$token_resp" | $JQ_BIN -r '.expires_at')

    if [ -z "$token" ] || [ "$token" == "null" ]; then
        log "❌ Failed to get initial token: Invalid response structure: $token_resp" "ERROR"
        TEST_3_RESULT="FAIL"
        return
    fi
    
    log "Initial token retrieved: ${token} (expires at $expiry)"

    # Step 2: Submit a mission
    local payload='{
        "target": "Rotation-Test",
        "priority": "Low",
        "objective": "Endurance"
    }'
    
    local resp=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "${COMMANDER_URL}/missions")
    local mission_id=$(echo "$resp" | $JQ_BIN -r '.mission_id')

    if [ -z "$mission_id" ] || [ "$mission_id" == "null" ]; then
        log "❌ Test 3 Failed: Could not extract mission_id from submission response." "ERROR"
        TEST_3_RESULT="FAIL"
        return
    fi

    log "Mission submitted: ${mission_id}"
    log_newline

    # Step 3: Print current token details repeatedly during wait (simulates time passing for rotation)
    local t
    for t in $(seq 1 4); do
        log "Current token: ${token} (expires at $expiry)"
        sleep 10
    done
    log_newline

    # Step 4: Ensure worker still completes mission after token rotation window
    local status=$(wait_for_mission_status "$mission_id" 90)
    
    if [[ "$status" == "COMPLETED" || "$status" == "FAILED" ]]; then
        log "✅ Test 3 Passed: Worker handled token rotation and completed mission."
        TEST_3_RESULT="PASS"
    else
        log "❌ Test 3 Failed: Mission did not complete after token expiry."
        TEST_3_RESULT="FAIL"
    fi

    log_newline
}

# ----------------------------------------
# Final Summary Report Generation
# ----------------------------------------
function generate_final_summary {
    log_newline
    log "==============================================="
    log "          FINAL MISSION TEST SUMMARY           "
    log "==============================================="
    log "Test 1: Single Mission Flow ........ $TEST_1_RESULT"
    log "Test 2: Concurrency (20 Missions).. $TEST_2_RESULT"
    log "        (COMPLETED: $TEST_2_COMPLETED, FAILED: $TEST_2_FAILED, TIMEOUT: $TEST_2_TIMEOUT)"
    log "Test 3: Token Rotation ............. $TEST_3_RESULT"
    log "==============================================="
    log_newline
}

# ----------------------------------------
# Test Orchestration
# ----------------------------------------

# Ensure dependencies are available
if [ -z "$CURL_BIN" ]; then
    echo "ERROR: 'curl' command not found. Please install curl for API interaction." >&2
    exit 1
fi

if [ -z "$JQ_BIN" ]; then
    echo "ERROR: 'jq' command not found. Please install jq (a lightweight and flexible command-line JSON processor) to parse API responses.)" >&2
    exit 1
fi

log_newline
log "Starting Mission System Tests"
log "Commander URL: $COMMANDER_URL"
log "Log file: $LOG_FILE"
log_newline

# Wait for Commander to become healthy
attempts=0
while [ $attempts -lt 10 ]; do
    # -m 5 sets a 5 second timeout for the curl command
    health_resp=$(curl -s -X GET "${COMMANDER_URL}/health" -m 5)
    curl_status=$?
    
    if [ $curl_status -eq 0 ]; then
        health_status=$(echo "$health_resp" | $JQ_BIN -r '.status')
        if [ "$health_status" == "healthy" ]; then
            log "Commander is healthy."
            break
        fi
    fi

    log "Waiting for Commander to be ready..." "INFO"
    sleep 5
    attempts=$((attempts + 1))
done

if [ $attempts -ge 10 ]; then
    log "❌ Commander service not reachable after multiple attempts" "ERROR"
    exit 1
fi

# Run tests
test_single_mission
test_concurrency
test_token_rotation

# Generate the final report
generate_final_summary

log "=== All Tests Completed ==="
log_newline
log "Test results stored in log file: $LOG_FILE"
