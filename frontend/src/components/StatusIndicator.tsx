import React from 'react';

interface StatusIndicatorProps {
  status: 'online' | 'offline' | 'checking';
}

const StatusIndicator: React.FC<StatusIndicatorProps> = ({ status }) => {
  const getStatusConfig = () => {
    switch (status) {
      case 'online':
        return {
          icon: '🟢',
          text: 'SECURE CONNECTION',
          className: 'status-online'
        };
      case 'offline':
        return {
          icon: '🔴',
          text: 'CONNECTION LOST',
          className: 'status-offline'
        };
      case 'checking':
        return {
          icon: '🟡',
          text: 'CONNECTING...',
          className: 'status-checking'
        };
      default:
        return {
          icon: '❓',
          text: 'UNKNOWN STATUS',
          className: 'status-unknown'
        };
    }
  };

  const config = getStatusConfig();

  return (
    <div className={`status-indicator ${config.className}`}>
      <span className="status-icon">{config.icon}</span>
      <span className="status-text">{config.text}</span>
    </div>
  );
};

export default StatusIndicator;
