import React, { useState, useEffect } from 'react';
import { Mission } from './types';
import { apiService } from './services/api';
import MissionForm from './components/MissionForm';
import MissionList from './components/MissionList';
import StatusIndicator from './components/StatusIndicator';
import './App.css';

const App: React.FC = () => {
  const [missions, setMissions] = useState<Mission[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [serverStatus, setServerStatus] = useState<'online' | 'offline' | 'checking'>('checking');

  // Fetch all missions
  const fetchMissions = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await apiService.getAllMissions();
      setMissions(response.missions);
      setServerStatus('online');
    } catch (err) {
      console.error('Error fetching missions:', err);
      setError('Failed to fetch missions');
      setServerStatus('offline');
    } finally {
      setLoading(false);
    }
  };

  // Check server health
  const checkServerHealth = async () => {
    try {
      await apiService.healthCheck();
      setServerStatus('online');
    } catch (err) {
      setServerStatus('offline');
    }
  };

  // Handle mission creation
  const handleMissionCreated = () => {
    fetchMissions(); // Refresh the mission list
  };

  // Auto-refresh missions every 5 seconds
  useEffect(() => {
    fetchMissions();
    checkServerHealth();
    
    const interval = setInterval(() => {
      fetchMissions();
      checkServerHealth();
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <div className="header-content">
          <h1>🎯 Mission Control System</h1>
          <p>Secure Command and Control Interface</p>
          <StatusIndicator status={serverStatus} />
        </div>
      </header>

      <main className="App-main">
        <div className="container">
          <div className="mission-control-grid">
            {/* Mission Creation Panel */}
            <div className="panel create-mission-panel">
              <h2>📝 Create New Mission</h2>
              <MissionForm onMissionCreated={handleMissionCreated} />
            </div>

            {/* Mission Status Panel */}
            <div className="panel mission-list-panel">
              <div className="panel-header">
                <h2>📊 Mission Status</h2>
                <button 
                  onClick={fetchMissions} 
                  className="refresh-btn"
                  disabled={loading}
                >
                  {loading ? '🔄' : '🔄'} Refresh
                </button>
              </div>
              
              {error && (
                <div className="error-message">
                  ⚠️ {error}
                </div>
              )}
              
              <MissionList missions={missions} loading={loading} />
            </div>
          </div>
        </div>
      </main>

      <footer className="App-footer">
        <p>Mission Control System - Secure Communications Hub</p>
        <p>Active Missions: {missions.length} | Server Status: 
          <span className={`status-text ${serverStatus}`}>{serverStatus.toUpperCase()}</span>
        </p>
      </footer>
    </div>
  );
};

export default App;
