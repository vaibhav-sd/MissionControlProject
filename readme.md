# Missino Control Project
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



## AI Usage Policy

### AI Tools Used in Development
This project was developed with assistance from AI tools in the following areas:

#### Code Generation and Architecture
- **Initial project structure**: AI assisted in Docker configuration
- **Boilerplate code**: Generated foundational Flask routes, RabbitMQ connection handling, and React components
- **Error handling patterns**: AI suggested robust error handling and retry mechanisms

#### Documentation
- **API documentation**: AI helped structure and format the API endpoint documentation
- **README sections**: Assisted in organizing and writing comprehensive setup instructions