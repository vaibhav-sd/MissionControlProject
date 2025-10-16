import React, { useState } from 'react';
import { CreateMissionRequest } from '../types';
import { apiService } from '../services/api';

interface MissionFormProps {
  onMissionCreated: () => void;
}

const MissionForm: React.FC<MissionFormProps> = ({ onMissionCreated }) => {
  const [formData, setFormData] = useState<CreateMissionRequest>({
    description: ''
  });

  const [loading, setLoading] = useState<boolean>(false);
  const [success, setSuccess] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.description) {
      setError('Please fill in all required fields');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccess(null);

      const response = await apiService.createMission(formData);

      setSuccess(`Mission ${response.mission_id.slice(0, 8)}... created successfully!`);

      setFormData({
        description: ''
      });

      onMissionCreated();

      setTimeout(() => setSuccess(null), 3000);

    } catch (err: any) {
      console.error('Error creating mission:', err);
      setError(err.message || 'Failed to create mission');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mission-form">
      <form onSubmit={handleSubmit}>

        <div className="form-group">
          <label htmlFor="description">Mission Description</label>
          <textarea
            id="description"
            name="description"
            value={formData.description}
            onChange={handleChange}
            rows={3}
            placeholder="Additional mission details and instructions..."
          />
        </div>

        {error && (
          <div className="error-message">
            ⚠️ {error}
          </div>
        )}

        {success && (
          <div className="success-message">
            ✅ {success}
          </div>
        )}

        <button
          type="submit"
          className="submit-btn"
          disabled={loading}
        >
          {loading ? '⏳ Creating Mission...' : '🚀 Deploy Mission'}
        </button>
      </form>
    </div>
  );
};

export default MissionForm;
