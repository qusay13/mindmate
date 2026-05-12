import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { trackingAPI } from '../services/api';
import { BookOpen, ArrowLeft, Calendar } from 'lucide-react';

const JournalHistoryPage = () => {
  const navigate = useNavigate();
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchHistory();
  }, []);

  const fetchHistory = async () => {
    try {
      const res = await trackingAPI.getJournalHistory();
      setHistory(res.data);
    } catch (err) {
      console.error('Failed to load journal history', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading your past journals...</p>
    </div>
  );

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
        <button className="icon-btn" onClick={() => navigate('/')}>
          <ArrowLeft size={20} />
        </button>
        <div>
          <h1>Journal History</h1>
          <p>Review your past daily entries.</p>
        </div>
      </header>

      <div className="glass-card" style={{ maxWidth: '800px', margin: '0 auto', padding: '2rem' }}>
        <div className="card-header" style={{ marginBottom: '2rem' }}>
          <BookOpen size={20} className="accent" />
          <h3>All Entries</h3>
        </div>

        {history.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#888', padding: '2rem 0' }}>
            <BookOpen size={40} style={{ opacity: 0.2, marginBottom: '1rem' }} />
            <p>You haven't written any journal entries yet.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            {history.map((entry) => (
              <div key={entry.journal_id} style={{ 
                background: 'rgba(255,255,255,0.03)', 
                border: '1px solid rgba(255,255,255,0.05)',
                borderRadius: '12px',
                padding: '1.5rem'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1rem', color: '#a78bfa', fontSize: '0.9rem' }}>
                  <Calendar size={16} />
                  <strong>{new Date(entry.entry_date).toLocaleDateString()}</strong>
                </div>
                <div style={{ whiteSpace: 'pre-wrap', lineHeight: 1.6, color: '#e2e8f0', fontSize: '0.95rem' }}>
                  {entry.content}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default JournalHistoryPage;
