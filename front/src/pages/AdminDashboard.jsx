import React, { useState, useEffect } from 'react';
import { clinicAPI, authAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { CheckCircle2, XCircle, AlertCircle, UserCheck, ShieldCheck, Activity, Users, FileText } from 'lucide-react';

const AdminDashboard = () => {
  useAuth();
  const [doctors, setDoctors] = useState([]);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionLoading, setActionLoading] = useState(null);

  const [stats, setStats] = useState(null);
  const [selectedDoctor, setSelectedDoctor] = useState(null);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [doctorsRes, statsRes, usersRes] = await Promise.all([
        clinicAPI.getAdminDoctors(),
        authAPI.getAdminStats(),
        authAPI.getAdminUsers()
      ]);
      setDoctors(Array.isArray(doctorsRes.data) ? doctorsRes.data : (doctorsRes.data?.results || []));
      setStats(statsRes.data);
      setUsers(Array.isArray(usersRes.data) ? usersRes.data : (usersRes.data?.results || []));
    } catch (err) {
      console.error('Failed to fetch admin data', err);
      setError('Could not load admin dashboard data.');
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (id, status) => {
    try {
      setActionLoading(id);
      await clinicAPI.approveDoctor(id, { status, rejection_reason: status === 'rejected' ? 'Did not meet requirements' : '' });
      fetchData();
    } catch {
      alert('Failed to update doctor status');
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeactivateUser = async (id) => {
    try {
      setActionLoading(id);
      await authAPI.deactivateUser(id);
      fetchData();
    } catch {
      alert('Failed to update user status');
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeactivateDoctor = async (id) => {
    try {
      setActionLoading(id);
      await authAPI.deactivateDoctor(id);
      fetchData();
    } catch {
      alert('Failed to update doctor status');
    } finally {
      setActionLoading(null);
    }
  };

  const getFullUrl = (path) => {
    if (!path) return null;
    if (path.startsWith('http')) return path;
    // Ensure path starts with slash and has /media/ prefix
    const cleanPath = path.startsWith('/') ? path : `/${path}`;
    return `http://localhost:8000/media${cleanPath}`;
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading Admin Dashboard...</p>
    </div>
  );

  if (error) return (
    <div className="error-screen fade-in glass-card">
      <AlertCircle size={48} className="error-icon" />
      <h2>Something went wrong</h2>
      <p>{error}</p>
      <button className="btn-primary" onClick={fetchData}>Try Again</button>
    </div>
  );

  const pendingDoctors = doctors.filter(d => d.status === 'pending');

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header" style={{ 
        borderLeft: '8px solid #a855f7', 
        padding: '1.5rem',
        background: 'rgba(168, 85, 247, 0.05)',
        borderRadius: '0 12px 12px 0',
        marginBottom: '2rem'
      }}>
        <h1 style={{ color: '#fff', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          Admin Control Panel <ShieldCheck size={32} color="#a855f7" />
        </h1>
        <p style={{ fontSize: '1.1rem', color: '#ccc' }}>Manage doctor registrations, patient accounts, and system health.</p>
        <div style={{ 
          background: '#a855f7', 
          color: '#fff', 
          padding: '6px 16px', 
          borderRadius: '20px', 
          display: 'inline-block', 
          fontSize: '0.9rem', 
          fontWeight: '900', 
          marginTop: '15px',
          boxShadow: '0 0 15px rgba(168, 85, 247, 0.4)'
        }}>
          SYSTEM VERSION 2.0 - FULL CONTROL ACTIVE
        </div>
      </header>

      <div className="admin-sections" style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        
        {stats && (
          <section className="admin-stats-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem', marginBottom: '1rem' }}>
            <div className="glass-card stat-card" style={{ padding: '1.5rem', textAlign: 'center' }}>
              <Users size={32} color="var(--primary-color)" style={{ marginBottom: '0.5rem' }} />
              <h3>{stats.total_users}</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Total Patients</p>
            </div>
            <div className="glass-card stat-card" style={{ padding: '1.5rem', textAlign: 'center' }}>
              <ShieldCheck size={32} color="#3fb950" style={{ marginBottom: '0.5rem' }} />
              <h3>{stats.total_doctors}</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Total Doctors</p>
            </div>
            <div className="glass-card stat-card" style={{ padding: '1.5rem', textAlign: 'center' }}>
              <FileText size={32} color="#a371f7" style={{ marginBottom: '0.5rem' }} />
              <h3>{stats.total_assessments}</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Assessments Taken</p>
            </div>
            <div className="glass-card stat-card" style={{ padding: '1.5rem', textAlign: 'center' }}>
              <Activity size={32} color="#f85149" style={{ marginBottom: '0.5rem' }} />
              <h3>{stats.average_wellbeing_score} / 100</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Avg Wellbeing Score</p>
            </div>
          </section>
        )}

        <section className="glass-card">
          <div className="card-header">
            <h3>Pending Doctor Approvals ({pendingDoctors.length})</h3>
          </div>
          {pendingDoctors.length === 0 ? (
            <p className="empty-text" style={{padding: '1rem', color: '#888'}}>No pending approvals.</p>
          ) : (
            <div className="doctor-list" style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1rem' }}>
              {pendingDoctors.map(doc => (
                <div key={doc.doctor_id} className="doctor-item glass-card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem' }}>
                  <div style={{ flex: 1, cursor: 'pointer' }} onClick={() => setSelectedDoctor(doc)}>
                    <h4>{doc.full_name}</h4>
                    <p style={{color: '#818cf8', fontSize: '0.9rem', fontWeight: 'bold'}}>{doc.specialization || 'General'} | {doc.nationality}</p>
                    <p style={{color: '#888', fontSize: '0.85rem'}}>{doc.email}</p>
                    <small style={{color: '#a855f7'}}>Click to view full details</small>
                  </div>
                  <div style={{ display: 'flex', gap: '0.5rem' }}>
                    <button 
                      className="btn-primary" 
                      onClick={() => handleApprove(doc.doctor_id, 'approved')}
                      disabled={actionLoading === doc.doctor_id}
                      style={{ backgroundColor: '#3fb950', border: 'none' }}
                    >
                      <CheckCircle2 size={18} /> Accept
                    </button>
                    <button 
                      className="btn-primary" 
                      onClick={() => handleApprove(doc.doctor_id, 'rejected')}
                      disabled={actionLoading === doc.doctor_id}
                      style={{ backgroundColor: '#f85149', border: 'none' }}
                    >
                      <XCircle size={18} /> Reject
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
          <section className="glass-card">
            <div className="card-header">
              <h3>Doctor Directory ({doctors.length})</h3>
            </div>
            <div style={{ maxHeight: '400px', overflowY: 'auto', marginTop: '1rem', paddingRight: '10px' }}>
              {doctors.filter(d => d.status !== 'pending').map(doc => (
                <div key={doc.doctor_id} style={{ padding: '1rem 0', borderBottom: '1px solid #333', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <h4 style={{ margin: 0, opacity: doc.is_active ? 1 : 0.5 }}>
                      {doc.full_name} {!doc.is_active && <span style={{fontSize: '0.7rem', color: '#f85149'}}>(Inactive)</span>}
                    </h4>
                    <small style={{ color: '#888' }}>{doc.email}</small>
                    <button 
                      onClick={() => setSelectedDoctor(doc)}
                      style={{ display: 'block', background: 'none', border: 'none', color: 'var(--primary-color)', fontSize: '0.75rem', padding: 0, marginTop: '4px', cursor: 'pointer' }}
                    >
                      Details & Files
                    </button>
                  </div>
                  <button 
                    onClick={() => handleDeactivateDoctor(doc.doctor_id)}
                    disabled={actionLoading === doc.doctor_id}
                    style={{ 
                      padding: '4px 10px', fontSize: '0.75rem', borderRadius: '4px', border: '1px solid #555',
                      background: doc.is_active ? 'rgba(248, 81, 73, 0.1)' : 'rgba(63, 185, 80, 0.1)',
                      color: doc.is_active ? '#f85149' : '#3fb950', cursor: 'pointer'
                    }}
                  >
                    {doc.is_active ? 'Deactivate' : 'Activate'}
                  </button>
                </div>
              ))}
            </div>
          </section>

          <section className="glass-card">
            <div className="card-header">
              <h3>Patient Directory ({users.length})</h3>
            </div>
            <div style={{ maxHeight: '400px', overflowY: 'auto', marginTop: '1rem', paddingRight: '10px' }}>
              {users.map(user => (
                <div key={user.user_id} style={{ padding: '1rem 0', borderBottom: '1px solid #333', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <h4 style={{ margin: 0, opacity: user.is_active ? 1 : 0.5 }}>
                      {user.full_name} {!user.is_active && <span style={{fontSize: '0.7rem', color: '#f85149'}}>(Inactive)</span>}
                    </h4>
                    <small style={{ color: '#888' }}>{user.email}</small>
                  </div>
                  <button 
                    onClick={() => handleDeactivateUser(user.user_id)}
                    disabled={actionLoading === user.user_id}
                    style={{ 
                      padding: '4px 10px', fontSize: '0.75rem', borderRadius: '4px', border: '1px solid #555',
                      background: user.is_active ? 'rgba(248, 81, 73, 0.1)' : 'rgba(63, 185, 80, 0.1)',
                      color: user.is_active ? '#f85149' : '#3fb950', cursor: 'pointer'
                    }}
                  >
                    {user.is_active ? 'Deactivate' : 'Activate'}
                  </button>
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>

      {/* Doctor Detail Modal */}
      {selectedDoctor && (
        <div className="modal-overlay" style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(10px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 2000
        }}>
          <div className="glass-card fade-in" style={{ width: '90%', maxWidth: '600px', padding: '2rem', maxHeight: '90vh', overflowY: 'auto' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
              <h2>Doctor Profile Details</h2>
              <button onClick={() => setSelectedDoctor(null)} style={{ background: 'none', border: 'none', color: '#fff', cursor: 'pointer', fontSize: '1.5rem' }}>&times;</button>
            </div>

            <div style={{ display: 'flex', gap: '1.5rem', marginBottom: '2rem' }}>
              <div style={{ width: 100, height: 100, borderRadius: '12px', background: 'linear-gradient(45deg, #a78bfa, #7c3aed)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '2.5rem', fontWeight: 'bold' }}>
                {selectedDoctor.full_name[0]}
              </div>
              <div>
                <h3 style={{ margin: 0 }}>{selectedDoctor.full_name}</h3>
                <p style={{ color: '#a78bfa', margin: '4px 0' }}>{selectedDoctor.specialization}</p>
                <p style={{ color: '#888', fontSize: '0.9rem' }}>{selectedDoctor.email}</p>
                <p style={{ color: '#888', fontSize: '0.9rem' }}>Nationality: {selectedDoctor.nationality}</p>
              </div>
            </div>

            <div style={{ marginBottom: '2rem' }}>
              <h4 style={{ borderBottom: '1px solid #333', paddingBottom: '0.5rem', marginBottom: '1rem' }}>Professional Bio</h4>
              <p style={{ color: '#ccc', lineHeight: 1.6 }}>{selectedDoctor.bio || 'No bio provided.'}</p>
            </div>

            <div style={{ marginBottom: '2rem' }}>
              <h4 style={{ borderBottom: '1px solid #333', paddingBottom: '0.5rem', marginBottom: '1rem' }}>Documents & Certificates</h4>
              {selectedDoctor.cv_file_path ? (
                <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
                  <a 
                    href={getFullUrl(selectedDoctor.cv_file_path)}
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="glass-card"
                    style={{ 
                      flex: 1, minWidth: '200px', padding: '1.5rem', textAlign: 'center', 
                      textDecoration: 'none', color: '#fff', border: '1px dashed #555' 
                    }}
                  >
                    <FileText size={32} style={{ marginBottom: '1rem', color: '#a855f7' }} />
                    <p style={{ fontWeight: 'bold' }}>View CV / Credentials</p>
                    <small style={{ color: '#888' }}>Click to open in new tab</small>
                  </a>
                </div>
              ) : (
                <p style={{ color: '#f85149' }}>No certificate files found for this doctor.</p>
              )}
            </div>

            <button 
              className="btn-primary full-width" 
              onClick={() => setSelectedDoctor(null)}
              style={{ background: 'rgba(255,255,255,0.1)' }}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminDashboard;
