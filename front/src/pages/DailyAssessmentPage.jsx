import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { trackingAPI } from '../services/api';
import { ChevronLeft, ChevronRight, Send, CheckCircle2 } from 'lucide-react';

const DailyAssessmentPage = () => {
  const { code } = useParams();
  const navigate = useNavigate();
  const [questions, setQuestions] = useState([]);
  const [currentStep, setCurrentStep] = useState(0);
  const [answers, setAnswers] = useState({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [completed, setCompleted] = useState(false);

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

  const handleOptionSelect = (questionId, optionValue, score) => {
    setAnswers({ 
      ...answers, 
      [questionId]: { optionValue, score } 
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
        selected_option: data.optionValue,
        score: data.score
      }));

      await trackingAPI.submitQuestionnaire({
        questionnaire_code: code,
        answers: answersList
      });
      setCompleted(true);
    } catch (err) {
      alert('Failed to submit assessment: ' + (err.response?.data?.error || 'Check your connections'));
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <div className="loading">Loading assessment...</div>;

  if (completed) {
    return (
      <div className="survey-complete fade-in">
        <div className="glass-card text-center">
          <CheckCircle2 size={64} className="success-icon" />
          <h2>Assessment Submitted!</h2>
          <p>Your daily progress has been updated.</p>
          <button className="btn-primary" onClick={() => navigate('/')}>Back to Dashboard</button>
        </div>
      </div>
    );
  }

  const currentQuestion = questions[currentStep];
  const progressPercent = ((currentStep + 1) / questions.length) * 100;

  return (
    <div className="survey-page fade-in">
      <header className="survey-header">
        <h1>{code} Assessment</h1>
        <div className="progress-bar-bg small">
          <div className="progress-bar-fill" style={{ width: `${progressPercent}%` }}></div>
        </div>
      </header>

      <div className="question-container glass-card">
        <h2 className="question-text">{currentQuestion?.question_text}</h2>
        
        <div className="options-grid">
          {currentQuestion?.options.map((option, idx) => (
            <button
              key={idx}
              className={`option-card ${answers[currentQuestion.question_id]?.optionValue === idx ? 'selected' : ''}`}
              onClick={() => handleOptionSelect(currentQuestion.question_id, idx, option.value)}
            >
              <span className="option-label">{option.text}</span>
              {answers[currentQuestion.question_id]?.optionValue === idx && <CheckCircle2 size={20} className="check" />}
            </button>
          ))}
        </div>

        <div className="survey-navigation">
          <button className="btn-secondary" onClick={prevStep} disabled={currentStep === 0}>
            <ChevronLeft size={20} /> Back
          </button>

          {currentStep === questions.length - 1 ? (
            <button 
              className="btn-primary" 
              onClick={handleSubmit}
              disabled={submitting || Object.keys(answers).length < questions.length}
            >
              {submitting ? 'Submitting...' : <>Submit <Send size={18} /></>}
            </button>
          ) : (
            <button 
              className="btn-primary" 
              onClick={nextStep}
              disabled={!answers[currentQuestion.question_id]}
            >
              Next <ChevronRight size={20} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default DailyAssessmentPage;
