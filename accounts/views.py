import hashlib
import secrets
from datetime import timedelta
from django.utils import timezone
from rest_framework import status, views, permissions
from rest_framework.response import Response
from .serializers import (
    UserRegistrationSerializer, DoctorRegistrationSerializer,
    LoginSerializer, UserSerializer, DoctorSerializer, AdminSerializer
)
from .models import User, Doctor, Admin, UserSession

class UserRegistrationView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = UserRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return Response({'message': 'User registered successfully', 'user_id': user.user_id}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DoctorRegistrationView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = DoctorRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            doctor = serializer.save()
            return Response({'message': 'Doctor registered successfully. Pending approval.', 'doctor_id': doctor.doctor_id}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']
        role = serializer.validated_data['role']

        user_obj = None
        if role == 'user':
            user_obj = User.objects.filter(email=email).first()
        elif role == 'doctor':
            user_obj = Doctor.objects.filter(email=email).first()
        elif role == 'admin':
            user_obj = Admin.objects.filter(email=email).first()

        if not user_obj or not user_obj.check_password(password):
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

        if hasattr(user_obj, 'is_active') and not user_obj.is_active:
            return Response({'error': 'Account is disabled'}, status=status.HTTP_403_FORBIDDEN)

        # Generate token
        token = secrets.token_urlsafe(64)
        token_hash = hashlib.sha256(token.encode()).hexdigest()

        # Capture IP & User-Agent
        ip_address = request.META.get('HTTP_X_FORWARDED_FOR')
        if ip_address:
            ip_address = ip_address.split(',')[0]
        else:
            ip_address = request.META.get('REMOTE_ADDR')
            
        device_info = {'user_agent': request.META.get('HTTP_USER_AGENT', 'Unknown')}
        expires_at = timezone.now() + timedelta(days=7)

        # Create Session
        session_data = {
            'token_hash': token_hash,
            'ip_address': ip_address,
            'device_info': device_info,
            'expires_at': expires_at,
        }
        
        if role == 'user':
            session_data['user'] = user_obj
        elif role == 'doctor':
            session_data['doctor'] = user_obj
        elif role == 'admin':
            session_data['admin'] = user_obj

        UserSession.objects.create(**session_data)

        response_data = {
            'token': token,
            'expires_at': expires_at,
            'role': role
        }
        
        if role == 'user':
            response_data['user'] = UserSerializer(user_obj).data
        elif role == 'doctor':
            response_data['doctor'] = DoctorSerializer(user_obj).data
        elif role == 'admin':
            response_data['admin'] = AdminSerializer(user_obj).data

        return Response(response_data, status=status.HTTP_200_OK)


class LogoutView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if hasattr(request, 'auth_session'):
            request.auth_session.delete()
            return Response({'message': 'Logged out successfully'}, status=status.HTTP_200_OK)
        return Response({'error': 'No active session found'}, status=status.HTTP_400_BAD_REQUEST)
