import React from 'react';
import { useAuth } from '../context/AuthContext';

const Navbar = () => {
  const { user } = useAuth();

  const initials = user?.full_name
    ? user.full_name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
    : 'U';

  return (
    <div className="navbar">
      <div className="user-badge">
        <div style={{ textAlign: 'right' }}>
          <p style={{ fontSize: '14px', fontWeight: 600, lineHeight: 1.3 }}>{user?.full_name}</p>
          <p style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'capitalize' }}>{user?.role}</p>
        </div>
        <div className="avatar">
          {initials}
        </div>
      </div>
    </div>
  );
};

export default Navbar;
