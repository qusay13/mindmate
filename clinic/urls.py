from django.urls import path
from .views import (
    AdminApproveDoctorView,
    DoctorListView,
    AdminDoctorListView,
    DoctorDetailView,
    DoctorContactView,
    PatientDoctorLinkView,
    DoctorPatientListView,
    DoctorPatientDetailView,
    DoctorPatientMoodHistoryView,
    DoctorPatientJournalHistoryView,
    DoctorPatientAnalysisListView,
    DoctorPatientRequestListView,
    DoctorRequestActionView
)

urlpatterns = [
    path('doctors/list/', DoctorListView.as_view(), name='doctor-list'),
    path('doctors/admin-list/', AdminDoctorListView.as_view(), name='admin-doctor-list'),
    path('doctors/<uuid:doctor_id>/', DoctorDetailView.as_view(), name='doctor-detail'),
    path('doctors/<uuid:doctor_id>/contact/', DoctorContactView.as_view(), name='doctor-contact'),
    path('doctors/<uuid:doctor_id>/approve/', AdminApproveDoctorView.as_view(), name='admin-doctor-approve'),
    path('link/', PatientDoctorLinkView.as_view(), name='patient-doctor-link'),
    path('doctor/patients/', DoctorPatientListView.as_view(), name='doctor-patient-list'),
    path('doctor/patients/<uuid:patient_id>/', DoctorPatientDetailView.as_view(), name='doctor-patient-detail'),
    path('doctor/patients/<uuid:patient_id>/mood/', DoctorPatientMoodHistoryView.as_view(), name='doctor-patient-mood'),
    path('doctor/patients/<uuid:patient_id>/journals/', DoctorPatientJournalHistoryView.as_view(), name='doctor-patient-journals'),
    path('doctor/patients/<uuid:patient_id>/analysis/', DoctorPatientAnalysisListView.as_view(), name='doctor-patient-analysis'),
    path('doctor/requests/', DoctorPatientRequestListView.as_view(), name='doctor-requests'),
    path('doctor/requests/<int:request_id>/action/', DoctorRequestActionView.as_view(), name='doctor-request-action'),
]
