from django.urls import path
from .views import UserRegistrationView, DoctorRegistrationView, LoginView, LogoutView

urlpatterns = [
    path('register/user/', UserRegistrationView.as_view(), name='register-user'),
    path('register/doctor/', DoctorRegistrationView.as_view(), name='register-doctor'),
    path('login/', LoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
]
