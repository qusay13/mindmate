import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, ClipboardList, Stethoscope, BarChart3, LogOut, MessageSquare, Sparkles, UserCircle, BookOpen } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const Sidebar = () => {
  const { user, logout } = useAuth();

  const menuItems = [
    { icon: <LayoutDashboard size={20} />, label: 'Dashboard', path: '/', roles: ['user', 'admin', 'doctor'] },
    { icon: <BarChart3 size={20} />, label: 'Analysis', path: '/analysis', roles: ['user'] },
    ...(!user?.initial_survey_completed ? [
      { icon: <ClipboardList size={20} />, label: 'Initial Survey', path: '/survey', roles: ['user'] }
    ] : []),
    { icon: <Sparkles size={20} />, label: 'MindMate AI', path: '/chatbot', roles: ['user'] },
    { icon: <Stethoscope size={20} />, label: 'Clinic', path: '/clinic', roles: ['user'] },
    { icon: <BookOpen size={20} />, label: 'Journal History', path: '/journal-history', roles: ['user'] },
    { icon: <MessageSquare size={20} />, label: 'Messages', path: '/chat', roles: ['user', 'doctor'] },
    { icon: <UserCircle size={20} />, label: 'Edit Profile', path: '/profile/edit', roles: ['user'] },
    { icon: <UserCircle size={20} />, label: 'Edit Profile', path: '/profile/doctor', roles: ['doctor'] },
  ];

  return (
    <div className="sidebar">
      <div className="brand">
        <div className="logo-icon">M</div>
        <h2>MindMate</h2>
      </div>
      
      <nav className="menu">
        {menuItems.filter(item => item.roles.includes(user?.role || 'user')).map((item) => (
          <NavLink 
            key={item.path} 
            to={item.path} 
            className={({ isActive }) => `menu-item ${isActive ? 'active' : ''}`}
          >
            {item.icon}
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="sidebar-footer">
        <button onClick={logout} className="logout-btn">
          <LogOut size={20} />
          <span>Logout</span>
        </button>
      </div>
    </div>
  );
};

export default Sidebar;
