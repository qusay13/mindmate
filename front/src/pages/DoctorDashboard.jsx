import React, { useState, useEffect } from 'react';
import { clinicAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import {
  Users, MessageSquare, UserCheck, Clock,
  ChevronRight, AlertCircle, Stethoscope
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const DoctorDashboard = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [patients, setPatients] = useState([]);
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [patientsRes, requestsRes] = await Promise.all([
        clinicAPI.getDoctorPatients(),
        clinicAPI.getRequests()
      ]);
      setPatients(patientsRes.data);
      setRequests(requestsRes.data);
    } catch (err) {
      console.error('Failed to fetch dashboard data', err);
      setError('Could not load patient or request list.');
    } finally {
      setLoading(false);
    }
  };

  const handleAction = async (requestId, action) => {
    try {
      await clinicAPI.handleRequestAction(requestId, action);
      fetchData();
    } catch (err) {
      alert('Failed to process request');
    }
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading Doctor Dashboard...</p>
    </div>
  );

  if (error) return (
    <div className="error-screen fade-in glass-card">
      <AlertCircle size={48} className="error-icon" />
      <h2>Something went wrong</h2>
      <p>{error}</p>
      <button className="btn-primary" onClick={fetchPatients}>Try Again</button>
    </div>
  );

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header">
        <h1>Doctor Dashboard <Stethoscope size={26} style={{ verticalAlign: 'bottom' }} /></h1>
        <p>Welcome back, Dr. {user?.full_name}. Here are your current patients.</p>
      </header>

      {/* Stats Row */}
      <div style={{ display: 'flex', gap: '1.5rem', marginBottom: '2rem', flexWrap: 'wrap' }}>
        {[
          { label: 'Total Patients', value: patients.length, icon: <Users size={22} />, color: '#a78bfa' },
          { label: 'Active Cases', value: patients.filter(p => p.status === 'active').length, icon: <UserCheck size={22} />, color: '#34d399' },
          { label: 'Pending Requests', value: requests.length, icon: <Clock size={22} />, color: '#f97316' },
        ].map((stat) => (
          <div key={stat.label} className="glass-card" style={{
            flex: '1 1 160px',
            padding: '1.25rem 1.5rem',
            display: 'flex',
            alignItems: 'center',
            gap: '1rem',
          }}>
            <div style={{
              width: 48, height: 48, borderRadius: '12px',
              background: `${stat.color}22`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: stat.color, flexShrink: 0
            }}>
              {stat.icon}
            </div>
            <div>
              <div style={{ fontSize: '1.8rem', fontWeight: 800, lineHeight: 1 }}>{stat.value}</div>
              <div style={{ fontSize: '0.82rem', color: '#888', marginTop: '0.2rem' }}>{stat.label}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Pending Requests */}
      <div className="glass-card" style={{ marginBottom: '2rem' }}>
        <div className="card-header">
          <Clock size={18} className="accent" />
          <h3>Pending Connection Requests ({requests.length})</h3>
        </div>
        <div style={{ padding: '1.5rem' }}>
          {requests.length === 0 ? (
            <p style={{ color: '#888', textAlign: 'center' }}>No pending requests.</p>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '1rem' }}>
              {requests.map(req => (
                <div key={req.request_id} style={{
                  padding: '1.25rem', borderRadius: '16px', background: 'rgba(255,255,255,0.03)',
                  border: '1px solid rgba(255,255,255,0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center'
                }}>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '1rem' }}>{req.user_name}</div>
                    <div style={{ fontSize: '0.82rem', color: '#888' }}>{req.user_email}</div>
                    <div style={{ fontSize: '0.7rem', color: '#a78bfa', marginTop: '0.4rem', fontWeight: 600 }}>Type: {req.request_type}</div>
                  </div>
                  <div style={{ display: 'flex', gap: '0.6rem' }}>
                    <button
                      onClick={() => handleAction(req.request_id, 'reject')}
                      style={{ padding: '0.5rem 0.9rem', borderRadius: '10px', border: '1px solid rgba(239, 68, 68, 0.3)', color: '#ef4444', background: 'rgba(239, 68, 68, 0.05)', fontSize: '0.82rem', fontWeight: 600, cursor: 'pointer' }}
                    >
                      Reject
                    </button>
                    <button
                      onClick={() => handleAction(req.request_id, 'accept')}
                      style={{ padding: '0.5rem 0.9rem', borderRadius: '10px', background: '#34d399', color: '#fff', border: 'none', fontSize: '0.82rem', fontWeight: 700, cursor: 'pointer' }}
                    >
                      Accept
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Patients List */}
      <section className="glass-card">
        <div className="card-header">
          <Users size={18} className="accent" />
          <h3>My Patients</h3>
        </div>

        {patients.length === 0 ? (
          <div style={{ padding: '2.5rem', textAlign: 'center', color: '#888' }}>
            <Users size={48} style={{ opacity: 0.2, marginBottom: '1rem' }} />
            <p>No patients linked yet.</p>
          </div>
        ) : (
          <div style={{ marginTop: '1rem' }}>
            {patients.map((patient) => (
              <div key={patient.user_id || patient.id} style={{
                display: 'flex',
                alignItems: 'center',
                padding: '1rem 0',
                borderBottom: '1px solid rgba(255,255,255,0.06)',
                gap: '1rem',
                cursor: 'pointer',
                transition: 'background 0.2s',
                borderRadius: '8px',
                paddingInline: '0.75rem',
              }}
                onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.04)'}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
              >
                <div style={{
                  width: 44, height: 44, borderRadius: '50%',
                  background: 'linear-gradient(135deg, #34d399, #059669)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontWeight: 700, color: '#fff', flexShrink: 0,
                }}>
                  {(patient.full_name || 'P')[0].toUpperCase()}
                </div>
                <div 
                  style={{ flex: 1, cursor: 'pointer' }} 
                  onClick={() => navigate(`/patient/${patient.user_id || patient.id}`)}
                >
                  <div style={{ fontWeight: 600 }}>{patient.full_name || 'Patient'}</div>
                  <div style={{ fontSize: '0.82rem', color: '#888' }}>{patient.email}</div>
                </div>
                <span style={{
                  padding: '0.25rem 0.75rem',
                  borderRadius: '20px',
                  fontSize: '0.78rem',
                  fontWeight: 600,
                  background: patient.status === 'active' ? '#34d39922' : '#f9731622',
                  color: patient.status === 'active' ? '#34d399' : '#f97316',
                }}>
                  {patient.status || 'active'}
                </span>
                <button
                  className="btn-primary"
                  style={{ padding: '0.4rem 0.8rem', borderRadius: '8px', fontSize: '0.82rem', display: 'flex', alignItems: 'center', gap: '0.3rem' }}
                  onClick={() => navigate('/chat')}
                >
                  <MessageSquare size={14} /> Chat
                </button>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
};

export default DoctorDashboard;
