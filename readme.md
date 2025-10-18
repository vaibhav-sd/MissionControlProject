# Mission Control Project
Commander's Camp is a distributed mission management system that allows clients to submit, monitor, and track the progress of military-style missions in a simulated environment. It features asynchronous processing, persistent status tracking, token-based authentication, and simulated mission execution outcomes with a React-based frontend.

![System Overview](https://github.com/vaibhav-sd/MissionControlProject/blob/master/images/frontend.png)
*Figure 1: frontend

---

## Setup Instructions


### Quick Start

1. **Start the application using Docker Compose:**
   ```bash
   docker-compose up --build
   ```

2. **Access the application:**
   - Frontend: http://localhost:3000
   - API: http://localhost:5000

![Docker Services](https://github.com/vaibhav-sd/MissionControlProject/blob/master/images/docker.png)
*Figure 2: Docker Compose Services Running*

### Services Overview

The application consists of the following services:
- **Commander (API)**: Flask API server running on port 5000
- **Soldier Workers**: 3 replicated worker instances for processing missions
- **Redis**: In-memory data store for mission status persistence
- **RabbitMQ**: Message broker for asynchronous communication
- **Frontend**: React application running on port 3000

### Health Check
Verify all services are running:
```bash
http://localhost:5000/health
```

![Health Check Response](https://github.com/vaibhav-sd/MissionControlProject/blob/master/images/health_check.png)
*Figure 3: API Health Check Response*

---

##  API Documentation

### Base URL
`http://localhost:5000`

### Authentication
The API uses token-based authentication with automatic token rotation every 30 seconds.

#### `POST /auth/token`
**Description:** Generate a new authentication token

### Core Endpoints

#### `GET /health`
**Description:** Health check for all services

#### `POST /missions`
**Description:** Submit a new mission request. The mission will be queued for execution by a worker.

![Health Check Response](https://github.com/vaibhav-sd/MissionControlProject/blob/master/images/creating_mission.png)
*Figure 4: Mission Creation*

#### `GET /missions`
**Description:** Get a list of all missions and their current status

![Health Check Response](https://github.com/vaibhav-sd/MissionControlProject/blob/master/images/getting_mission_info.png)
*Figure 5: Mission Info*


#### `GET /missions/{mission_id}`
**Description:** Get the status of a specific mission

### Mission Status Flow
1. **QUEUED**: Mission received and queued for processing
2. **IN_PROGRESS**: Worker has started executing the mission
3. **COMPLETED**: Mission executed successfully
4. **FAILED**: Mission execution failed


#### Technology Decisions

| Component | Technology | Rationale |
|-----------|------------|----------|
| **API Framework** | Flask | Lightweight, minimal overhead, extensive ecosystem |
| **Persistence** | Redis | In-memory performance, built-in data structures, pub/sub capabilities |
| **Frontend** | React + TypeScript | Component-based architecture, type safety, rich ecosystem |
| **Containerization** | Docker | Consistent deployment, service isolation, easy scaling |
| **Message Format** | JSON | Language-agnostic, human-readable, widespread support |
| **Worker Scaling** | Docker Compose Replicas | Simple horizontal scaling without orchestration complexity |



### Message Queue: RabbitMQ
**Rationale for RabbitMQ Selection:**
- **Reliability**: Guarantees message delivery with durable queues and acknowledgments - critical for mission-critical operations
- **Security**: Messages are persisted and can survive node failures, ensuring no mission orders are lost
- **Scalability**: Supports multiple worker instances for horizontal scaling across battlefield units
- **Battle-tested**: Industry standard with extensive documentation and proven reliability in production environments

**RabbitMQ Configuration Details:**
- **Queue Durability**: All queues are marked as durable, surviving broker restarts
- **Message Persistence**: Messages are persisted to disk before acknowledgment
- **Connection Management**: Automatic reconnection with exponential backoff for network resilience
- **Quality of Service**: Prefetch limits prevent worker overloading during high-volume operations

**Queue Architecture:**
```
Commander's Camp API
        ↓ (publishes missions)
    orders_queue (durable)
        ↓ (consumed by)
    Soldier Workers
        ↓ (publishes status)
    status_queue (durable)
        ↓ (consumed by)
    Commander's Camp API
```


### Authentication & Identity Management: Token-Based with Rotation
**Comprehensive Authentication System:**

**Token Type**: UUID4-based Bearer Tokens
- **Format**: RFC 4122 compliant UUIDs (e.g., `f24d89b6-b8cd-4cbf-83d5-735a2a6d5b5c`)
- **Entropy**: 128-bit cryptographically secure random generation
- **Transmission**: Included in message payloads for verification

**Time to Live (TTL) Configuration:**
- **Token Lifespan**: 30 seconds (configurable via `TOKEN_ROTATION_INTERVAL`)
- **Refresh Interval**: 25 seconds (before expiration to prevent gaps)
- **Grace Period**: 5-second buffer for network latency tolerance

**Rotation Policy Implementation:**

1. **Automatic Token Generation**:
   ```python
   def generate_token():
    token = str(uuid.uuid4())
    expiry = datetime.now() + timedelta(seconds=TOKEN_ROTATION_INTERVAL)
    
    with token_lock:
        active_tokens[token] = expiry
        # Clean up expired tokens
        current_time = datetime.now()
        expired_tokens = [t for t, exp in active_tokens.items() if exp < current_time]
        for expired_token in expired_tokens:
            del active_tokens[expired_token]
    
    print(f"Generated new token: {token[:8]}... (expires at {expiry})")
    return token, expiry
   ```

2. **Worker Token Refresh**:
   - Background thread runs every 25 seconds
   - Proactively requests new tokens before expiration
   - Maintains continuous operation without interruption

3. **Token Validation**:
   ```python
   def is_token_valid(token):
       if token in active_tokens:
           return active_tokens[token] > datetime.now()
       return False
   ```

4. **Security Features**:
   - **Token Cleanup**: Expired tokens automatically removed
   - **Thread Safety**: Token operations protected by threading locks
   - **Logging**: All token operations logged for audit trails
   - **Rejection Handling**: Invalid tokens cause message rejection

**Security Benefits:**
- **Compromise Mitigation**: Short-lived tokens limit exposure window
- **No Persistent Sessions**: Stateless authentication reduces attack surface
- **Automatic Recovery**: Workers automatically recover from token expiration
- **Distributed Security**: Works across multiple worker instances without coordination


###  Architecture Overview
The Commander's Camp system implements a **secure, asynchronous, one-way command architecture** designed for military operations where field units cannot expose public endpoints. The system ensures soldiers are never exposed by waiting for commands through a resilient communication pattern.

![Architecture Diagram](https://github.com/vaibhav-sd/MissionControlProject/blob/master/images/architecture.png)
*Figure 6:  Architecture - Secure Command & Control System*

#### Core Components:

**1. Commander's Camp (Flask API Service)**
- **Role**: Central command center for issuing and tracking missions
- **Responsibilities**:
  - Mission queue management via REST API
  - Authentication token generation and validation
  - Real-time status tracking and persistence
  - Security token rotation enforcement
- **Port**: 5000
- **Technology**: Flask with CORS support for frontend integration

**2. Soldier Workers (Battle Field Units)**
- **Role**: Autonomous field units that execute missions
- **Responsibilities**:
  - Continuous polling of orders queue (no exposed endpoints)
  - Mission execution with simulated battlefield conditions
  - Status reporting through secure message channels
  - Automatic token refresh and rotation handling
- **Scaling**: 3 replicated instances for high availability
- **Technology**: Python with ThreadPoolExecutor for concurrent missions

**3. Central Communications Hub (Message Broker)**
- **Role**: Secure communication backbone
- **Queues**:
  - `orders_queue`: Commander → Soldiers (mission distribution)
  - `status_queue`: Soldiers → Commander (progress updates)
- **Technology**: RabbitMQ with durable queues and acknowledgments
- **Security**: Within secure territory, no external exposure

**4. Mission Status Persistence (Redis)**
- **Role**: Fast, reliable status tracking
- **Data**: Mission states, timestamps, and metadata
- **Performance**: In-memory operations for real-time updates

**5. Mission Control Dashboard (React Frontend)**
- **Role**: Visual command interface
- **Features**: Real-time mission tracking, status visualization
- **Port**: 3000


### Data Flow
1. **Mission Submission**: Client submits mission via REST API
2. **Queue Publication**: Mission published to `orders_queue` with unique ID
3. **Worker Polling**: Available worker picks up mission from queue
4. **Authentication**: Worker validates token with Commander
5. **Mission Execution**: Worker simulates mission (5-15 seconds)
6. **Status Updates**: Progress published to `status_queue` with token
7. **Status Persistence**: Commander receives updates and persists to Redis
8. **Client Monitoring**: Client polls API for real-time status updates

![Data Flow Diagram](https://github.com/vaibhav-sd/MissionControlProject/blob/master/images/flow.svg)
*Figure 7: System Data Flow*

---
## AI Usage Policy

### AI Tools Used in Development
This project was developed with assistance from AI tools in the following areas:

#### Code Generation and Architecture
- **Initial project structure**: AI assisted in Docker configuration
- **Boilerplate code**: Generated foundational Flask routes, RabbitMQ connection handling, and React components
- **Error handling patterns**: AI suggested robust error handling and retry mechanisms

#### Documentation
- **API documentation**: AI helped structure and format the API endpoint documentation
- **README sections**: Assisted in organizing and writing comprehensive setup instructions along with creation of architecture diagram.