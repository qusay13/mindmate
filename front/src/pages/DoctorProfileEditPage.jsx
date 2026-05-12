import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { profileAPI } from '../services/api';
import { Stethoscope, Save, ArrowLeft, Camera, MessageCircle, Globe, FileText, CheckCircle2, Eye, EyeOff } from 'lucide-react';

const DoctorProfileEditPage = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [previewImg, setPreviewImg] = useState(null);

  const [form, setForm] = useState({
    full_name: '',
    specialization: '',
    bio: '',
    whatsapp_number: '',
    is_whatsapp_visible: false,
    nationality: '',
    profile_image: null,
  });

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const res = await profileAPI.getDoctorProfile();
        const d = res.data;
        setForm({
          full_name: d.full_name || '',
          specialization: d.specialization || '',
          bio: d.bio || '',
          whatsapp_number: d.whatsapp_number || '',
          is_whatsapp_visible: d.is_whatsapp_visible || false,
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
    const { name, value, type, checked } = e.target;
    setForm(prev => ({ ...prev, [name]: type === 'checkbox' ? checked : value }));
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
        if (value !== null && value !== '') {
          formData.append(key, value);
        }
      });
      await profileAPI.updateDoctorProfile(formData);
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

  const avatarLetter = form.full_name?.[0]?.toUpperCase() || 'D';

  const SPECIALIZATIONS = [
    'Depression & Mood Disorders',
    'Anxiety & Panic Disorders',
    'Stress & Burnout Management',
    'Trauma & PTSD',
    'OCD & Related Disorders',
    'Child & Adolescent Psychiatry',
    'Addiction & Substance Abuse',
    'General Psychiatry',
    'Cognitive Behavioral Therapy',
    'Relationship & Family Therapy',
  ];

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
          <Stethoscope size={28} color="#00f2ff" /> Edit My Profile
        </h1>
        <p>Update your professional information, specialization, and contact details.</p>
      </header>

      <div style={{ maxWidth: '620px', margin: '0 auto' }}>
        {/* Avatar */}
        <div className="glass-card" style={{ padding: '2rem', marginBottom: '1.5rem', textAlign: 'center' }}>
          <div style={{ position: 'relative', display: 'inline-block', marginBottom: '1rem' }}>
            {previewImg ? (
              <img
                src={previewImg.startsWith('http') ? previewImg : `http://localhost:8000${previewImg}`}
                alt="Profile"
                style={{ width: 100, height: 100, borderRadius: '50%', objectFit: 'cover', border: '3px solid #00f2ff' }}
              />
            ) : (
              <div style={{
                width: 100, height: 100, borderRadius: '50%',
                background: 'linear-gradient(135deg, #00f2ff, #0066cc)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '2.5rem', fontWeight: 800, color: '#fff',
                border: '3px solid #00f2ff'
              }}>
                {avatarLetter}
              </div>
            )}
            <label htmlFor="doctor_image_input" style={{
              position: 'absolute', bottom: 0, right: 0,
              background: '#00f2ff', borderRadius: '50%', padding: '6px',
              cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center'
            }}>
              <Camera size={14} color="#000" />
            </label>
            <input id="doctor_image_input" type="file" accept="image/*" onChange={handleImageChange} style={{ display: 'none' }} />
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
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Full Name</label>
              <input type="text" name="full_name" value={form.full_name} onChange={handleChange} className="input-field" placeholder="Dr. Your Name" style={{ width: '100%' }} />
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                <Stethoscope size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} /> Specialization
              </label>
              <select name="specialization" value={form.specialization} onChange={handleChange} className="input-field" style={{ width: '100%' }}>
                <option value="">Select specialization</option>
                {SPECIALIZATIONS.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                <FileText size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} /> Professional Bio
              </label>
              <textarea
                name="bio"
                value={form.bio}
                onChange={handleChange}
                className="input-field"
                placeholder="Tell patients about your experience and approach..."
                rows={4}
                style={{ width: '100%', resize: 'vertical' }}
              />
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                <Globe size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} /> Nationality
              </label>
              <input type="text" name="nationality" value={form.nationality} onChange={handleChange} className="input-field" placeholder="e.g. Saudi, Jordanian..." style={{ width: '100%' }} />
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                <MessageCircle size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} /> WhatsApp Number
              </label>
              <input type="tel" name="whatsapp_number" value={form.whatsapp_number} onChange={handleChange} className="input-field" placeholder="+966 5X XXX XXXX" style={{ width: '100%' }} />
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', padding: '1rem', background: 'rgba(255,255,255,0.04)', borderRadius: 10, border: '1px solid rgba(255,255,255,0.08)' }}>
              <input
                type="checkbox"
                id="whatsapp_visible"
                name="is_whatsapp_visible"
                checked={form.is_whatsapp_visible}
                onChange={handleChange}
                style={{ width: 16, height: 16, accentColor: '#00f2ff' }}
              />
              <label htmlFor="whatsapp_visible" style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.9rem' }}>
                {form.is_whatsapp_visible ? <Eye size={16} color="#22c55e" /> : <EyeOff size={16} color="var(--text-secondary)" />}
                Show WhatsApp number to connected patients
              </label>
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

export default DoctorProfileEditPage;
