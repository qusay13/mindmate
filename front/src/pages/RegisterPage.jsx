import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authAPI } from '../services/api';
import { UserPlus, Mail, Lock, User, Briefcase, MapPin } from 'lucide-react';

const RegisterPage = () => {
  const [role, setRole] = useState('user');
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    full_name: '',
    specialization: '',
    clinic_address: '',
    years_of_experience: 1
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      if (role === 'user') {
        await authAPI.registerUser({
          email: formData.email,
          password: formData.password,
          full_name: formData.full_name
        });
      } else {
        await authAPI.registerDoctor(formData);
      }
      alert('Registration successful! Please login.');
      navigate('/login');
    } catch (err) {
      if (err.response?.data) {
        // Handle Django-style error objects
        const backendErrors = err.response.data;
        if (typeof backendErrors === 'object') {
          const firstError = Object.values(backendErrors)[0];
          setError(Array.isArray(firstError) ? firstError[0] : JSON.stringify(firstError));
        } else {
          setError('Registration failed. Please check your data.');
        }
      } else {
        setError('Connection error. Is the backend running?');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page fade-in">
      <div className="glass-card auth-card wide">
        <div className="auth-header">
          <h1>Create Account</h1>
          <p>Join MindMate as a {role}</p>
        </div>

        <div className="role-toggle-large">
          <button 
            className={role === 'user' ? 'active' : ''} 
            onClick={() => setRole('user')}
          >
            I am a Patient
          </button>
          <button 
            className={role === 'doctor' ? 'active' : ''} 
            onClick={() => setRole('doctor')}
          >
            I am a Doctor
          </button>
        </div>

        <form onSubmit={handleSubmit} className="auth-form">
          {error && <div className="error-message">{error}</div>}

          <div className="form-grid">
            <div className="form-group">
              <label>Full Name</label>
              <div className="input-with-icon">
                <User size={18} />
                <input
                  type="text"
                  className="input-field"
                  placeholder="John Doe"
                  value={formData.full_name}
                  onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                  required
                />
              </div>
            </div>

            <div className="form-group">
              <label>Email Address</label>
              <div className="input-with-icon">
                <Mail size={18} />
                <input
                  type="email"
                  className="input-field"
                  placeholder="john@example.com"
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  required
                />
              </div>
            </div>

            <div className="form-group">
              <label>Password</label>
              <div className="input-with-icon">
                <Lock size={18} />
                <input
                  type="password"
                  className="input-field"
                  placeholder="••••••••"
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                  required
                />
              </div>
            </div>

            {role === 'doctor' && (
              <>
                <div className="form-group">
                  <label>Specialization</label>
                  <div className="input-with-icon">
                    <Briefcase size={18} />
                    <input
                      type="text"
                      className="input-field"
                      placeholder="e.g. Clinical Psychologist"
                      value={formData.specialization}
                      onChange={(e) => setFormData({ ...formData, specialization: e.target.value })}
                      required
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label>Clinic Address</label>
                  <div className="input-with-icon">
                    <MapPin size={18} />
                    <input
                      type="text"
                      className="input-field"
                      placeholder="123 Health St."
                      value={formData.clinic_address}
                      onChange={(e) => setFormData({ ...formData, clinic_address: e.target.value })}
                    />
                  </div>
                </div>
              </>
            )}
          </div>

          <button type="submit" className="btn-primary full-width" disabled={loading}>
            {loading ? 'Registering...' : 'Complete Registration'}
          </button>
        </form>

        <p className="auth-footer">
          Already have an account? <Link to="/login">Login here</Link>
        </p>
      </div>
    </div>
  );
};

export default RegisterPage;
