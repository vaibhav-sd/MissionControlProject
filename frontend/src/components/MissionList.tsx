import React from 'react';
import { Mission } from '../types';

interface MissionListProps {
  missions: Mission[];
  loading: boolean;
}

const MissionList: React.FC<MissionListProps> = ({ missions, loading }) => {
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'QUEUED': return '⏳';
      case 'IN_PROGRESS': return '🔄';
      case 'COMPLETED': return '✅';
      case 'FAILED': return '❌';
      default: return '❓';
    }
  };

  const getStatusClass = (status: string) => {
    return `status-badge status-${status.toLowerCase()}`;
  };

  const formatTimestamp = (timestamp: string) => {
    try {
      const date = new Date(timestamp);
      return date.toLocaleString();
    } catch {
      return timestamp;
    }
  };

  if (loading && missions.length === 0) {
    return (
      <div className="loading-container">
        <div className="loading-spinner">🔄</div>
        <p>Loading missions...</p>
      </div>
    );
  }

  if (missions.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-icon">📭</div>
        <h3>No Missions Deployed</h3>
        <p>Create a new mission to get started with your operations.</p>
      </div>
    );
  }

  const sortedMissions = [...missions].sort((a, b) => {
    return new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime();
  });

  const statusCounts = missions.reduce((acc, mission) => {
    acc[mission.status] = (acc[mission.status] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  return (
    <div className="mission-list">
      {/* Status Summary */}
      <div className="status-summary">
        <div className="summary-item">
          <span className="summary-label">⏳ Queued:</span>
          <span className="summary-count">{statusCounts.QUEUED || 0}</span>
        </div>
        <div className="summary-item">
          <span className="summary-label">🔄 In Progress:</span>
          <span className="summary-count">{statusCounts.IN_PROGRESS || 0}</span>
        </div>
        <div className="summary-item">
          <span className="summary-label">✅ Completed:</span>
          <span className="summary-count">{statusCounts.COMPLETED || 0}</span>
        </div>
        <div className="summary-item">
          <span className="summary-label">❌ Failed:</span>
          <span className="summary-count">{statusCounts.FAILED || 0}</span>
        </div>
      </div>

      {/* Mission Cards */}
      <div className="missions-container">
        {sortedMissions.map((mission, index) => (
          <div key={mission.mission_id} className="mission-card">
            <div className="mission-header">
              <div className="mission-id">
                <strong>Mission #{index + 1}</strong>
                <span className="mission-uuid">{mission.mission_id.slice(0, 8)}...</span>
              </div>
              <div className={getStatusClass(mission.status)}>
                {getStatusIcon(mission.status)} {mission.status}
              </div>
            </div>
            
            <div className="mission-details">
              <div className="mission-timestamp">
                <span className="timestamp-label">Last Updated:</span>
                <span className="timestamp-value">{formatTimestamp(mission.timestamp)}</span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {loading && (
        <div className="loading-overlay">
          <div className="loading-spinner">🔄</div>
        </div>
      )}
    </div>
  );
};

export default MissionList;
