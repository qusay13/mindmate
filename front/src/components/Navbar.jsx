import React from 'react';
import { useAuth } from '../context/AuthContext';
import { User as UserIcon } from 'lucide-react';

const Navbar = () => {
  const { user } = useAuth();

  return (
    <div className="navbar">
      <div className="user-badge">
        <div className="user-info text-right mr-3">
          <p className="font-bold text-sm">{user?.full_name}</p>
          <p className="text-xs text-secondary capitalize">{user?.role}</p>
        </div>
        <div className="avatar">
          <UserIcon size={20} className="accent" />
        </div>
      </div>
    </div>
  );
};

export default Navbar;
