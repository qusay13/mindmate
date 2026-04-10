import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { trackingAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { Smile, Frown, Meh, BookOpen, TrendingUp, CheckCircle2, AlertCircle, ChevronRight } from 'lucide-react';


const Dashboard = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [progress, setProgress] = useState(null);

  const [mood, setMood] = useState(null);
  const [journal, setJournal] = useState('');
  const [savingMood, setSavingMood] = useState(false);
  const [savingJournal, setSavingJournal] = useState(false);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      const [progRes, moodRes, journalRes] = await Promise.all([
        trackingAPI.getProgress(),
        trackingAPI.getMood().catch(() => ({ data: null })),
        trackingAPI.getJournal().catch(() => ({ data: { content: '' } }))
      ]);
      
      setProgress(progRes.data);
      if (moodRes.data) setMood(moodRes.data.mood_level);
      if (journalRes.data) setJournal(journalRes.data.content);
    } catch (err) {
      console.error('Error fetching dashboard data', err);
    }
  };

  const handleMoodSelect = async (level) => {
    setSavingMood(true);
    try {
      await trackingAPI.saveMood({ mood_level: level });
      setMood(level);
      fetchDashboardData(); // Refresh progress
    } catch (err) {
      alert('Failed to save mood');
    } finally {
      setSavingMood(false);
    }
  };

  const handleJournalSubmit = async () => {
    setSavingJournal(true);
    try {
      await trackingAPI.saveJournal({ content: journal });
      fetchDashboardData(); // Refresh progress
      alert('Journal saved successfully!');
    } catch (err) {
      alert('Failed to save journal');
    } finally {
      setSavingJournal(false);
    }
  };

  if (!progress) return <div className="loading">Loading dashboard...</div>;

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header">
        <h1>Hello, {user?.full_name || 'User'}</h1>
        <p>Your mental wellness journey so far.</p>
      </header>

      <div className="dashboard-grid">
        {/* Progress Section */}
        <section className="glass-card progress-card">
          <div className="card-header">
            <TrendingUp size={20} className="accent" />
            <h3>Daily Progress</h3>
            <span className="streak-badge">{progress.streak} Day Streak</span>
          </div>
          
          <div className="progress-container">
            <div className="progress-bar-bg">
              <div 
                className="progress-bar-fill" 
                style={{ width: `${progress?.completion || 0}%` }}
              ></div>
            </div>
            <div className="progress-stats">
              <span>{progress?.completion || 0}% Complete</span>
              <span>{progress?.completed?.length || 0} / 3 Parts</span>
            </div>
          </div>

          <div className="task-list">
            <div className={`task-item ${progress?.mood_completed ? 'done' : ''}`}>
              {progress?.mood_completed ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
              <span>Mood Tracking</span>
            </div>
            <div 
              className={`task-item ${progress?.questionnaire_completed ? 'done' : ''} clickable`}
              onClick={() => !progress?.questionnaire_completed && navigate('/assessment/PHQ-9')}
            >
              <div className="task-info">
                {progress?.questionnaire_completed ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
                <span>Daily Questionnaires</span>
              </div>
              {!progress?.questionnaire_completed && <ChevronRight size={16} />}
            </div>

            <div className={`task-item ${progress?.journal_completed ? 'done' : ''}`}>
              {progress?.journal_completed ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
              <span>Daily Journal</span>
            </div>

          </div>
        </section>

        {/* Mood Section */}
        <section className="glass-card mood-card">
          <h3>How are you feeling today?</h3>
          <div className="mood-selector-grid">
            {[
              { level: 1, icon: <Frown />, label: 'Very Bad' },
              { level: 2, icon: <Frown />, label: 'Bad' },
              { level: 3, icon: <Meh />, label: 'Neutral' },
              { level: 4, icon: <Smile />, label: 'Good' },
              { level: 5, icon: <Smile />, label: 'Very Good' },
            ].map((m) => (
              <button
                key={m.level}
                className={`mood-btn lvl-${m.level} ${mood === m.level ? 'active' : ''}`}
                onClick={() => handleMoodSelect(m.level)}
                disabled={savingMood}
              >
                {m.icon}
                <span>{m.label}</span>
              </button>
            ))}
          </div>
        </section>

        {/* Journal Section */}
        <section className="glass-card journal-card full-row">
          <div className="card-header">
            <BookOpen size={20} className="accent" />
            <h3>Daily Journal</h3>
          </div>
          <textarea
            className="input-field journal-input"
            placeholder="Write about your day..."
            value={journal}
            onChange={(e) => setJournal(e.target.value)}
          ></textarea>
          <button 
            className="btn-primary" 
            onClick={handleJournalSubmit}
            disabled={savingJournal || !journal.trim()}
          >
            {savingJournal ? 'Saving...' : 'Save Journal Entry'}
          </button>
        </section>
      </div>
    </div>
  );
};

export default Dashboard;
