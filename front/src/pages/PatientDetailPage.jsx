import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { clinicAPI } from '../services/api';
import { 
  ArrowLeft, User, Calendar, Activity, 
  BookOpen, MessageCircle, AlertCircle 
} from 'lucide-react';

const PatientDetailPage = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [patient, setPatient] = useState(null);
  const [moods, setMoods] = useState([]);
  const [journals, setJournals] = useState([]);
  const [analysis, setAnalysis] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchPatientData();
  }, [id]);

  const fetchPatientData = async () => {
    try {
      setLoading(true);
      const [detailRes, moodRes, journalRes, analysisRes] = await Promise.all([
        clinicAPI.getPatientDetail(id),
        clinicAPI.getPatientMood(id),
        clinicAPI.getPatientJournals(id).catch(() => ({ data: [] })),
        clinicAPI.getPatientAnalysis(id).catch(() => ({ data: [] }))
      ]);
      
      setPatient(detailRes.data);
      setMoods(moodRes.data);
      setJournals(journalRes.data);
      setAnalysis(analysisRes.data);
    } catch (err) {
      console.error('Error fetching patient data', err);
      setError('Failed to load patient details. You might not have permission.');
    } finally {
      setLoading(false);
    }
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading patient records...</p>
    </div>
  );

  if (error) return (
    <div className="error-screen fade-in glass-card">
      <AlertCircle size={48} className="error-icon" />
      <h2>Access Restricted</h2>
      <p>{error}</p>
      <button className="btn-primary" onClick={() => navigate('/')}>Back to Dashboard</button>
    </div>
  );

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
        <button onClick={() => navigate('/')} className="btn-icon" title="Back">
          <ArrowLeft size={24} />
        </button>
        <div>
          <h1>Patient Profile</h1>
          <p>Reviewing history for {patient?.full_name}</p>
        </div>
      </header>

      <div className="dashboard-grid" style={{ gridTemplateColumns: '1fr 2fr', gap: '1.5rem' }}>
        
        {/* Patient Sidebar */}
        <aside className="glass-card" style={{ height: 'fit-content' }}>
          <div className="card-header">
            <User size={18} className="accent" />
            <h3>General Info</h3>
          </div>
          <div style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div style={{ textAlign: 'center', marginBottom: '1rem' }}>
              <div style={{ 
                width: 80, height: 80, borderRadius: '50%', margin: '0 auto 1rem',
                background: 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '2rem', fontWeight: 800, color: '#fff'
              }}>
                {patient?.full_name?.[0].toUpperCase()}
              </div>
              <h2 style={{ margin: 0 }}>{patient?.full_name}</h2>
              <p style={{ color: '#888', fontSize: '0.9rem' }}>{patient?.email}</p>
            </div>
            
            <div className="info-item">
              <label style={{ color: '#888', fontSize: '0.8rem', display: 'block' }}>Gender</label>
              <span>{patient?.gender || 'Not specified'}</span>
            </div>
            <div className="info-item">
              <label style={{ color: '#888', fontSize: '0.8rem', display: 'block' }}>Nationality</label>
              <span>{patient?.nationality || 'Not specified'}</span>
            </div>
            <div className="info-item">
              <label style={{ color: '#888', fontSize: '0.8rem', display: 'block' }}>Status</label>
              <span className="badge-active">{patient?.status}</span>
            </div>
            
            <button 
              className="btn-primary" 
              style={{ marginTop: '1rem', width: '100%' }}
              onClick={() => navigate('/chat')}
            >
              <MessageCircle size={18} style={{ marginRight: 8 }} />
              Open Chat
            </button>
          </div>
        </aside>

        {/* Patient Records */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          
          {/* Mood Trends */}
          <section className="glass-card">
            <div className="card-header">
              <Activity size={18} className="accent" />
              <h3>Recent Mood Trends (Last 30 Days)</h3>
            </div>
            <div style={{ padding: '1.5rem' }}>
              {moods.length === 0 ? (
                <p style={{ color: '#888' }}>No mood data available for this patient.</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                  {moods.slice(0, 7).map(m => (
                    <div key={m.mood_id} style={{ 
                      display: 'flex', alignItems: 'center', gap: '1rem', 
                      padding: '0.75rem', borderRadius: '8px', background: 'rgba(255,255,255,0.03)' 
                    }}>
                      <div style={{ width: 100, fontSize: '0.8rem', color: '#888' }}>
                        {new Date(m.recorded_date).toLocaleDateString()}
                      </div>
                      <div style={{ flex: 1, display: 'flex', gap: '4px' }}>
                        {[1, 2, 3, 4, 5].map(i => (
                          <div key={i} style={{ 
                            width: '20%', height: 8, borderRadius: 4,
                            background: i <= m.mood_level ? getMoodColor(m.mood_level) : 'rgba(255,255,255,0.1)'
                          }}></div>
                        ))}
                      </div>
                      <div style={{ width: 80, textAlign: 'right', fontWeight: 600, fontSize: '0.9rem' }}>
                        {m.mood_label || 'Neutral'}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </section>

          {/* Journals */}
          <section className="glass-card">
            <div className="card-header">
              <BookOpen size={18} className="accent" />
              <h3>Journal History</h3>
            </div>
            <div style={{ padding: '1.5rem' }}>
              {journals.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '1rem', color: '#888' }}>
                  <AlertCircle size={32} style={{ opacity: 0.3, marginBottom: '0.5rem' }} />
                  <p>No journals shared with you yet.</p>
                  <p style={{ fontSize: '0.8rem' }}>Patients must explicitly grant full journal access.</p>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  {journals.map(j => (
                    <div key={j.journal_id} className="journal-entry" style={{
                      padding: '1rem', borderRadius: '12px', background: 'rgba(255,255,255,0.03)',
                      border: '1px solid rgba(255,255,255,0.05)'
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
                        <span style={{ fontSize: '0.8rem', color: '#a78bfa', fontWeight: 600 }}>
                          {new Date(j.entry_date).toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
                        </span>
                      </div>
                      <p style={{ margin: 0, fontSize: '0.95rem', lineHeight: 1.6, color: '#e2e8f0' }}>
                        {j.content}
                      </p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </section>

          {/* AI Analysis Insights */}
          <section className="glass-card">
            <div className="card-header">
              <Activity size={18} className="accent" />
              <h3>AI Psychological Analysis</h3>
            </div>
            <div style={{ padding: '1.5rem' }}>
              {analysis.length === 0 ? (
                <p style={{ color: '#888' }}>No analysis insights available for this patient.</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  {analysis.map(a => (
                    <div key={a.analysis_id} style={{ 
                      padding: '1rem', borderRadius: '12px', background: 'rgba(167, 139, 250, 0.05)',
                      border: '1px solid rgba(167, 139, 250, 0.1)'
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.8rem' }}>
                        <span style={{ fontWeight: 700, color: '#a78bfa' }}>Pattern: {a.dominant_pattern}</span>
                        <span style={{ fontSize: '0.75rem', color: '#888' }}>{new Date(a.analyzed_at).toLocaleDateString()}</span>
                      </div>
                      
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.8rem' }}>
                        {a.detected_symptoms?.map((s, idx) => (
                          <span key={idx} style={{ 
                            padding: '0.2rem 0.5rem', borderRadius: '4px', fontSize: '0.7rem',
                            background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', border: '1px solid rgba(239, 68, 68, 0.2)'
                          }}>{s}</span>
                        ))}
                      </div>

                      <div style={{ fontSize: '0.85rem', color: '#e2e8f0' }}>
                        <div style={{ fontWeight: 600, marginBottom: '0.3rem', fontSize: '0.8rem', color: '#888' }}>Disorder Probabilities:</div>
                        {Object.entries(a.disorder_scores || {}).map(([disorder, score]) => (
                          <div key={disorder} style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '0.2rem' }}>
                            <span style={{ width: 80, fontSize: '0.75rem' }}>{disorder}</span>
                            <div style={{ flex: 1, height: 4, background: 'rgba(255,255,255,0.1)', borderRadius: 2 }}>
                              <div style={{ width: `${score}%`, height: '100%', background: '#a78bfa', borderRadius: 2 }}></div>
                            </div>
                            <span style={{ fontSize: '0.75rem', width: 30 }}>{score}%</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </section>

        </div>
      </div>
    </div>
  );
};

const getMoodColor = (level) => {
  if (level <= 2) return '#ef4444'; // Red
  if (level === 3) return '#f59e0b'; // Amber
  return '#34d399'; // Green
};

export default PatientDetailPage;
