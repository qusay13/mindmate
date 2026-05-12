import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { UserPlus, Mail, Lock, User, Globe, Stethoscope, FileText, UploadCloud, AlertCircle, CheckCircle } from 'lucide-react';
import { authAPI } from '../services/api';

const DoctorRegisterPage = () => {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    full_name: '',
    nationality: '',
    specialization: '',
    bio: ''
  });
  const [cvFile, setCvFile] = useState(null);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleFileChange = (e) => {
    setCvFile(e.target.files[0]);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);

    try {
      const data = new FormData();
      Object.keys(formData).forEach(key => {
        data.append(key, formData[key]);
      });
      if (cvFile) {
        data.append('cv_file_path', cvFile);
      }

      await authAPI.registerDoctor(data, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });

      setSuccess('Registration successful! Your application is now pending admin approval.');
      setTimeout(() => {
        navigate('/login');
      }, 3000);
    } catch (err) {
      console.error('Registration failed:', err);
      const errorData = err.response?.data;
      if (typeof errorData === 'object' && errorData !== null) {
        const errorMessages = Object.entries(errorData)
          .map(([key, val]) => `${key}: ${Array.isArray(val) ? val.join(', ') : val}`)
          .join(' | ');
        setError(errorMessages || 'Registration failed. Please check your inputs.');
      } else {
        setError('Registration failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page fade-in">
      <div className="glass-card auth-card wide">
        <div className="auth-header">
          <h1>Doctor Application</h1>
          <p>Join MindMate as a professional therapist</p>
        </div>

        {error && <div className="error-message">{error}</div>}
        {success && <div className="success-message" style={{ background: 'rgba(16, 185, 129, 0.1)', color: '#10b981', padding: '1rem', borderRadius: '8px', marginBottom: '1.5rem', textAlign: 'center' }}>{success}</div>}

        <form onSubmit={handleSubmit} className="auth-form" encType="multipart/form-data">
          <div className="form-grid">
            <div className="form-group">
              <label>Full Name</label>
              <div className="input-with-icon">
                <User size={18} />
                <input
                  type="text"
                  name="full_name"
                  className="input-field"
                  placeholder="Dr. Sarah Johnson"
                  value={formData.full_name}
                  onChange={handleChange}
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
                  name="email"
                  className="input-field"
                  placeholder="doctor@clinic.com"
                  value={formData.email}
                  onChange={handleChange}
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
                  name="password"
                  className="input-field"
                  placeholder="••••••••"
                  value={formData.password}
                  onChange={handleChange}
                  required
                />
              </div>
            </div>

            <div className="form-group">
              <label>Specialization</label>
              <div className="input-with-icon">
                <Stethoscope size={18} />
                <input
                  type="text"
                  name="specialization"
                  className="input-field"
                  placeholder="e.g. Clinical Psychologist"
                  value={formData.specialization}
                  onChange={handleChange}
                  required
                />
              </div>
            </div>

            <div className="form-group">
              <label>Nationality</label>
              <div className="input-with-icon">
                <Globe size={18} />
                <input
                  type="text"
                  name="nationality"
                  className="input-field"
                  placeholder="e.g. Jordan"
                  value={formData.nationality}
                  onChange={handleChange}
                />
              </div>
            </div>

            <div className="form-group">
              <label>CV / Credentials (PDF)</label>
              <div className="input-with-icon" style={{ padding: '0.5rem', background: 'rgba(255,255,255,0.05)', border: '1px dashed #555', borderRadius: '8px', display: 'flex', alignItems: 'center' }}>
                <UploadCloud size={18} style={{ marginRight: '0.5rem' }} />
                <input
                  type="file"
                  name="cv_file_path"
                  onChange={handleFileChange}
                  accept=".pdf,.doc,.docx"
                  required
                  style={{ width: '100%', cursor: 'pointer', color: '#ccc' }}
                />
              </div>
            </div>
          </div>

          <div className="form-group" style={{ marginTop: '1rem', marginBottom: '1.5rem' }}>
            <label>Professional Bio</label>
            <div className="input-with-icon" style={{ alignItems: 'flex-start', padding: '0.8rem' }}>
              <FileText size={18} style={{ marginTop: '0.2rem' }} />
              <textarea
                name="bio"
                className="input-field"
                placeholder="Briefly describe your experience and approach..."
                value={formData.bio}
                onChange={handleChange}
                rows="3"
                style={{ resize: 'vertical', minHeight: '60px', padding: '0 0.5rem' }}
              />
            </div>
          </div>

          <button type="submit" className="btn-primary full-width" disabled={loading}>
            {loading ? 'Submitting...' : 'Apply as Doctor'}
          </button>
        </form>

        <p className="auth-footer">
          Patient? <Link to="/register">Register here</Link> | Already have an account? <Link to="/login">Login</Link>
        </p>
      </div>
    </div>
  );
};

export default DoctorRegisterPage;
