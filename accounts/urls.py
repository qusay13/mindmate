from django.urls import path
from .views import (
    UserRegistrationView, DoctorRegistrationView,
    LoginView, LogoutView,
    RequestEmailVerificationView, VerifyEmailView,
    RequestPasswordResetView, ResetPasswordView,
    AdminPlatformStatsView, AdminUserListView,
    AdminDeactivateUserView, AdminDeactivateDoctorView,
    UserProfileUpdateView, DoctorProfileUpdateView
)

urlpatterns = [
    # Registration
    path('register/user/',   UserRegistrationView.as_view(),   name='register-user'),
    path('register/doctor/', DoctorRegistrationView.as_view(), name='register-doctor'),

    # Login / Logout
    path('login/',  LoginView.as_view(),  name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),

    # Email Verification
    path('email/verify/request/', RequestEmailVerificationView.as_view(), name='email-verify-request'),
    path('email/verify/confirm/', VerifyEmailView.as_view(),              name='email-verify-confirm'),

    # Password Reset
    path('password/reset/request/', RequestPasswordResetView.as_view(), name='password-reset-request'),
    path('password/reset/confirm/', ResetPasswordView.as_view(),         name='password-reset-confirm'),

    # Admin Dashboard Actions
    path('admin/stats/', AdminPlatformStatsView.as_view(), name='admin-stats'),
    path('admin/users/', AdminUserListView.as_view(), name='admin-users-list'),
    path('admin/users/<uuid:user_id>/deactivate/', AdminDeactivateUserView.as_view(), name='admin-user-deactivate'),
    path('admin/doctors/<uuid:doctor_id>/deactivate/', AdminDeactivateDoctorView.as_view(), name='admin-doctor-deactivate'),

    # Profile Update
    path('profile/user/', UserProfileUpdateView.as_view(), name='user-profile-update'),
    path('profile/doctor/', DoctorProfileUpdateView.as_view(), name='doctor-profile-update'),
]
