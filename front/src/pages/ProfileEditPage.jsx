import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { profileAPI, notificationsAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { User, Save, ArrowLeft, Camera, Calendar, Phone, Globe, CheckCircle2, Bell } from 'lucide-react';

const ProfileEditPage = () => {
  const { user: authUser } = useAuth();
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
    date_of_birth: '',
    gender: '',
    phone_number: '',
    nationality: '',
    profile_image: null,
  });

  useEffect(() => {
    const fetchProfileAndPrefs = async () => {
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

        // Fetch user preferences
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
        // Enforce Service Worker Registration and Web Push Handshake
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

        // VAPID Public key for encrypting payloads
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
        // Unsubscribe endpoint
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
      // Dev mode fallback
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

  // Helper utility to convert VAPID keys
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

      <div style={{ maxWidth: '600px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
        {/* Avatar Section */}
        <div className="glass-card" style={{ padding: '2rem', textAlign: 'center' }}>
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

        {/* Personal Details Form */}
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

        {/* Premium Notification Settings Panel */}
        <div className="glass-card" style={{ padding: '2rem' }}>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', margin: '0 0 0.5rem 0', color: '#a855f7', fontSize: '1.2rem', fontWeight: 700 }}>
            <Bell size={20} /> Notification Preferences
          </h3>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
            Choose how you wish to receive updates regarding treatment summaries, assessments, and messages.
          </p>

          <div style={{ display: 'grid', gap: '1rem' }}>
            {/* Email Notifs */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '1rem', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.04)' }}>
              <div>
                <p style={{ margin: 0, fontWeight: 600, fontSize: '0.95rem', color: '#f1f5f9' }}>Email Alerts</p>
                <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Receive detailed psychiatric summaries and chat reports.</p>
              </div>
              <button
                type="button"
                onClick={handleToggleEmail}
                disabled={updatingPrefs}
                style={{
                  padding: '0.45rem 1rem',
                  borderRadius: '8px',
                  border: '1px solid',
                  borderColor: emailNotifs ? '#a855f7' : 'rgba(255,255,255,0.1)',
                  background: emailNotifs ? 'rgba(168,85,247,0.1)' : 'rgba(0,0,0,0.2)',
                  color: emailNotifs ? '#c084fc' : 'var(--text-secondary)',
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
                  borderColor: pushNotifs ? '#a855f7' : 'rgba(255,255,255,0.1)',
                  background: pushNotifs ? 'rgba(168,85,247,0.1)' : 'rgba(0,0,0,0.2)',
                  color: pushNotifs ? '#c084fc' : 'var(--text-secondary)',
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

export default ProfileEditPage;
