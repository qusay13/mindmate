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
  const [ratingModal, setRatingModal] = useState(null); // doctor object or null
  const [ratingValue, setRatingValue] = useState(5);
  const [ratingComment, setRatingComment] = useState('');
  const [submittingRating, setSubmittingRating] = useState(false);
  useAuth();
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

  const submitRating = async () => {
    if (!ratingModal) return;
    setSubmittingRating(true);
    try {
      await clinicAPI.rateDoctor(ratingModal.doctor_id, {
        score: ratingValue,
        comment: ratingComment
      });
      alert('Thank you for your rating!');
      setRatingModal(null);
      setRatingComment('');
      setRatingValue(5);
      fetchDoctors(); // Refresh ratings
    } catch (err) {
      alert(err.response?.data?.error || 'Failed to submit rating. You can only rate doctors you are connected with.');
    } finally {
      setSubmittingRating(false);
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
                      <Star size={11} /> {dr.average_rating || '0.0'} ({dr.ratings_count})
                    </span>
                    <span style={{
                      padding: '0.2rem 0.6rem', borderRadius: '20px', fontSize: '0.75rem',
                      background: '#34d399' + '22', color: '#34d399', display: 'flex', alignItems: 'center', gap: 4
                    }}>
                      <ShieldCheck size={11} /> Verified
                    </span>
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
                    <button
                      className="btn-primary"
                      onClick={() => navigate('/chat')}
                      style={{ flex: 1, borderRadius: '10px', padding: '0.55rem 0.8rem', fontSize: '0.85rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
                    >
                      <MessageSquare size={15} /> Message
                    </button>
                    <button
                      className="btn-primary"
                      onClick={() => setRatingModal(dr)}
                      style={{ flex: 1, borderRadius: '10px', padding: '0.55rem 0.8rem', fontSize: '0.85rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, background: 'rgba(210, 153, 34, 0.2)', color: '#d29922', border: '1px solid #d29922' }}
                    >
                      <Star size={15} /> Rate
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

      {/* Rating Modal */}
      {ratingModal && (
        <div className="modal-overlay" style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.8)', backdropFilter: 'blur(8px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000
        }}>
          <div className="glass-card fade-in" style={{ width: '90%', maxWidth: '400px', padding: '2rem' }}>
            <h2 style={{ textAlign: 'center', marginBottom: '0.5rem' }}>Rate Dr. {ratingModal.full_name}</h2>
            <p style={{ textAlign: 'center', color: '#888', marginBottom: '1.5rem', fontSize: '0.9rem' }}>Share your experience to help others.</p>
            
            <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem', marginBottom: '1.5rem' }}>
              {[1, 2, 3, 4, 5].map(v => (
                <Star
                  key={v}
                  size={32}
                  style={{ cursor: 'pointer', fill: v <= ratingValue ? '#d29922' : 'none', color: v <= ratingValue ? '#d29922' : '#555' }}
                  onClick={() => setRatingValue(v)}
                />
              ))}
            </div>

            <textarea
              className="input-field"
              placeholder="Add a comment (optional)..."
              value={ratingComment}
              onChange={(e) => setRatingComment(e.target.value)}
              rows="4"
              style={{ width: '100%', marginBottom: '1.5rem', background: 'rgba(255,255,255,0.05)', borderRadius: '12px', padding: '1rem' }}
            />

            <div style={{ display: 'flex', gap: '1rem' }}>
              <button
                className="btn-primary"
                onClick={() => setRatingModal(null)}
                style={{ flex: 1, background: 'rgba(255,255,255,0.1)', color: '#fff' }}
              >
                Cancel
              </button>
              <button
                className="btn-primary"
                onClick={submitRating}
                disabled={submittingRating}
                style={{ flex: 1 }}
              >
                {submittingRating ? 'Submitting...' : 'Submit Rating'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ClinicPage;
