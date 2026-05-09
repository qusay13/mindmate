import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { clinicAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import {
  Search, Star, ShieldCheck, UserPlus, MessageSquare,
  CheckCircle2, Loader, Stethoscope, Globe
} from 'lucide-react';

const ClinicPage = () => {
  const [doctors, setDoctors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [linking, setLinking] = useState(null);
  const { user } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    fetchDoctors();
  }, []);

  const fetchDoctors = async () => {
    try {
      setLoading(true);
      const res = await clinicAPI.getDoctors();
      setDoctors(res.data);
    } catch (err) {
      console.error('Error fetching doctors', err);
    } finally {
      setLoading(false);
    }
  };

  const handleLink = async (doctorId) => {
    setLinking(doctorId);
    try {
      await clinicAPI.linkWithDoctor({ doctor_id: doctorId, request_type: 'user_selected' });
      // Update local state to show pending
      setDoctors(prev => prev.map(dr =>
        dr.doctor_id === doctorId ? { ...dr, link_status: 'pending' } : dr
      ));
    } catch (err) {
      alert(err.response?.data?.error || 'Failed to connect with doctor');
    } finally {
      setLinking(null);
    }
  };

  const filteredDoctors = doctors.filter(dr => {
    const name = dr.full_name?.toLowerCase() || '';
    const spec = dr.specialization?.toLowerCase() || '';
    const q = search.toLowerCase();
    return name.includes(q) || spec.includes(q);
  });

  return (
    <div className="clinic-page fade-in">
      <header className="page-header">
        <h1>Find Your Specialist</h1>
        <p>Connect with licensed mental health professionals who can support your journey.</p>

        <div className="search-bar glass-card">
          <Search size={20} className="text-secondary" />
          <input
            type="text"
            placeholder="Search by name or specialization..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{
              background: 'none', border: 'none', outline: 'none',
              color: 'inherit', fontSize: '0.95rem', flex: 1,
            }}
          />
        </div>
      </header>

      {loading ? (
        <div className="loading-screen">
          <div className="loader"></div>
          <p>Finding specialists...</p>
        </div>
      ) : (
        <div className="doctors-grid">
          {filteredDoctors.map((dr) => (
            <div key={dr.doctor_id} className="glass-card doctor-card" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              {/* Header */}
              <div style={{ display: 'flex', gap: '1rem', alignItems: 'flex-start' }}>
                <div style={{
                  width: 56, height: 56, borderRadius: '50%', flexShrink: 0,
                  background: 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '1.4rem', fontWeight: 800, color: '#fff'
                }}>
                  {(dr.full_name || 'D')[0].toUpperCase()}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700 }}>Dr. {dr.full_name}</h3>
                  <div style={{ color: '#a78bfa', fontSize: '0.85rem', marginTop: '0.2rem' }}>
                    <Stethoscope size={13} style={{ verticalAlign: 'middle', marginRight: 4 }} />
                    {dr.specialization || 'General'}
                  </div>
                  <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', flexWrap: 'wrap' }}>
                    <span style={{
                      padding: '0.2rem 0.6rem', borderRadius: '20px', fontSize: '0.75rem',
                      background: '#d29922' + '22', color: '#d29922', display: 'flex', alignItems: 'center', gap: 4
                    }}>
                      <Star size={11} /> 4.9
                    </span>
                    <span style={{
                      padding: '0.2rem 0.6rem', borderRadius: '20px', fontSize: '0.75rem',
                      background: '#34d399' + '22', color: '#34d399', display: 'flex', alignItems: 'center', gap: 4
                    }}>
                      <ShieldCheck size={11} /> Verified
                    </span>
                    {dr.nationality && (
                      <span style={{
                        padding: '0.2rem 0.6rem', borderRadius: '20px', fontSize: '0.75rem',
                        background: 'rgba(255,255,255,0.07)', color: '#aaa', display: 'flex', alignItems: 'center', gap: 4
                      }}>
                        <Globe size={11} /> {dr.nationality}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Bio */}
              {dr.bio && (
                <p style={{ fontSize: '0.85rem', color: '#aaa', lineHeight: 1.5, margin: 0 }}>
                  {dr.bio.length > 120 ? dr.bio.slice(0, 120) + '...' : dr.bio}
                </p>
              )}

              {/* Actions */}
              <div style={{ display: 'flex', gap: '0.75rem', marginTop: 'auto' }}>
                {dr.link_status === 'linked' ? (
                  <>
                    <div style={{
                      flex: 1, padding: '0.55rem 0.8rem', borderRadius: '10px',
                      background: '#34d39922', color: '#34d399', display: 'flex',
                      alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: '0.85rem', fontWeight: 600
                    }}>
                      <CheckCircle2 size={15} /> Connected
                    </div>
                    <button
                      className="btn-primary"
                      onClick={() => navigate('/chat')}
                      style={{ flex: 1, borderRadius: '10px', padding: '0.55rem 0.8rem', fontSize: '0.85rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
                    >
                      <MessageSquare size={15} /> Message
                    </button>
                  </>
                ) : dr.link_status === 'pending' ? (
                  <div style={{
                    flex: 1, padding: '0.6rem', borderRadius: '10px',
                    background: 'rgba(255, 152, 0, 0.1)', color: '#ff9800', display: 'flex',
                    alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: '0.85rem', fontWeight: 600
                  }}>
                    <Loader size={15} className="spin" /> Request Pending...
                  </div>
                ) : (
                  <button
                    className="btn-primary"
                    onClick={() => handleLink(dr.doctor_id)}
                    disabled={linking === dr.doctor_id}
                    style={{ flex: 1, borderRadius: '10px', padding: '0.6rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
                  >
                    {linking === dr.doctor_id
                      ? <><Loader size={15} className="spin" /> Sending...</>
                      : <><UserPlus size={15} /> Request Connection</>
                    }
                  </button>
                )}
              </div>
            </div>
          ))}

          {filteredDoctors.length === 0 && !loading && (
            <div style={{ textAlign: 'center', padding: '3rem', color: '#888', gridColumn: '1/-1' }}>
              <Stethoscope size={48} style={{ opacity: 0.2, marginBottom: '1rem', display: 'block', margin: '0 auto 1rem' }} />
              <p>No specialists found matching your search.</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default ClinicPage;
