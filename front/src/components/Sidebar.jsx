import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, ClipboardList, Stethoscope, MessageSquare, Bell, LogOut } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const Sidebar = () => {
  const { logout, user } = useAuth();

  const menuItems = [
    { icon: <LayoutDashboard size={20} />, label: 'Dashboard', path: '/' },
    { icon: <ClipboardList size={20} />, label: 'Survey', path: '/survey' },
    { icon: <Stethoscope size={20} />, label: 'Clinic', path: '/clinic' },
    { icon: <MessageSquare size={20} />, label: 'Chatbot', path: '/chat' },
    { icon: <Bell size={20} />, label: 'Notifications', path: '/notifications' },
  ];

  return (
    <div className="sidebar">
      <div className="brand">
        <div className="logo-icon">M</div>
        <h2>MindMate</h2>
      </div>
      
      <nav className="menu">
        {menuItems.map((item) => (
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
