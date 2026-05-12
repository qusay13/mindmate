import React, { useState, useEffect, useRef } from 'react';
import { Bell } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { notificationsAPI } from '../services/api';

const Navbar = () => {
  const { user } = useAuth();
  const [unreadCount, setUnreadCount] = useState(0);
  const [notifications, setNotifications] = useState([]);
  const [showDropdown, setShowDropdown] = useState(false);
  const dropdownRef = useRef(null);

  const initials = user?.full_name
    ? user.full_name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
    : 'U';

  useEffect(() => {
    fetchNotifications();
    // Poll every 5 seconds for better real-time feel
    const interval = setInterval(fetchNotifications, 5000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const fetchNotifications = async () => {
    if (!user || user.role === 'admin') return;
    try {
      const endpoint = user?.role === 'doctor' ? 'doctor' : 'user';
      const res = await notificationsAPI.getNotifications(endpoint);
      
      if (res.data) {
        setNotifications(res.data.notifications || []);
        setUnreadCount(res.data.unread_count || 0);
      }
    } catch {
      // Silently fail
    }
  };

  const handleMarkAllRead = async () => {
    try {
      const endpoint = user?.role === 'doctor' ? 'doctor' : 'user';
      await notificationsAPI.markAllRead(endpoint);
      setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
    } catch {/* silent */}
  };

  const formatTime = (dateStr) => {
    const d = new Date(dateStr);
    const now = new Date();
    const diff = Math.floor((now - d) / 60000);
    if (diff < 1) return 'Just now';
    if (diff < 60) return `${diff}m ago`;
    if (diff < 1440) return `${Math.floor(diff / 60)}h ago`;
    return `${Math.floor(diff / 1440)}d ago`;
  };

  return (
    <div className="navbar">
      {/* Notification Bell */}
      <div className="notif-wrapper" ref={dropdownRef}>
        <button
          className="notif-bell"
          onClick={() => setShowDropdown(prev => !prev)}
          aria-label="Notifications"
        >
          <Bell size={20} />
          {unreadCount > 0 && (
            <span className="notif-badge">{unreadCount > 9 ? '9+' : unreadCount}</span>
          )}
        </button>

        {showDropdown && (
          <div className="notif-dropdown glass-card">
            <div className="notif-header">
              <span>Notifications</span>
              {unreadCount > 0 && (
                <button className="mark-read-btn" onClick={handleMarkAllRead}>
                  Mark all read
                </button>
              )}
            </div>

            <div className="notif-list">
              {notifications.length === 0 ? (
                <div className="notif-empty">
                  <Bell size={28} style={{ opacity: 0.3 }} />
                  <p>No notifications yet</p>
                </div>
              ) : (
                notifications.slice(0, 10).map((n, i) => (
                  <div key={i} className={`notif-item ${!n.is_read ? 'unread' : ''}`}>
                    <div className="notif-dot" />
                    <div className="notif-content">
                      <p className="notif-title">{n.title}</p>
                      <p className="notif-body">{n.body}</p>
                      <span className="notif-time">{formatTime(n.created_at)}</span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>

      {/* User Badge */}
      <div className="user-badge">
        <div style={{ textAlign: 'right' }}>
          <p style={{ fontSize: '14px', fontWeight: 600, lineHeight: 1.3 }}>{user?.full_name}</p>
          <p style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'capitalize' }}>{user?.role}</p>
        </div>
        <div className="avatar">{initials}</div>
      </div>
    </div>
  );
};

export default Navbar;
