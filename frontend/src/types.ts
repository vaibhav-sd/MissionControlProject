export interface Mission {
  mission_id: string;
  status: 'QUEUED' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';
  timestamp: string;
}

export interface MissionData {
  objective: string;
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  location: string;
  assignedUnit: string;
  description: string;
}

export interface CreateMissionRequest {
  description: string;
}

export interface CreateMissionResponse {
  mission_id: string;
  status: string;
  message: string;
}

export interface MissionStatusResponse {
  mission_id: string;
  status: string;
  timestamp: string;
}

export interface MissionsListResponse {
  missions: Mission[];
}
