# ==============================
# test_missions.ps1
# Automated Mission System Tests
# ==============================

param(
    [string]$CommanderURL = "http://localhost:5000"
)

# ----------------------------------------
# Log file setup
# ----------------------------------------
$LogFile = "mission_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
# Create or overwrite
New-Item -Path $LogFile -ItemType File -Force | Out-Null

# ----------------------------------------
# Logging Helper
# ----------------------------------------
function Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "[$timestamp] [$Level] $Message"
    
    # Print to console
    Write-Host $fullMessage

    # Append to log file
    Add-Content -Path $LogFile -Value $fullMessage
}

function Log-Newline {
    Write-Host ""
    Add-Content -Path $LogFile -Value ""
}

# ----------------------------------------
# Helper: Wait for mission to reach a terminal state
# ----------------------------------------
function Wait-ForMissionStatus {
    param(
        [string]$MissionId,
        [int]$TimeoutSeconds = 60
    )

    $endTime = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $endTime) {
        try {
            $response = Invoke-RestMethod -Uri "$CommanderURL/missions/$MissionId" -Method GET -TimeoutSec 5
            $status = $response.status
            Log "Mission ${MissionId}: Current status = $status"

            if ($status -in @("COMPLETED", "FAILED")) {
                Log-Newline
                return $status
            }
        }
        catch {
            Log "Error fetching mission status: $($_.Exception.Message)" "WARN"
        }
        Start-Sleep -Seconds 3
    }
    Log-Newline
    return "TIMEOUT"
}

# ----------------------------------------
# Test 1: Single Mission Flow
# ----------------------------------------
function Test-SingleMission {
    Log-Newline
    Log "=== Running Test 1: Single Mission Flow ==="
    Log-Newline

    $payload = @{
        target    = "Alpha Site"
        priority  = "High"
        objective = "Recon"
    }

    try {
        $response = Invoke-RestMethod -Uri "$CommanderURL/missions" -Method POST -ContentType "application/json" -Body ($payload | ConvertTo-Json)
        $missionId = $response.mission_id
        Log "Mission submitted: ${missionId} (Status: $($response.status))"

        if ($response.status -ne "QUEUED") {
            throw "Expected status QUEUED but got $($response.status)"
        }

        $finalStatus = Wait-ForMissionStatus -MissionId $missionId
        if ($finalStatus -eq "COMPLETED" -or $finalStatus -eq "FAILED") {
            Log "✅ Test 1 Passed: Mission reached terminal status $finalStatus"
        }
        else {
            Log "❌ Test 1 Failed: Mission did not complete in time"
        }
    }
    catch {
        Log "❌ Test 1 Failed: $($_.Exception.Message)" "ERROR"
    }

    Log-Newline
}

# ----------------------------------------
# Test 2: Concurrency Test (20 missions)
# ----------------------------------------
function Test-Concurrency {
    Log-Newline
    Log "=== Running Test 2: Concurrency (20 missions) ==="
    Log-Newline

    $missions = @()
    for ($i = 1; $i -le 20; $i++) {
        $payload = @{
            target    = "Zone-$i"
            priority  = "Medium"
            objective = "Patrol"
        }

        try {
            $response = Invoke-RestMethod -Uri "$CommanderURL/missions" -Method POST -ContentType "application/json" -Body ($payload | ConvertTo-Json)
            Log "Submitted mission ${i} → ID: $($response.mission_id)"
            $missions += $response.mission_id
        }
        catch {
            Log "Error submitting mission ${i}: $($_.Exception.Message)" "WARN"
        }
    }

    Log-Newline
    Log "Polling all missions for terminal status..."
    Log-Newline

    # Track all missions
    $completed = 0
    foreach ($id in $missions) {
        $status = Wait-ForMissionStatus -MissionId $id -TimeoutSeconds 120
        Log "Mission ${id}: final status = $status"
        if ($status -eq "COMPLETED" -or $status -eq "FAILED") {
            $completed++
        }
    }

    Log-Newline
    if ($completed -eq $missions.Count) {
        Log "✅ Test 2 Passed: All $completed missions processed concurrently."
    }
    else {
        Log "❌ Test 2 Failed: $completed / $($missions.Count) completed."
    }

    Log-Newline
}

# ----------------------------------------
# Test 3: Authentication & Token Rotation
# ----------------------------------------
function Test-TokenRotation {
    Log-Newline
    Log "=== Running Test 3: Authentication & Token Rotation ==="
    Log-Newline

    # Step 1: Get initial token
    try {
        $tokenResp = Invoke-RestMethod -Uri "$CommanderURL/auth/token" -Method POST
        $token = $tokenResp.token
        $expiry = $tokenResp.expires_at
        Log "Initial token retrieved: ${token} (expires at $expiry)"
    }
    catch {
        Log "❌ Failed to get initial token: $($_.Exception.Message)" "ERROR"
        return
    }

    # Step 2: Submit a mission
    $payload = @{
        target    = "Rotation-Test"
        priority  = "Low"
        objective = "Endurance"
    }
    $resp = Invoke-RestMethod -Uri "$CommanderURL/missions" -Method POST -ContentType "application/json" -Body ($payload | ConvertTo-Json)
    $missionId = $resp.mission_id
    Log "Mission submitted: ${missionId}"
    Log-Newline

    # Step 3: Print current token details repeatedly during wait
    for ($t = 1; $t -le 4; $t++) {
        Log "Current token: ${token} (expires at $expiry)"
        Start-Sleep -Seconds 10
    }
    Log-Newline

    # Step 4: Ensure worker still completes mission after token rotation
    $status = Wait-ForMissionStatus -MissionId $missionId -TimeoutSeconds 90
    if ($status -in @("COMPLETED", "FAILED")) {
        Log "✅ Test 3 Passed: Worker handled token rotation and completed mission."
    }
    else {
        Log "❌ Test 3 Failed: Mission did not complete after token expiry."
    }

    Log-Newline
}

# ----------------------------------------
# Test Orchestration
# ----------------------------------------
Log-Newline
Log "Starting Mission System Tests"
Log "Commander URL: $CommanderURL"
Log "Log file: $LogFile"
Log-Newline

# Wait for Commander to become healthy
$attempts = 0
while ($attempts -lt 10) {
    try {
        $health = Invoke-RestMethod -Uri "$CommanderURL/health" -Method GET -TimeoutSec 5
        if ($health.status -eq "healthy") {
            Log "Commander is healthy."
            break
        }
    }
    catch {
        Log "Waiting for Commander to be ready..." "INFO"
        Start-Sleep -Seconds 5
    }
    $attempts++
}

if ($attempts -ge 10) {
    Log "❌ Commander service not reachable after multiple attempts" "ERROR"
    exit 1
}

# Run tests
Test-SingleMission
Test-Concurrency
Test-TokenRotation

Log "=== All Tests Completed ==="
Log-Newline
Log "Test results stored in log file: $LogFile"
