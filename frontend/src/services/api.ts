import axios from 'axios';
import { CreateMissionRequest, CreateMissionResponse, MissionStatusResponse, MissionsListResponse } from '../types';

const API_BASE_URL = 'http://localhost:5000';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for logging
api.interceptors.request.use(
  (config) => {
    console.log(`Making ${config.method?.toUpperCase()} request to ${config.url}`);
    return config;
  },
  (error) => {
    console.error('Request error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    console.error('Response error:', error);
    if (error.response?.status === 500) {
      throw new Error('Server error - please try again later');
    } else if (error.response?.status === 404) {
      throw new Error('Resource not found');
    } else if (error.code === 'ECONNREFUSED') {
      throw new Error('Cannot connect to server - please check if the backend is running');
    }
    throw error;
  }
);

export const apiService = {
  // Create a new mission
  createMission: async (missionData: CreateMissionRequest): Promise<CreateMissionResponse> => {
    try {
      const response = await api.post<CreateMissionResponse>('/missions', missionData);
      return response.data;
    } catch (error) {
      console.error('Error creating mission:', error);
      throw error;
    }
  },

  // Get mission status by ID
  getMissionStatus: async (missionId: string): Promise<MissionStatusResponse> => {
    try {
      const response = await api.get<MissionStatusResponse>(`/missions/${missionId}`);
      return response.data;
    } catch (error) {
      console.error('Error getting mission status:', error);
      throw error;
    }
  },

  // Get all missions
  getAllMissions: async (): Promise<MissionsListResponse> => {
    try {
      const response = await api.get<MissionsListResponse>('/missions');
      return response.data;
    } catch (error) {
      console.error('Error getting all missions:', error);
      throw error;
    }
  },

  // Health check
  healthCheck: async (): Promise<any> => {
    try {
      const response = await api.get('/health');
      return response.data;
    } catch (error) {
      console.error('Health check failed:', error);
      throw error;
    }
  }
};

export default apiService;
