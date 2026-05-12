import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { profileAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { User, Save, ArrowLeft, Camera, Calendar, Phone, Globe, CheckCircle2 } from 'lucide-react';

const ProfileEditPage = () => {
  const { user: authUser } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [previewImg, setPreviewImg] = useState(null);

  const [form, setForm] = useState({
    full_name: '',
    date_of_birth: '',
    gender: '',
    phone_number: '',
    nationality: '',
    profile_image: null,
  });

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const res = await profileAPI.getUserProfile();
        const d = res.data;
        setForm({
          full_name: d.full_name || '',
          date_of_birth: d.date_of_birth || '',
          gender: d.gender || '',
          phone_number: d.phone_number || '',
          nationality: d.nationality || '',
          profile_image: null,
        });
        if (d.profile_image) setPreviewImg(d.profile_image);
      } catch {
        setError('Failed to load profile.');
      } finally {
        setLoading(false);
      }
    };
    fetchProfile();
  }, []);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
  };

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setForm(prev => ({ ...prev, profile_image: file }));
      setPreviewImg(URL.createObjectURL(file));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const formData = new FormData();
      Object.entries(form).forEach(([key, value]) => {
        if (value !== null && value !== '') formData.append(key, value);
      });
      await profileAPI.updateUserProfile(formData);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to update profile.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading your profile...</p>
    </div>
  );

  const avatarLetter = form.full_name?.[0]?.toUpperCase() || authUser?.email?.[0]?.toUpperCase() || 'U';

  return (
    <div className="dashboard-page fade-in">
      <header className="page-header">
        <button
          onClick={() => navigate('/')}
          style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 6, marginBottom: '1rem', fontSize: '0.9rem' }}
        >
          <ArrowLeft size={16} /> Back to Dashboard
        </button>
        <h1 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <User size={28} color="#a855f7" /> Edit My Profile
        </h1>
        <p>Update your personal information and preferences.</p>
      </header>

      <div style={{ maxWidth: '600px', margin: '0 auto' }}>
        {/* Avatar Section */}
        <div className="glass-card" style={{ padding: '2rem', marginBottom: '1.5rem', textAlign: 'center' }}>
          <div style={{ position: 'relative', display: 'inline-block', marginBottom: '1rem' }}>
            {previewImg ? (
              <img
                src={previewImg.startsWith('http') ? previewImg : `http://localhost:8000${previewImg}`}
                alt="Profile"
                style={{ width: 100, height: 100, borderRadius: '50%', objectFit: 'cover', border: '3px solid #a855f7' }}
              />
            ) : (
              <div style={{
                width: 100, height: 100, borderRadius: '50%',
                background: 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '2.5rem', fontWeight: 800, color: '#fff',
                border: '3px solid #a855f7'
              }}>
                {avatarLetter}
              </div>
            )}
            <label htmlFor="profile_image_input" style={{
              position: 'absolute', bottom: 0, right: 0,
              background: '#a855f7', borderRadius: '50%', padding: '6px',
              cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center'
            }}>
              <Camera size={14} color="#fff" />
            </label>
            <input id="profile_image_input" type="file" accept="image/*" onChange={handleImageChange} style={{ display: 'none' }} />
          </div>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Click the camera icon to change your photo</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="glass-card" style={{ padding: '2rem' }}>
          {error && (
            <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid #ef4444', borderRadius: 10, padding: '0.75rem 1rem', color: '#ef4444', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
              {error}
            </div>
          )}

          {saved && (
            <div style={{ background: 'rgba(34,197,94,0.1)', border: '1px solid #22c55e', borderRadius: 10, padding: '0.75rem 1rem', color: '#22c55e', marginBottom: '1.5rem', fontSize: '0.9rem', display: 'flex', alignItems: 'center', gap: 8 }}>
              <CheckCircle2 size={16} /> Profile updated successfully!
            </div>
          )}

          <div style={{ display: 'grid', gap: '1.25rem' }}>
            {/* Full Name */}
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                Full Name
              </label>
              <input
                type="text"
                name="full_name"
                value={form.full_name}
                onChange={handleChange}
                className="input-field"
                placeholder="Your full name"
                style={{ width: '100%' }}
              />
            </div>

            {/* Date of Birth */}
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                <Calendar size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} /> Date of Birth
              </label>
              <input
                type="date"
                name="date_of_birth"
                value={form.date_of_birth}
                onChange={handleChange}
                className="input-field"
                style={{ width: '100%' }}
              />
            </div>

            {/* Gender */}
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                Gender
              </label>
              <select
                name="gender"
                value={form.gender}
                onChange={handleChange}
                className="input-field"
                style={{ width: '100%' }}
              >
                <option value="">Select gender</option>
                <option value="male">Male</option>
                <option value="female">Female</option>
                <option value="other">Other</option>
              </select>
            </div>

            {/* Phone */}
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                <Phone size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} /> Phone Number
              </label>
              <input
                type="tel"
                name="phone_number"
                value={form.phone_number}
                onChange={handleChange}
                className="input-field"
                placeholder="+966 5X XXX XXXX"
                style={{ width: '100%' }}
              />
            </div>

            {/* Nationality */}
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                <Globe size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} /> Nationality
              </label>
              <input
                type="text"
                name="nationality"
                value={form.nationality}
                onChange={handleChange}
                className="input-field"
                placeholder="e.g. Saudi, Jordanian..."
                style={{ width: '100%' }}
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={saving}
            className="btn-primary"
            style={{ width: '100%', marginTop: '2rem', padding: '0.85rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}
          >
            {saving ? 'Saving...' : <><Save size={18} /> Save Changes</>}
          </button>
        </form>
      </div>
    </div>
  );
};

export default ProfileEditPage;
