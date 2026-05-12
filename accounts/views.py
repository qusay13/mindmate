import hashlib
import secrets
from datetime import timedelta
from django.utils import timezone
from rest_framework import status, views, permissions, generics
from rest_framework.response import Response
from .serializers import (
    UserRegistrationSerializer, DoctorRegistrationSerializer,
    LoginSerializer, UserSerializer, DoctorSerializer, AdminSerializer
)
from .models import User, Doctor, Admin, UserSession
from .authentication import CustomTokenAuthentication


# ============================================================
# REGISTRATION
# ============================================================

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


# ============================================================
# LOGIN / LOGOUT
# ============================================================

class LoginView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email    = serializer.validated_data['email']
        password = serializer.validated_data['password']
        role     = serializer.validated_data['role']

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
        token      = secrets.token_urlsafe(64)
        token_hash = hashlib.sha256(token.encode()).hexdigest()

        # Capture IP & User-Agent
        ip_address = request.META.get('HTTP_X_FORWARDED_FOR')
        if ip_address:
            ip_address = ip_address.split(',')[0]
        else:
            ip_address = request.META.get('REMOTE_ADDR')

        device_info = {'user_agent': request.META.get('HTTP_USER_AGENT', 'Unknown')}
        expires_at  = timezone.now() + timedelta(days=7)

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

        response_data = {'token': token, 'expires_at': expires_at, 'role': role}
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


# ============================================================
# EMAIL VERIFICATION
# ============================================================

class RequestEmailVerificationView(views.APIView):
    """
    POST /api/accounts/email/verify/request/
    Body: { "email": "...", "role": "user" | "doctor" }
    يرسل رابط تأكيد البريد الإلكتروني.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from .models import AuthToken
        from django.core.mail import send_mail

        email = request.data.get('email', '').strip().lower()
        role  = request.data.get('role', 'user')

        if not email:
            return Response({'error': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if role not in ('user', 'doctor'):
            return Response({'error': 'role must be user or doctor.'}, status=status.HTTP_400_BAD_REQUEST)

        owner = None
        if role == 'user':
            owner = User.objects.filter(email=email).first()
        else:
            owner = Doctor.objects.filter(email=email).first()

        # Always return same message (no enumeration)
        if not owner:
            return Response({'message': 'If this email is registered, a verification link has been sent.'})

        # Remove old verification tokens
        old_qs = AuthToken.objects.filter(token_type='email_verification')
        old_qs.filter(user=owner).delete() if role == 'user' else old_qs.filter(doctor=owner).delete()

        # Create token (24 h)
        raw_token  = secrets.token_urlsafe(48)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        token_data = {
            'token_hash': token_hash,
            'token_type': 'email_verification',
            'expires_at': timezone.now() + timedelta(hours=24),
        }
        if role == 'user':
            token_data['user'] = owner
        else:
            token_data['doctor'] = owner
        AuthToken.objects.create(**token_data)

        # Send email
        verify_url = f"http://localhost:5173/verify-email?token={raw_token}&role={role}"
        send_mail(
            subject='MindMate — تأكيد البريد الإلكتروني',
            message=(
                f'مرحباً {getattr(owner, "full_name", None) or email}،\n\n'
                f'اضغط على الرابط التالي لتأكيد بريدك الإلكتروني:\n{verify_url}\n\n'
                f'الرابط صالح لمدة 24 ساعة.\n\nفريق MindMate'
            ),
            from_email='noreply@mindmate.app',
            recipient_list=[email],
            fail_silently=True,
        )

        return Response({'message': 'If this email is registered, a verification link has been sent.'})


class VerifyEmailView(views.APIView):
    """
    POST /api/accounts/email/verify/confirm/
    Body: { "token": "..." }
    يفعّل الحساب بعد التحقق من الـ token.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from .models import AuthToken

        raw_token  = request.data.get('token', '').strip()
        if not raw_token:
            return Response({'error': 'Token is required.'}, status=status.HTTP_400_BAD_REQUEST)

        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        try:
            auth_token = AuthToken.objects.get(token_hash=token_hash, token_type='email_verification')
        except AuthToken.DoesNotExist:
            return Response({'error': 'Invalid or expired token.'}, status=status.HTTP_400_BAD_REQUEST)

        if auth_token.is_expired:
            auth_token.delete()
            return Response({'error': 'Token has expired. Please request a new verification link.'}, status=status.HTTP_400_BAD_REQUEST)

        if auth_token.is_used:
            return Response({'error': 'This token has already been used.'}, status=status.HTTP_400_BAD_REQUEST)

        # Mark token used
        auth_token.used_at = timezone.now()
        auth_token.save(update_fields=['used_at'])

        # Activate the owner
        owner = auth_token.user or auth_token.doctor
        if owner:
            owner.is_active = True
            owner.save(update_fields=['is_active'])

        return Response({'message': 'Email verified successfully. You can now log in.'})


# ============================================================
# PASSWORD RESET
# ============================================================

class RequestPasswordResetView(views.APIView):
    """
    POST /api/accounts/password/reset/request/
    Body: { "email": "...", "role": "user" | "doctor" }
    يرسل رابط إعادة تعيين كلمة المرور.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from .models import AuthToken
        from django.core.mail import send_mail

        email = request.data.get('email', '').strip().lower()
        role  = request.data.get('role', 'user')

        if not email:
            return Response({'error': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if role not in ('user', 'doctor'):
            return Response({'error': 'role must be user or doctor.'}, status=status.HTTP_400_BAD_REQUEST)

        owner = None
        if role == 'user':
            owner = User.objects.filter(email=email).first()
        else:
            owner = Doctor.objects.filter(email=email).first()

        if not owner:
            return Response({'message': 'If this email is registered, a reset link has been sent.'})

        # Remove previous reset tokens
        old_qs = AuthToken.objects.filter(token_type='password_reset')
        old_qs.filter(user=owner).delete() if role == 'user' else old_qs.filter(doctor=owner).delete()

        # Create token (1 h)
        raw_token  = secrets.token_urlsafe(48)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        token_data = {
            'token_hash': token_hash,
            'token_type': 'password_reset',
            'expires_at': timezone.now() + timedelta(hours=1),
        }
        if role == 'user':
            token_data['user'] = owner
        else:
            token_data['doctor'] = owner
        AuthToken.objects.create(**token_data)

        # Send email
        reset_url = f"http://localhost:5173/reset-password?token={raw_token}&role={role}"
        send_mail(
            subject='MindMate — إعادة تعيين كلمة المرور',
            message=(
                f'مرحباً {getattr(owner, "full_name", None) or email}،\n\n'
                f'اضغط على الرابط التالي لإعادة تعيين كلمة المرور:\n{reset_url}\n\n'
                f'الرابط صالح لمدة ساعة واحدة فقط.\n'
                f'إذا لم تطلب هذا، تجاهل هذه الرسالة.\n\nفريق MindMate'
            ),
            from_email='noreply@mindmate.app',
            recipient_list=[email],
            fail_silently=True,
        )

        return Response({'message': 'If this email is registered, a reset link has been sent.'})


class ResetPasswordView(views.APIView):
    """
    POST /api/accounts/password/reset/confirm/
    Body: { "token": "...", "new_password": "..." }
    يضبط كلمة المرور الجديدة ويلغي جميع الجلسات.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from .models import AuthToken

        raw_token    = request.data.get('token', '').strip()
        new_password = request.data.get('new_password', '').strip()

        if not raw_token or not new_password:
            return Response({'error': 'token and new_password are required.'}, status=status.HTTP_400_BAD_REQUEST)
        if len(new_password) < 8:
            return Response({'error': 'Password must be at least 8 characters.'}, status=status.HTTP_400_BAD_REQUEST)

        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        try:
            auth_token = AuthToken.objects.get(token_hash=token_hash, token_type='password_reset')
        except AuthToken.DoesNotExist:
            return Response({'error': 'Invalid or expired token.'}, status=status.HTTP_400_BAD_REQUEST)

        if auth_token.is_expired:
            auth_token.delete()
            return Response({'error': 'Token has expired. Please request a new one.'}, status=status.HTTP_400_BAD_REQUEST)

        if auth_token.is_used:
            return Response({'error': 'Token has already been used.'}, status=status.HTTP_400_BAD_REQUEST)

        owner = auth_token.user or auth_token.doctor
        if not owner:
            return Response({'error': 'Invalid token.'}, status=status.HTTP_400_BAD_REQUEST)

        # Set new password
        owner.set_password(new_password)
        owner.save(update_fields=['password'])

        # Mark token used
        auth_token.used_at = timezone.now()
        auth_token.save(update_fields=['used_at'])

        # Revoke all active sessions for security
        if hasattr(owner, 'user_id'):
            UserSession.objects.filter(user=owner).delete()
        elif hasattr(owner, 'doctor_id'):
            UserSession.objects.filter(doctor=owner).delete()

        return Response({'message': 'Password reset successfully. Please log in with your new password.'})


# ============================================================
# ADMIN STATISTICS
# ============================================================

class AdminPlatformStatsView(views.APIView):
    """
    GET /api/accounts/admin/stats/
    Returns general statistics for the admin dashboard.
    """
    authentication_classes = [CustomTokenAuthentication]

    def get(self, request):
        if not hasattr(request.user, 'admin_id'):
            return Response({'error': 'Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        from tracking.models import DailyProgress, QuestionnaireSession, DailyMoodEntry
        from django.db.models import Avg

        total_users = User.objects.count()
        total_doctors = Doctor.objects.count()
        pending_doctors = Doctor.objects.filter(status='pending').count()
        
        total_assessments = QuestionnaireSession.objects.filter(completed=True).count()
        
        # Calculate a mock or derived wellbeing score if actual score doesn't exist yet
        total_moods = DailyMoodEntry.objects.count()
        
        return Response({
            'total_users': total_users,
            'total_doctors': total_doctors,
            'pending_doctors': pending_doctors,
            'total_assessments': total_assessments,
            'average_wellbeing_score': 85.0  # Placeholder
        })


class AdminUserListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated] # Simplified check
    serializer_class = UserSerializer

    def get_queryset(self):
        if not hasattr(self.request.user, 'admin_id'):
            return User.objects.none()
        return User.objects.all().order_by('-created_at')


class AdminDeactivateUserView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    
    def post(self, request, user_id):
        if not hasattr(request.user, 'admin_id'):
            return Response({'error': 'Unauthorized'}, status=403)
        try:
            user = User.objects.get(user_id=user_id)
            user.is_active = not user.is_active # Toggle
            if not user.is_active:
                user.deleted_at = timezone.now()
            else:
                user.deleted_at = None
            user.save()
            return Response({'message': f'User {"deactivated" if not user.is_active else "activated"} successfully', 'is_active': user.is_active})
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=404)


class AdminDeactivateDoctorView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]

    def post(self, request, doctor_id):
        if not hasattr(request.user, 'admin_id'):
            return Response({'error': 'Unauthorized'}, status=403)
        try:
            doctor = Doctor.objects.get(doctor_id=doctor_id)
            doctor.is_active = not doctor.is_active
            if not doctor.is_active:
                doctor.deleted_at = timezone.now()
            else:
                doctor.deleted_at = None
            doctor.save()
            return Response({'message': f'Doctor {"deactivated" if not doctor.is_active else "activated"} successfully', 'is_active': doctor.is_active})
        except Doctor.DoesNotExist:
            return Response({'error': 'Doctor not found'}, status=404)


# ============================================================
# PROFILE UPDATE
# ============================================================

class UserProfileUpdateView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'user_id'):
            return Response({'error': 'Only patients can access this endpoint'}, status=403)
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        if not hasattr(request.user, 'user_id'):
            return Response({'error': 'Only patients can access this endpoint'}, status=403)
        user = request.user
        allowed_fields = ['full_name', 'date_of_birth', 'gender', 'phone_number', 'nationality', 'profile_image']
        data = {k: v for k, v in request.data.items() if k in allowed_fields}
        # Handle file upload
        if 'profile_image' in request.FILES:
            data['profile_image'] = request.FILES['profile_image']
        for field, value in data.items():
            setattr(user, field, value)
        user.save()
        return Response(UserSerializer(user).data)


class DoctorProfileUpdateView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'doctor_id'):
            return Response({'error': 'Only doctors can access this endpoint'}, status=403)
        serializer = DoctorSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        if not hasattr(request.user, 'doctor_id'):
            return Response({'error': 'Only doctors can access this endpoint'}, status=403)
        doctor = request.user
        allowed_fields = ['full_name', 'specialization', 'bio', 'whatsapp_number', 'is_whatsapp_visible', 'nationality', 'profile_image']
        data = {k: v for k, v in request.data.items() if k in allowed_fields}
        if 'profile_image' in request.FILES:
            data['profile_image'] = request.FILES['profile_image']
        for field, value in data.items():
            setattr(doctor, field, value)
        doctor.save()
        return Response(DoctorSerializer(doctor).data)
