import React, { useState, useEffect } from 'react';
import { clinicAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { CheckCircle2, XCircle, AlertCircle, UserCheck, ShieldCheck } from 'lucide-react';

const AdminDashboard = () => {
  const { user } = useAuth();
  const [doctors, setDoctors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionLoading, setActionLoading] = useState(null);

  useEffect(() => {
    fetchDoctors();
  }, []);

  const fetchDoctors = async () => {
    try {
      setLoading(true);
      const res = await clinicAPI.getAdminDoctors();
      setDoctors(res.data);
    } catch (err) {
      console.error('Failed to fetch doctors', err);
      setError('Could not load doctors list.');
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (id, status) => {
    try {
      setActionLoading(id);
      await clinicAPI.approveDoctor(id, { status, rejection_reason: status === 'rejected' ? 'Did not meet requirements' : '' });
      fetchDoctors();
    } catch (err) {
      alert('Failed to update doctor status');
    } finally {
      setActionLoading(null);
    }
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
      <button className="btn-primary" onClick={fetchDoctors}>Try Again</button>
    </div>
  );

  const pendingDoctors = doctors.filter(d => d.status === 'pending');
  const approvedDoctors = doctors.filter(d => d.status === 'approved');
  const rejectedDoctors = doctors.filter(d => d.status === 'rejected');

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header">
        <h1>Admin Control Panel <ShieldCheck size={28} style={{verticalAlign: 'bottom'}} /></h1>
        <p>Manage doctor registrations and system settings.</p>
      </header>

      <div className="admin-sections" style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
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
                  <div>
                    <h4>{doc.full_name}</h4>
                    <p style={{color: '#888', fontSize: '0.9rem'}}>{doc.specialization || 'General'} | {doc.nationality}</p>
                    <p style={{color: '#888', fontSize: '0.9rem'}}>{doc.email}</p>
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

        <div style={{ display: 'flex', gap: '2rem' }}>
          <section className="glass-card" style={{ flex: 1 }}>
            <div className="card-header">
              <h3>Approved Doctors ({approvedDoctors.length})</h3>
            </div>
            <div style={{ maxHeight: '300px', overflowY: 'auto', marginTop: '1rem', paddingRight: '10px' }}>
              {approvedDoctors.map(doc => (
                <div key={doc.doctor_id} style={{ padding: '0.8rem 0', borderBottom: '1px solid #333' }}>
                  <h4 style={{ margin: 0 }}>{doc.full_name} <UserCheck size={14} color="#3fb950" /></h4>
                  <small style={{ color: '#888' }}>{doc.email}</small>
                </div>
              ))}
            </div>
          </section>

          <section className="glass-card" style={{ flex: 1 }}>
            <div className="card-header">
              <h3>Rejected Doctors ({rejectedDoctors.length})</h3>
            </div>
            <div style={{ maxHeight: '300px', overflowY: 'auto', marginTop: '1rem', paddingRight: '10px' }}>
              {rejectedDoctors.map(doc => (
                <div key={doc.doctor_id} style={{ padding: '0.8rem 0', borderBottom: '1px solid #333' }}>
                  <h4 style={{ margin: 0 }}>{doc.full_name}</h4>
                  <small style={{ color: '#f85149' }}>Rejected</small>
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;
