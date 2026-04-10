from django.urls import path
from .views import (
    AdminApproveDoctorView,
    DoctorListView,
    DoctorDetailView,
    DoctorContactView,
    PatientDoctorLinkView
)

urlpatterns = [
    path('doctors/list/', DoctorListView.as_view(), name='doctor-list'),
    path('doctors/<uuid:doctor_id>/', DoctorDetailView.as_view(), name='doctor-detail'),
    path('doctors/<uuid:doctor_id>/contact/', DoctorContactView.as_view(), name='doctor-contact'),
    path('doctors/<uuid:doctor_id>/approve/', AdminApproveDoctorView.as_view(), name='admin-doctor-approve'),
    path('link/', PatientDoctorLinkView.as_view(), name='patient-doctor-link'),
]
