import React, { useState, useEffect } from 'react';
import { clinicAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { Search, MapPin, Star, Phone, ShieldCheck, UserPlus } from 'lucide-react';

const ClinicPage = () => {
  const [doctors, setDoctors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const { user } = useAuth();
  const [linking, setLinking] = useState(null);

  useEffect(() => {
    fetchDoctors();
  }, []);

  const fetchDoctors = async () => {
    try {
      const res = await clinicAPI.getDoctors();
      setDoctors(res.data);
    } catch (err) {
      console.error('Error fetching doctors', err);
    } finally {
      setLoading(false);
    }
  };

  const handleLink = async (doctorId) => {
    setLinking(doctorId);
    try {
      await clinicAPI.linkWithDoctor({ doctor: doctorId });
      alert('Link request sent successfully!');
      fetchDoctors(); // Refresh state
    } catch (err) {
      alert(err.response?.data?.error || 'Failed to link with doctor');
    } finally {
      setLinking(null);
    }
  };

  const filteredDoctors = doctors.filter(dr => 
    dr.full_name.toLowerCase().includes(search.toLowerCase()) ||
    dr.specialization.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="clinic-page fade-in">
      <header className="page-header">
        <h1>Find Your Specialist</h1>
        <p>Connect with licensed professionals who can support your journey.</p>
        
        <div className="search-bar glass-card">
          <Search size={20} className="text-secondary" />
          <input 
            type="text" 
            placeholder="Search by name or specialization..." 
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </header>

      {loading ? (
        <div>Finding doctors...</div>
      ) : (
        <div className="doctors-grid">
          {filteredDoctors.map((dr) => (
            <div key={dr.id} className="glass-card doctor-card">
              <div className="doctor-info">
                <div className="doctor-avatar">
                  {dr.full_name.charAt(0)}
                </div>
                <div className="doctor-meta">
                  <h3>Dr. {dr.full_name}</h3>
                  <p className="specialization">{dr.specialization}</p>
                  <div className="doctor-badges">
                    <span className="badge"><Star size={14} /> 4.9</span>
                    <span className="badge"><ShieldCheck size={14} /> Verified</span>
                  </div>
                </div>
              </div>

              <div className="doctor-details">
                <p><MapPin size={16} /> {dr.clinic_address || 'Virtual Clinic'}</p>
                <div className="experience-tag">{dr.years_of_experience || 5}+ Years Experience</div>
              </div>

              <div className="doctor-actions">
                <button 
                  className="btn-primary"
                  onClick={() => handleLink(dr.id)}
                  disabled={linking === dr.id}
                >
                  <UserPlus size={18} /> {linking === dr.id ? 'Linking...' : 'Request Connection'}
                </button>
              </div>
            </div>
          ))}

          {filteredDoctors.length === 0 && (
            <div className="no-results">No specialists found matching your search.</div>
          )}
        </div>
      )}
    </div>
  );
};

export default ClinicPage;
