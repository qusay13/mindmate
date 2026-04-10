import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000/api/';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor to add token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('mindmate_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
}, (error) => {
  return Promise.reject(error);
});

export const authAPI = {
  login: (credentials) => api.post('accounts/login/', credentials),
  registerUser: (data) => api.post('accounts/register/user/', data),
  registerDoctor: (data) => api.post('accounts/register/doctor/', data),
  logout: () => api.post('accounts/logout/'),
};

export const surveyAPI = {
  getQuestions: () => api.get('survey/questions/'),
  submitResponses: (data) => api.post('survey/submit/', data),
};

export const trackingAPI = {
  getMood: () => api.get('tracking/mood/'),
  saveMood: (data) => api.post('tracking/mood/', data),
  getJournal: () => api.get('tracking/journal/'),
  saveJournal: (data) => api.post('tracking/journal/', data),
  getProgress: () => api.get('tracking/progress/'),
  getQuestionnaireTypes: () => api.get('tracking/questionnaires/'),
  getQuestionnaireQuestions: (code) => api.get(`tracking/questionnaires/${code}/questions/`),
  submitQuestionnaire: (data) => api.post('tracking/questionnaires/submit/', data),
};


export const clinicAPI = {
  getDoctors: () => api.get('clinic/doctors/list/'),
  getDoctorDetail: (id) => api.get(`clinic/doctors/${id}/`),
  getDoctorContact: (id) => api.get(`clinic/doctors/${id}/contact/`),
  linkWithDoctor: (data) => api.post('clinic/link/', data),
  approveDoctor: (id, data) => api.patch(`clinic/doctors/${id}/approve/`, data),
};


export default api;
