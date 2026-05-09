import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import Dashboard from './pages/Dashboard';
import SurveyPage from './pages/SurveyPage';
import ClinicPage from './pages/ClinicPage';
import DailyAssessmentPage from './pages/DailyAssessmentPage';
import AnalysisPage from './pages/AnalysisPage';
import AdminDashboard from './pages/AdminDashboard';
import DoctorDashboard from './pages/DoctorDashboard';
import ChatPage from './pages/ChatPage';
import PatientDetailPage from './pages/PatientDetailPage';
import ChatbotPage from './pages/ChatbotPage';


const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();
  if (loading) return (
    <div className="loading-screen">
      <div className="loader"></div>
      <p>Loading...</p>
    </div>
  );
  if (!user) return <Navigate to="/login" />;
  return children;
};

const AppContent = () => {
  const { user } = useAuth();

  return (
    <div className="app-container">
      {user && <Sidebar />}
      <div className="main-content">
        {user && <Navbar />}
        <div className="page-wrapper">
          <Routes>
            <Route path="/login" element={!user ? <LoginPage /> : <Navigate to="/" />} />
            <Route path="/register" element={!user ? <RegisterPage /> : <Navigate to="/" />} />
            <Route path="/" element={
              <ProtectedRoute>
                {user?.role === 'admin' ? <AdminDashboard />
                  : user?.role === 'doctor' ? <DoctorDashboard />
                  : <Dashboard />}
              </ProtectedRoute>
            } />
            <Route path="/patient/:id" element={<ProtectedRoute><PatientDetailPage /></ProtectedRoute>} />
            <Route path="/chat" element={<ProtectedRoute><ChatPage /></ProtectedRoute>} />
            <Route path="/chatbot" element={<ProtectedRoute><ChatbotPage /></ProtectedRoute>} />
            <Route path="/analysis" element={<ProtectedRoute><AnalysisPage /></ProtectedRoute>} />
            <Route path="/survey" element={<ProtectedRoute><SurveyPage /></ProtectedRoute>} />
            <Route path="/clinic" element={<ProtectedRoute><ClinicPage /></ProtectedRoute>} />
            <Route path="/assessment/:code" element={<ProtectedRoute><DailyAssessmentPage /></ProtectedRoute>} />
          </Routes>
        </div>
      </div>
    </div>
  );
};

function App() {
  return (
    <AuthProvider>
      <Router>
        <AppContent />
      </Router>
    </AuthProvider>
  );
}

export default App;
