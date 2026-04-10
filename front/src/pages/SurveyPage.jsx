import React, { useState, useEffect } from 'react';
import { surveyAPI } from '../services/api';
import { CheckCircle2, ChevronRight, ChevronLeft, Send } from 'lucide-react';

const SurveyPage = () => {
  const [questions, setQuestions] = useState([]);
  const [currentStep, setCurrentStep] = useState(0);
  const [answers, setAnswers] = useState({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [completed, setCompleted] = useState(false);

  useEffect(() => {
    const fetchQuestions = async () => {
      try {
        const res = await surveyAPI.getQuestions();
        setQuestions(res.data);
        
        // Initialize scale questions with default value 5
        const initialAnswers = {};
        res.data.forEach(q => {
          if (q.question_type === 'scale') {
            initialAnswers[q.question_id] = 5;
          }
        });
        setAnswers(initialAnswers);
      } catch (err) {
        console.error('Error fetching questions', err);
      } finally {
        setLoading(false);
      }
    };
    fetchQuestions();
  }, []);

  const handleOptionSelect = (questionId, optionId) => {
    setAnswers({ ...answers, [questionId]: optionId });
  };

  const nextStep = () => {
    if (currentStep < questions.length - 1) {
      setCurrentStep(currentStep + 1);
    }
  };

  const prevStep = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleSubmit = async () => {
    setSubmitting(true);
    try {
      const responseList = Object.entries(answers).map(([qId, val]) => {
        const question = questions.find(q => q.question_id.toString() === qId);
        const isScale = question?.question_type === 'scale';
        
        return {
          question_id: parseInt(qId),
          answer_text: isScale ? val.toString() : (question?.options[val] || val.toString()),
          answer_value: isScale ? parseFloat(val) : null
        };
      });
      await surveyAPI.submitResponses({ responses: responseList });
      setCompleted(true);
    } catch (err) {
      alert('Error submitting survey: ' + (err.response?.data?.error || 'Check your answers'));
    } finally {
      setSubmitting(false);
    }
  };


  if (loading) return <div>Loading initial assessment...</div>;

  if (completed) {
    return (
      <div className="survey-complete fade-in">
        <div className="glass-card text-center">
          <div className="success-icon">
            <CheckCircle2 size={64} />
          </div>
          <h2>Assessment Completed!</h2>
          <p>Thank you for completing your initial assessment. This helps us personalize your experience.</p>
          <button className="btn-primary" onClick={() => window.location.href = '/'}>
            Go to Dashboard
          </button>
        </div>
      </div>
    );
  }

  const currentQuestion = questions[currentStep];
  const progressPercent = ((currentStep + 1) / questions.length) * 100;

  // Transform options if they are simple strings
  const renderedOptions = currentQuestion?.options?.map((opt, idx) => 
    typeof opt === 'string' ? { id: idx, text: opt, value: idx } : opt
  ) || [];

  return (
    <div className="survey-page fade-in">
      <header className="survey-header">
        <h1>Initial Assessment</h1>
        <p>Step {currentStep + 1} of {questions.length}</p>
        <div className="progress-bar-bg small">
          <div className="progress-bar-fill" style={{ width: `${progressPercent}%` }}></div>
        </div>
      </header>

      <div className="question-container glass-card">
        <h2 className="question-text">{currentQuestion?.question_text}</h2>
        
        {currentQuestion?.question_type === 'scale' ? (
          <div className="scale-container">
            <input 
              type="range" min="1" max="10" 
              className="range-input"
              value={answers[currentQuestion.question_id] || 5}
              onChange={(e) => handleOptionSelect(currentQuestion.question_id, parseInt(e.target.value))}
            />
            <div className="scale-labels">
              <span>1</span>
              <span>Selected: {answers[currentQuestion.question_id] || 5}</span>
              <span>10</span>
            </div>
          </div>
        ) : (
          <div className="options-grid">
            {renderedOptions.map((option) => (
              <button
                key={option.id}
                className={`option-card ${answers[currentQuestion.question_id] === option.id ? 'selected' : ''}`}
                onClick={() => handleOptionSelect(currentQuestion.question_id, option.id)}
              >
                <span className="option-label">{option.text}</span>
                {answers[currentQuestion.question_id] === option.id && <CheckCircle2 size={20} className="check" />}
              </button>
            ))}
          </div>
        )}

        <div className="survey-navigation">
          <button 
            className="btn-secondary" 
            onClick={prevStep} 
            disabled={currentStep === 0}
          >
            <ChevronLeft size={20} /> Back
          </button>

          {currentStep === questions.length - 1 ? (
            <button 
              className="btn-primary" 
              onClick={handleSubmit}
              disabled={submitting || Object.keys(answers).length < questions.length}
            >
              {submitting ? 'Submitting...' : <>Submit Assessment <Send size={18} /></>}
            </button>
          ) : (
            <button 
              className="btn-primary" 
              onClick={nextStep}
              disabled={currentQuestion?.question_type !== 'scale' && !answers[currentQuestion.question_id]}
            >
              Next <ChevronRight size={20} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};


export default SurveyPage;
