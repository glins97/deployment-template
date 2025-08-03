import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';

function App() {
  const [backendStatus, setBackendStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const backendUrl = process.env.BACKEND_URL || 'http://localhost:8000';

  const checkBackendHealth = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      const response = await axios.get(`${backendUrl}/health/`);
      setBackendStatus(response.data);
    } catch (err) {
      setError('Failed to connect to backend');
      setBackendStatus(null);
    } finally {
      setLoading(false);
    }
  }, [backendUrl]);

  useEffect(() => {
    checkBackendHealth();
  }, [checkBackendHealth]);

  return (
    <div className="App">
      <div className="container">
        <h1>Deployment Template</h1>
        <p>Frontend React application successfully loaded!</p>
        
        <div className={`status-card ${backendStatus ? 'status-ok' : error ? 'status-error' : ''}`}>
          <h3>Backend Status</h3>
          {loading && <p>Checking backend connection...</p>}
          {backendStatus && (
            <div>
              <p><strong>Status:</strong> {backendStatus.status}</p>
              <p><strong>Message:</strong> {backendStatus.message}</p>
            </div>
          )}
          {error && <p><strong>Error:</strong> {error}</p>}
          
          <button onClick={checkBackendHealth} disabled={loading}>
            {loading ? 'Checking...' : 'Check Backend'}
          </button>
        </div>

        <div className="status-card">
          <h3>Environment Info</h3>
          <p><strong>Backend URL:</strong> {backendUrl}</p>
          <p><strong>Build Environment:</strong> {process.env.NODE_ENV}</p>
        </div>
      </div>
    </div>
  );
}

export default App;