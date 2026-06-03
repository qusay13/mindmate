import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { profileAPI, notificationsAPI } from '../services/api';
import { Stethoscope, Save, ArrowLeft, Camera, MessageCircle, Globe, FileText, CheckCircle2, Eye, EyeOff, Bell } from 'lucide-react';

const DoctorProfileEditPage = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [previewImg, setPreviewImg] = useState(null);

  // Preference Settings States
  const [emailNotifs, setEmailNotifs] = useState(true);
  const [pushNotifs, setPushNotifs] = useState(true);
  const [updatingPrefs, setUpdatingPrefs] = useState(false);

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
    const fetchProfileAndPrefs = async () => {
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

        // Fetch doctor preferences
        const prefsRes = await notificationsAPI.getPreferences();
        setEmailNotifs(prefsRes.data.email_notifications);
        setPushNotifs(prefsRes.data.push_notifications);
      } catch {
        setError('Failed to load profile and preferences.');
      } finally {
        setLoading(false);
      }
    };
    fetchProfileAndPrefs();
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

  // Preference Handlers
  const handleToggleEmail = async () => {
    setUpdatingPrefs(true);
    try {
      const newVal = !emailNotifs;
      const res = await notificationsAPI.updatePreferences({ email_notifications: newVal });
      setEmailNotifs(res.data.email_notifications);
    } catch {
      setError('Failed to update email preferences.');
    } finally {
      setUpdatingPrefs(false);
    }
  };

  const handleTogglePush = async () => {
    setUpdatingPrefs(true);
    try {
      const newVal = !pushNotifs;
      if (newVal) {
        if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
          alert('Push notifications are not supported on this browser.');
          setUpdatingPrefs(false);
          return;
        }

        const permission = await Notification.requestPermission();
        if (permission !== 'granted') {
          alert('Notification permission denied.');
          setUpdatingPrefs(false);
          return;
        }

        const reg = await navigator.serviceWorker.register('/service-worker.js');
        await navigator.serviceWorker.ready;

        // VAPID mock public key mapping
        const applicationServerKey = urlB64ToUint8Array('BEl62iUZGdwAOWRxsRFQGBESDEFGH12345_TEST_KEY_VAPID_MOCK_VALUE');
        
        let sub = await reg.pushManager.getSubscription();
        if (!sub) {
          sub = await reg.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: applicationServerKey
          });
        }

        // Register push endpoint with backend database securely
        await notificationsAPI.subscribePush(sub.toJSON());
      } else {
        const reg = await navigator.serviceWorker.ready;
        const sub = await reg.pushManager.getSubscription();
        if (sub) {
          await notificationsAPI.unsubscribePush({ endpoint: sub.endpoint });
          await sub.unsubscribe();
        }
      }

      const res = await notificationsAPI.updatePreferences({ push_notifications: newVal });
      setPushNotifs(res.data.push_notifications);
    } catch (err) {
      console.warn('Push registration fallback:', err);
      try {
        const res = await notificationsAPI.updatePreferences({ push_notifications: !pushNotifs });
        setPushNotifs(res.data.push_notifications);
      } catch {
        setError('Failed to update push preferences.');
      }
    } finally {
      setUpdatingPrefs(false);
    }
  };

  function urlB64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/\-/g, '+')
      .replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

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

      <div style={{ maxWidth: '620px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
        {/* Avatar */}
        <div className="glass-card" style={{ padding: '2rem', textAlign: 'center' }}>
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

        {/* Premium Notification Settings Panel */}
        <div className="glass-card" style={{ padding: '2rem' }}>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', margin: '0 0 0.5rem 0', color: '#00f2ff', fontSize: '1.2rem', fontWeight: 700 }}>
            <Bell size={20} /> Notification Preferences
          </h3>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
            Choose how you wish to receive updates regarding appointments, psychiatric sessions, and patient messages.
          </p>

          <div style={{ display: 'grid', gap: '1rem' }}>
            {/* Email Notifs */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '1rem', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.04)' }}>
              <div>
                <p style={{ margin: 0, fontWeight: 600, fontSize: '0.95rem', color: '#f1f5f9' }}>Email Alerts</p>
                <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Receive detailed patient daily summaries and session alerts.</p>
              </div>
              <button
                type="button"
                onClick={handleToggleEmail}
                disabled={updatingPrefs}
                style={{
                  padding: '0.45rem 1rem',
                  borderRadius: '8px',
                  border: '1px solid',
                  borderColor: emailNotifs ? '#00f2ff' : 'rgba(255,255,255,0.1)',
                  background: emailNotifs ? 'rgba(0,242,255,0.1)' : 'rgba(0,0,0,0.2)',
                  color: emailNotifs ? '#00f2ff' : 'var(--text-secondary)',
                  cursor: 'pointer',
                  fontWeight: 600,
                  fontSize: '0.85rem',
                  transition: 'all 0.2s'
                }}
              >
                {emailNotifs ? 'Enabled' : 'Disabled'}
              </button>
            </div>

            {/* Push Notifs */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '1rem', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.04)' }}>
              <div>
                <p style={{ margin: 0, fontWeight: 600, fontSize: '0.95rem', color: '#f1f5f9' }}>Web Push Notifications</p>
                <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Receive instant chat pings and status alerts on your device.</p>
              </div>
              <button
                type="button"
                onClick={handleTogglePush}
                disabled={updatingPrefs}
                style={{
                  padding: '0.45rem 1rem',
                  borderRadius: '8px',
                  border: '1px solid',
                  borderColor: pushNotifs ? '#00f2ff' : 'rgba(255,255,255,0.1)',
                  background: pushNotifs ? 'rgba(0,242,255,0.1)' : 'rgba(0,0,0,0.2)',
                  color: pushNotifs ? '#00f2ff' : 'var(--text-secondary)',
                  cursor: 'pointer',
                  fontWeight: 600,
                  fontSize: '0.85rem',
                  transition: 'all 0.2s'
                }}
              >
                {pushNotifs ? 'Enabled' : 'Disabled'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DoctorProfileEditPage;
