import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { trackingAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { 
  Smile, Frown, Meh, BookOpen, TrendingUp, CheckCircle2, 
  AlertCircle, ChevronRight, Brain, Activity, HeartPulse, 
  Flame, BarChart3, Sparkles
} from 'lucide-react';

const MOOD_OPTIONS = [
  { level: 1, icon: <Frown size={24} />, label: 'Very Bad', color: '#f85149' },
  { level: 2, icon: <Frown size={24} />, label: 'Bad', color: '#f97316' },
  { level: 3, icon: <Meh size={24} />, label: 'Neutral', color: '#d29922' },
  { level: 4, icon: <Smile size={24} />, label: 'Good', color: '#34d399' },
  { level: 5, icon: <Smile size={24} />, label: 'Very Good', color: '#3fb950' },
];

const QUESTIONNAIRE_META = {
  GAD7: { label: 'GAD-7', desc: 'Anxiety Assessment', icon: <Brain size={20} />, css: 'gad7' },
  PHQ9: { label: 'PHQ-9', desc: 'Depression Screening', icon: <HeartPulse size={20} />, css: 'phq9' },
  PSS10: { label: 'PSS-10', desc: 'Stress Evaluation', icon: <Activity size={20} />, css: 'pss10' },
};

const WellbeingCircle = ({ score }) => {
  const radius = 50;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (score / 100) * circumference;
  const color = score >= 75 ? '#34d399' : score >= 50 ? '#d29922' : score >= 25 ? '#f97316' : '#f85149';

  return (
    <div className="wellbeing-circle">
      <svg viewBox="0 0 120 120">
        <circle className="track" cx="60" cy="60" r={radius} />
        <circle
          className="fill"
          cx="60" cy="60" r={radius}
          stroke={color}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
        />
      </svg>
      <div className="wellbeing-value">
        <div className="score" style={{ color }}>{Math.round(score)}</div>
        <div className="label">Wellbeing</div>
      </div>
    </div>
  );
};

const Dashboard = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [progress, setProgress] = useState(null);
  const [mood, setMood] = useState(null);
  const [journal, setJournal] = useState('');
  const [analysis, setAnalysis] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const [savingMood, setSavingMood] = useState(false);
  const [savingJournal, setSavingJournal] = useState(false);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [progRes, moodRes, journalRes, analysisRes] = await Promise.all([
        trackingAPI.getProgress().catch(() => ({
          data: { completion: 0, streak: 0, completed: [], mood_completed: false, questionnaire_completed: false, journal_completed: false, phq9_completed: false, gad7_completed: false, pss10_completed: false }
        })),
        trackingAPI.getMood().catch(() => ({ data: null })),
        trackingAPI.getJournal().catch(() => ({ data: null })),
        trackingAPI.getAnalysis().catch(() => ({ data: null })),
      ]);

      setProgress(progRes.data);
      if (moodRes.data) setMood(moodRes.data.mood_level);
      if (journalRes.data?.content) setJournal(journalRes.data.content);
      if (analysisRes.data) setAnalysis(analysisRes.data);
    } catch (err) {
      console.error('Dashboard fetch failed:', err);
      setError('Could not load your progress. Please try refreshing.');
    } finally {
      setLoading(false);
    }
  };

  const handleMoodSelect = async (level) => {
    setSavingMood(true);
    try {
      await trackingAPI.saveMood({ mood_level: level });
      setMood(level);
      fetchDashboardData();
    } catch {
      alert('Failed to save mood');
    } finally {
      setSavingMood(false);
    }
  };

  const handleJournalSubmit = async () => {
    setSavingJournal(true);
    try {
      await trackingAPI.saveJournal({ content: journal });
      fetchDashboardData();
    } catch {
      alert('Failed to save journal');
    } finally {
      setSavingJournal(false);
    }
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading your wellness dashboard...</p>
    </div>
  );

  if (error) return (
    <div className="error-screen fade-in glass-card">
      <AlertCircle size={48} className="error-icon" />
      <h2>Something went wrong</h2>
      <p>{error}</p>
      <button className="btn-primary" onClick={fetchDashboardData}>Try Again</button>
    </div>
  );

  // Extract latest daily analysis for wellbeing display
  const latestDaily = analysis?.daily_analyses?.length > 0
    ? analysis.daily_analyses[analysis.daily_analyses.length - 1]
    : null;
  const fifteenDay = analysis?.fifteen_day_analysis;

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header">
        <h1>Welcome back, {user?.full_name || 'User'} 👋</h1>
        <p>Here's your mental wellness overview for today.</p>
      </header>

      <div className="dashboard-grid">
        {/* ===== Wellbeing Score Card ===== */}
        <section className="glass-card" style={{ animationDelay: '0.1s' }}>
          <div className="card-header">
            <Sparkles size={18} className="accent" />
            <h3>Wellbeing Score</h3>
            {fifteenDay && (
              <span className={`trend-badge trend-${fifteenDay.trend || 'stable'}`}>
                {fifteenDay.trend === 'improving' ? '↑ Improving' : fifteenDay.trend === 'declining' ? '↓ Declining' : '↔ Stable'}
              </span>
            )}
          </div>

          {latestDaily?.wellbeing_score != null ? (
            <div className="wellbeing-section">
              <WellbeingCircle score={latestDaily.wellbeing_score} />
              <div className="wellbeing-details">
                <h3>
                  {latestDaily.wellbeing_score >= 75 ? 'Looking Great!' :
                   latestDaily.wellbeing_score >= 50 ? 'Room for Improvement' :
                   latestDaily.wellbeing_score >= 25 ? 'Needs Attention' : 'Seek Support'}
                </h3>
                <span className={`risk-label risk-${latestDaily.risk_level || 'healthy'}`}>
                  {latestDaily.risk_label_ar || 'صحي'}
                </span>
                <div className="domain-bars">
                  {latestDaily.anxiety_score != null && (
                    <div className="domain-bar">
                      <span className="domain-label">Anxiety</span>
                      <div className="bar-track">
                        <div className="bar-fill anxiety" style={{ width: `${latestDaily.anxiety_score}%` }} />
                      </div>
                      <span className="bar-value">{Math.round(latestDaily.anxiety_score)}%</span>
                    </div>
                  )}
                  {latestDaily.depression_score != null && (
                    <div className="domain-bar">
                      <span className="domain-label">Depression</span>
                      <div className="bar-track">
                        <div className="bar-fill depression" style={{ width: `${latestDaily.depression_score}%` }} />
                      </div>
                      <span className="bar-value">{Math.round(latestDaily.depression_score)}%</span>
                    </div>
                  )}
                  {latestDaily.stress_score != null && (
                    <div className="domain-bar">
                      <span className="domain-label">Stress</span>
                      <div className="bar-track">
                        <div className="bar-fill stress" style={{ width: `${latestDaily.stress_score}%` }} />
                      </div>
                      <span className="bar-value">{Math.round(latestDaily.stress_score)}%</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ) : (
            <div className="empty-state">
              <BarChart3 size={40} />
              <h3>No analysis yet</h3>
              <p>Complete your mood and questionnaires to see your wellbeing score.</p>
            </div>
          )}
        </section>

        {/* ===== Daily Progress ===== */}
        <section className="glass-card" style={{ animationDelay: '0.15s' }}>
          <div className="card-header">
            <TrendingUp size={18} className="accent" />
            <h3>Daily Progress</h3>
            <span className="streak-badge"><Flame size={12} /> {progress?.streak || 0} Day Streak</span>
          </div>

          <div className="progress-container">
            <div className="progress-bar-bg">
              <div className="progress-bar-fill" style={{ width: `${progress?.completion || 0}%` }} />
            </div>
            <div className="progress-stats">
              <span>{progress?.completion || 0}% Complete</span>
              <span>{progress?.completed?.length || 0} / 3 Tasks</span>
            </div>
          </div>

          <div className="task-list">
            <div className={`task-item ${progress?.mood_completed ? 'done' : ''}`}>
              <div className="task-info">
                {progress?.mood_completed ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
                <span>Mood Check-in</span>
              </div>
            </div>
            <div className={`task-item ${progress?.questionnaire_completed ? 'done' : ''}`}>
              <div className="task-info">
                {progress?.questionnaire_completed ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
                <span>Questionnaire</span>
              </div>
            </div>
            <div className={`task-item ${progress?.journal_completed ? 'done' : ''}`}>
              <div className="task-info">
                {progress?.journal_completed ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
                <span>Daily Journal</span>
              </div>
            </div>
          </div>
        </section>

        {/* ===== Mood Selector ===== */}
        <section className="glass-card mood-card" style={{ animationDelay: '0.2s' }}>
          <h3>How are you feeling today?</h3>
          <div className="mood-selector-grid">
            {MOOD_OPTIONS.map((m) => (
              <button
                key={m.level}
                className={`mood-btn ${mood === m.level ? 'active' : ''}`}
                onClick={() => handleMoodSelect(m.level)}
                disabled={savingMood}
              >
                {m.icon}
                <span>{m.label}</span>
              </button>
            ))}
          </div>
        </section>

        {/* ===== Questionnaire Picker ===== */}
        <section className="glass-card" style={{ animationDelay: '0.25s' }}>
          <div className="card-header">
            <Brain size={18} className="accent" />
            <h3>Daily Assessments</h3>
          </div>
          <div className="questionnaire-picker">
            {Object.entries(QUESTIONNAIRE_META).map(([code, meta]) => {
              const fieldName = `${code.toLowerCase()}_completed`;
              const isDone = progress?.[fieldName] || false;
              return (
                <div
                  key={code}
                  className={`q-picker-card ${meta.css} ${isDone ? 'completed' : ''}`}
                  onClick={() => !isDone && navigate(`/assessment/${code}`)}
                >
                  <div className="q-icon-row">
                    <div className={`q-icon ${meta.css}`}>{meta.icon}</div>
                    <span className={`q-badge ${isDone ? 'done' : 'pending'}`}>
                      {isDone ? <><CheckCircle2 size={12} /> Done</> : 'Start'}
                    </span>
                  </div>
                  <h4>{meta.label}</h4>
                  <p>{meta.desc}</p>
                </div>
              );
            })}
          </div>
        </section>

        {/* ===== Journal Section ===== */}
        <section className="glass-card full-row" style={{ animationDelay: '0.3s' }}>
          <div className="card-header">
            <BookOpen size={18} className="accent" />
            <h3>Daily Journal</h3>
            {progress?.journal_completed && (
              <span className="q-badge done"><CheckCircle2 size={12} /> Saved</span>
            )}
          </div>
          <textarea
            className="input-field journal-input"
            placeholder="Write about your day, thoughts, or feelings..."
            value={journal}
            onChange={(e) => setJournal(e.target.value)}
          />
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
