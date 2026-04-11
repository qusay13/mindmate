import React, { useState, useEffect } from 'react';
import { trackingAPI } from '../services/api';
import { 
  BarChart3, TrendingUp, TrendingDown, Minus, Shield, 
  Brain, HeartPulse, Activity, AlertTriangle, Lightbulb,
  Calendar, Zap, Target, Layers
} from 'lucide-react';

const AnalysisPage = () => {
  const [analysis, setAnalysis] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('fifteen');

  useEffect(() => {
    const fetchAnalysis = async () => {
      try {
        const res = await trackingAPI.getAnalysis();
        setAnalysis(res.data);
        // Auto-select tab based on available data
        if (res.data?.thirty_day_analysis) setActiveTab('thirty');
        else if (res.data?.fifteen_day_analysis) setActiveTab('fifteen');
        else setActiveTab('daily');
      } catch (err) {
        console.error('Analysis fetch error:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchAnalysis();
  }, []);

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Generating your analysis reports...</p>
    </div>
  );

  const dailyAnalyses = analysis?.daily_analyses || [];
  const fifteen = analysis?.fifteen_day_analysis;
  const thirty = analysis?.thirty_day_analysis;

  if (!dailyAnalyses.length) {
    return (
      <div className="analysis-page fade-in">
        <header className="page-header">
          <h1>Mental Health Analysis</h1>
          <p>Your comprehensive psychological wellbeing reports.</p>
        </header>
        <div className="glass-card no-data-msg">
          <BarChart3 size={48} style={{ opacity: 0.3, marginBottom: '16px' }} />
          <h3>Not Enough Data Yet</h3>
          <p>Complete your daily mood check-ins and questionnaires for at least 3 days to unlock your first analysis report. Keep going!</p>
        </div>
      </div>
    );
  }

  const activeData = activeTab === 'thirty' ? thirty : activeTab === 'fifteen' ? fifteen : null;
  const latestDaily = dailyAnalyses[dailyAnalyses.length - 1];

  const getTrendIcon = (trend) => {
    if (trend === 'improving') return <TrendingUp size={14} />;
    if (trend === 'declining') return <TrendingDown size={14} />;
    return <Minus size={14} />;
  };

  return (
    <div className="analysis-page fade-in">
      <header className="page-header">
        <h1>Mental Health Analysis</h1>
        <p>Comprehensive insights powered by clinical questionnaires (GAD-7, PHQ-9, PSS-10).</p>
      </header>

      {/* Period Tabs */}
      <div className="period-tabs">
        <button
          className={`period-tab ${activeTab === 'daily' ? 'active' : ''}`}
          onClick={() => setActiveTab('daily')}
        >
          <Calendar size={14} /> Daily
        </button>
        <button
          className={`period-tab ${activeTab === 'fifteen' ? 'active' : ''}`}
          onClick={() => setActiveTab('fifteen')}
          disabled={!fifteen}
        >
          <Zap size={14} /> 15-Day
        </button>
        <button
          className={`period-tab ${activeTab === 'thirty' ? 'active' : ''}`}
          onClick={() => setActiveTab('thirty')}
          disabled={!thirty}
        >
          <Target size={14} /> 30-Day
        </button>
      </div>

      {/* ===== Daily Tab ===== */}
      {activeTab === 'daily' && (
        <div className="analysis-grid">
          <section className="glass-card analysis-card">
            <div className="card-header">
              <Shield size={18} className="accent" />
              <h3>Latest Daily Score</h3>
            </div>
            <div className="stat-row">
              <div className="stat-box">
                <div className="stat-value">{latestDaily.wellbeing_score != null ? Math.round(latestDaily.wellbeing_score) : '—'}</div>
                <div className="stat-label">Wellbeing</div>
              </div>
              <div className="stat-box">
                <div className="stat-value">{latestDaily.mood_score != null ? Math.round(latestDaily.mood_score) : '—'}</div>
                <div className="stat-label">Mood Score</div>
              </div>
              <div className="stat-box">
                <div className="stat-value" style={{ fontSize: '14px' }}>{latestDaily.risk_label_ar || '—'}</div>
                <div className="stat-label">Risk Level</div>
              </div>
            </div>
          </section>

          <section className="glass-card analysis-card">
            <div className="card-header">
              <BarChart3 size={18} className="accent" />
              <h3>Score History</h3>
              <span className="text-xs text-secondary">{dailyAnalyses.length} days tracked</span>
            </div>
            <div className="score-chart">
              {dailyAnalyses.map((d, i) => (
                <div
                  key={i}
                  className="score-bar"
                  style={{ height: `${d.wellbeing_score || 10}%` }}
                  title={`${d.analysis_date}: ${Math.round(d.wellbeing_score || 0)}`}
                />
              ))}
            </div>
          </section>

          <section className="glass-card analysis-card full-row">
            <div className="card-header">
              <Layers size={18} className="accent" />
              <h3>Domain Breakdown (Latest)</h3>
            </div>
            <div className="stat-row">
              <div className="stat-box">
                <div className="stat-value" style={{ background: 'linear-gradient(135deg, #00f2ff, #00d4ff)', WebkitBackgroundClip: 'text' }}>
                  {latestDaily.anxiety_score != null ? Math.round(latestDaily.anxiety_score) : '—'}
                </div>
                <div className="stat-label"><Brain size={12} /> Anxiety</div>
              </div>
              <div className="stat-box">
                <div className="stat-value" style={{ background: 'linear-gradient(135deg, #f472b6, #ec4899)', WebkitBackgroundClip: 'text' }}>
                  {latestDaily.depression_score != null ? Math.round(latestDaily.depression_score) : '—'}
                </div>
                <div className="stat-label"><HeartPulse size={12} /> Depression</div>
              </div>
              <div className="stat-box">
                <div className="stat-value" style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)', WebkitBackgroundClip: 'text' }}>
                  {latestDaily.stress_score != null ? Math.round(latestDaily.stress_score) : '—'}
                </div>
                <div className="stat-label"><Activity size={12} /> Stress</div>
              </div>
            </div>
          </section>
        </div>
      )}

      {/* ===== 15-Day / 30-Day Tab ===== */}
      {(activeTab === 'fifteen' || activeTab === 'thirty') && activeData && (
        <div className="analysis-grid">
          {/* Overview Stats */}
          <section className="glass-card analysis-card">
            <div className="card-header">
              <Shield size={18} className="accent" />
              <h3>Period Overview</h3>
              <span className={`trend-badge trend-${activeData.trend || activeData.overall_trend || 'stable'}`}>
                {getTrendIcon(activeData.trend || activeData.overall_trend)}
                {activeData.trend_ar || activeData.overall_trend_ar || 'مستقر'}
              </span>
            </div>
            <div className="stat-row">
              <div className="stat-box">
                <div className="stat-value">{Math.round(activeData.average_wellbeing)}</div>
                <div className="stat-label">Avg. Wellbeing</div>
              </div>
              <div className="stat-box">
                <div className="stat-value" style={{ fontSize: '13px' }}>{activeData.risk_label_ar}</div>
                <div className="stat-label">Risk Level</div>
              </div>
              <div className="stat-box">
                <div className="stat-value" style={{ fontSize: '13px' }}>{activeData.stability_ar}</div>
                <div className="stat-label">Stability</div>
              </div>
            </div>
          </section>

          {/* Domain Averages */}
          <section className="glass-card analysis-card">
            <div className="card-header">
              <Layers size={18} className="accent" />
              <h3>Domain Averages</h3>
            </div>
            <div className="stat-row">
              <div className="stat-box">
                <div className="stat-value">{activeData.anxiety_avg != null ? Math.round(activeData.anxiety_avg) : '—'}</div>
                <div className="stat-label">Anxiety</div>
              </div>
              <div className="stat-box">
                <div className="stat-value">{activeData.depression_avg != null ? Math.round(activeData.depression_avg) : '—'}</div>
                <div className="stat-label">Depression</div>
              </div>
              <div className="stat-box">
                <div className="stat-value">{activeData.stress_avg != null ? Math.round(activeData.stress_avg) : '—'}</div>
                <div className="stat-label">Stress</div>
              </div>
            </div>

            {/* Domain trends for 30-day */}
            {activeTab === 'thirty' && thirty && (
              <div style={{ marginTop: '16px', display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                {thirty.anxiety_trend_ar && (
                  <span className={`trend-badge trend-${thirty.anxiety_trend}`}>
                    <Brain size={12} /> Anxiety: {thirty.anxiety_trend_ar}
                  </span>
                )}
                {thirty.depression_trend_ar && (
                  <span className={`trend-badge trend-${thirty.depression_trend}`}>
                    <HeartPulse size={12} /> Depression: {thirty.depression_trend_ar}
                  </span>
                )}
                {thirty.stress_trend_ar && (
                  <span className={`trend-badge trend-${thirty.stress_trend}`}>
                    <Activity size={12} /> Stress: {thirty.stress_trend_ar}
                  </span>
                )}
              </div>
            )}
          </section>

          {/* Score History Chart */}
          <section className="glass-card analysis-card full-row">
            <div className="card-header">
              <BarChart3 size={18} className="accent" />
              <h3>Wellbeing Score History</h3>
              <span className="text-xs text-secondary">{activeData.daily_scores?.length || 0} days</span>
            </div>
            <div className="score-chart">
              {(activeData.daily_scores || []).map((score, i) => (
                <div
                  key={i}
                  className="score-bar"
                  style={{ height: `${score}%` }}
                  title={`Day ${i + 1}: ${Math.round(score)}`}
                />
              ))}
            </div>
          </section>

          {/* 30-Day Exclusive Features */}
          {activeTab === 'thirty' && thirty && (
            <>
              {/* Cross-Period Comparison */}
              {thirty.period_comparison && (
                <section className="glass-card analysis-card">
                  <div className="card-header">
                    <TrendingUp size={18} className="accent" />
                    <h3>Period Comparison</h3>
                  </div>
                  <div className="stat-row">
                    <div className="stat-box">
                      <div className="stat-value">{Math.round(thirty.first_half_wellbeing)}</div>
                      <div className="stat-label">First Half</div>
                    </div>
                    <div className="stat-box">
                      <div className="stat-value">{Math.round(thirty.second_half_wellbeing)}</div>
                      <div className="stat-label">Second Half</div>
                    </div>
                    <div className="stat-box">
                      <div className="stat-value" style={{ fontSize: '14px' }}>{thirty.improvement_percentage > 0 ? '+' : ''}{thirty.improvement_percentage}%</div>
                      <div className="stat-label">Change</div>
                    </div>
                  </div>
                  <div style={{ textAlign: 'center', marginTop: '12px' }}>
                    <span className={`trend-badge trend-${thirty.period_comparison === 'improved' ? 'improving' : thirty.period_comparison === 'declined' ? 'declining' : 'stable'}`}>
                      {thirty.period_comparison_ar}
                    </span>
                  </div>
                </section>
              )}

              {/* Severity Trajectory */}
              {thirty.severity_trajectory_ar && (
                <section className="glass-card analysis-card">
                  <div className="card-header">
                    <AlertTriangle size={18} className="accent" />
                    <h3>Severity Trajectory</h3>
                  </div>
                  <div style={{ textAlign: 'center', padding: '16px 0' }}>
                    <p style={{ fontSize: '20px', marginBottom: '8px' }}>{thirty.severity_trajectory_ar}</p>
                    <div className="stat-row" style={{ marginTop: '16px' }}>
                      <div className="stat-box">
                        <div className="stat-value">{Math.round(thirty.worst_day_score)}</div>
                        <div className="stat-label">Worst Day</div>
                      </div>
                      <div className="stat-box">
                        <div className="stat-value">{Math.round(thirty.best_day_score)}</div>
                        <div className="stat-label">Best Day</div>
                      </div>
                      <div className="stat-box">
                        <div className="stat-value">{Math.round(thirty.score_range)}</div>
                        <div className="stat-label">Range</div>
                      </div>
                    </div>
                  </div>
                </section>
              )}

              {/* Weekly Pattern */}
              {thirty.weekly_pattern_detected && (
                <section className="glass-card analysis-card full-row">
                  <div className="card-header">
                    <Calendar size={18} className="accent" />
                    <h3>Weekly Pattern Detected</h3>
                  </div>
                  <p style={{ direction: 'rtl', textAlign: 'right', color: 'var(--text-secondary)', fontSize: '14px', lineHeight: '1.8' }}>
                    {thirty.weekly_pattern_ar}
                  </p>
                </section>
              )}

              {/* Domain Correlation */}
              {thirty.domain_correlation_ar?.length > 0 && (
                <section className="glass-card analysis-card full-row">
                  <div className="card-header">
                    <Layers size={18} className="accent" />
                    <h3>Domain Correlation</h3>
                  </div>
                  {thirty.domain_correlation_ar.map((item, i) => (
                    <div key={i} className="correlation-item" style={{ direction: 'rtl', textAlign: 'right' }}>
                      {item}
                    </div>
                  ))}
                </section>
              )}
            </>
          )}

          {/* Recommendations */}
          {activeData.recommendations_ar?.length > 0 && (
            <section className="glass-card analysis-card full-row">
              <div className="card-header">
                <Lightbulb size={18} className="accent" />
                <h3>Recommendations</h3>
              </div>
              <ul className="recommendation-list">
                {activeData.recommendations_ar.map((rec, i) => (
                  <li key={i} className="recommendation-item" style={{ direction: 'rtl', textAlign: 'right' }}>
                    {rec}
                  </li>
                ))}
              </ul>
            </section>
          )}

          {/* Adaptive Adjustments */}
          {activeData.adaptive_adjustments_ar?.length > 0 && (
            <section className="glass-card analysis-card full-row">
              <div className="card-header">
                <Zap size={18} className="accent" />
                <h3>Adaptive Questionnaire Adjustments</h3>
              </div>
              <ul className="recommendation-list">
                {activeData.adaptive_adjustments_ar.map((adj, i) => (
                  <li key={i} className="recommendation-item" style={{ direction: 'rtl', textAlign: 'right', borderLeftColor: 'var(--accent-warm)' }}>
                    {adj}
                  </li>
                ))}
              </ul>
            </section>
          )}
        </div>
      )}

      {/* No data for selected tab */}
      {(activeTab === 'fifteen' && !fifteen) && (
        <div className="glass-card no-data-msg">
          <h3>15-Day Analysis Not Ready</h3>
          <p>You need at least 3 days of data to generate the 15-day analysis. Keep tracking!</p>
        </div>
      )}
      {(activeTab === 'thirty' && !thirty) && (
        <div className="glass-card no-data-msg">
          <h3>30-Day Analysis Not Ready</h3>
          <p>You need at least 15 days of data to unlock the comprehensive 30-day report.</p>
        </div>
      )}
    </div>
  );
};

export default AnalysisPage;
