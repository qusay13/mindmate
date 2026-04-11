import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { trackingAPI } from '../services/api';
import { ChevronLeft, ChevronRight, Send, CheckCircle2, Brain, HeartPulse, Activity } from 'lucide-react';

const QUESTIONNAIRE_META = {
  GAD7: { label: 'GAD-7', fullName: 'Generalized Anxiety Disorder', icon: <Brain size={24} />, color: '#00f2ff' },
  PHQ9: { label: 'PHQ-9', fullName: 'Patient Health Questionnaire', icon: <HeartPulse size={24} />, color: '#f472b6' },
  PSS10: { label: 'PSS-10', fullName: 'Perceived Stress Scale', icon: <Activity size={24} />, color: '#f59e0b' },
};

const DailyAssessmentPage = () => {
  const { code } = useParams();
  const navigate = useNavigate();
  const [questions, setQuestions] = useState([]);
  const [currentStep, setCurrentStep] = useState(0);
  const [answers, setAnswers] = useState({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [completed, setCompleted] = useState(false);
  const [result, setResult] = useState(null);

  const meta = QUESTIONNAIRE_META[code] || { label: code, fullName: code, icon: <Brain size={24} />, color: '#00f2ff' };

  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await trackingAPI.getQuestionnaireQuestions(code);
        setQuestions(res.data);
      } catch (err) {
        console.error('Error fetching daily questions', err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [code]);

  const handleOptionSelect = (questionId, optionIndex, score) => {
    setAnswers({
      ...answers,
      [questionId]: { optionIndex, score }
    });
  };

  const nextStep = () => {
    if (currentStep < questions.length - 1) setCurrentStep(currentStep + 1);
  };

  const prevStep = () => {
    if (currentStep > 0) setCurrentStep(currentStep - 1);
  };

  const handleSubmit = async () => {
    setSubmitting(true);
    try {
      const answersList = Object.entries(answers).map(([qId, data]) => ({
        question_id: parseInt(qId),
        selected_option: data.optionIndex,
        score: data.score
      }));

      const res = await trackingAPI.submitQuestionnaire({
        questionnaire_code: code,
        answers: answersList
      });
      setResult(res.data);
      setCompleted(true);
    } catch (err) {
      alert('Failed to submit assessment: ' + (err.response?.data?.error || 'Please check your connection'));
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading {meta.label} assessment...</p>
    </div>
  );

  if (completed) {
    return (
      <div className="survey-complete fade-in">
        <div className="glass-card text-center" style={{ maxWidth: '500px', padding: '48px' }}>
          <CheckCircle2 size={56} className="success-icon" />
          <h2 style={{ marginBottom: '12px' }}>{meta.label} Complete!</h2>
          {result && (
            <div style={{ marginBottom: '24px' }}>
              <div className="stat-row" style={{ justifyContent: 'center', marginBottom: '16px' }}>
                <div className="stat-box">
                  <div className="stat-value">{result.total_score}</div>
                  <div className="stat-label">Total Score</div>
                </div>
                <div className="stat-box">
                  <div className="stat-value" style={{ fontSize: '16px' }}>{result.severity_level}</div>
                  <div className="stat-label">Severity</div>
                </div>
              </div>
            </div>
          )}
          <p style={{ color: 'var(--text-secondary)', marginBottom: '24px', fontSize: '14px' }}>
            Your daily progress has been updated. Results are now reflected in your analysis.
          </p>
          <button className="btn-primary" onClick={() => navigate('/')}>Back to Dashboard</button>
        </div>
      </div>
    );
  }

  const currentQuestion = questions[currentStep];
  const progressPercent = ((currentStep + 1) / questions.length) * 100;

  // RaedRepo options format: { label: "أبداً", score: 0 }
  const options = currentQuestion?.options || [];

  return (
    <div className="survey-page fade-in">
      <header className="survey-header">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', marginBottom: '8px' }}>
          <span style={{ color: meta.color }}>{meta.icon}</span>
          <h1>{meta.label} Assessment</h1>
        </div>
        <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginBottom: '16px' }}>{meta.fullName}</p>
        <p style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>Question {currentStep + 1} of {questions.length}</p>
        <div className="progress-bar-bg small" style={{ maxWidth: '400px', margin: '12px auto 0' }}>
          <div className="progress-bar-fill" style={{ width: `${progressPercent}%` }} />
        </div>
      </header>

      <div className="question-container glass-card">
        <h2 className="question-text" style={{ direction: 'rtl', textAlign: 'right' }}>
          {currentQuestion?.question_text}
        </h2>

        <div className="options-grid">
          {options.map((option, idx) => (
            <button
              key={idx}
              className={`option-card ${answers[currentQuestion.question_id]?.optionIndex === idx ? 'selected' : ''}`}
              onClick={() => handleOptionSelect(currentQuestion.question_id, idx, option.score)}
              style={{ direction: 'rtl' }}
            >
              <span className="option-label">{option.label}</span>
              {answers[currentQuestion.question_id]?.optionIndex === idx && <CheckCircle2 size={20} className="check" />}
            </button>
          ))}
        </div>

        <div className="survey-navigation">
          <button className="btn-secondary" onClick={prevStep} disabled={currentStep === 0}>
            <ChevronLeft size={18} /> Back
          </button>

          {currentStep === questions.length - 1 ? (
            <button
              className="btn-primary"
              onClick={handleSubmit}
              disabled={submitting || Object.keys(answers).length < questions.length}
            >
              {submitting ? 'Submitting...' : <>Submit <Send size={16} /></>}
            </button>
          ) : (
            <button
              className="btn-primary"
              onClick={nextStep}
              disabled={!answers[currentQuestion.question_id]}
            >
              Next <ChevronRight size={18} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default DailyAssessmentPage;
