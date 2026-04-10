import hashlib
from django.utils import timezone
from rest_framework.authentication import BaseAuthentication
from rest_framework import exceptions
from .models import UserSession

class CustomTokenAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return None

        try:
            prefix, token = auth_header.split(' ')
            if prefix.lower() != 'bearer':
                return None
        except ValueError:
            raise exceptions.AuthenticationFailed('Invalid token header. No credentials provided.')

        token_hash = hashlib.sha256(token.encode()).hexdigest()

        try:
            session = UserSession.objects.select_related('user', 'doctor', 'admin').get(token_hash=token_hash)
        except UserSession.DoesNotExist:
            raise exceptions.AuthenticationFailed('Invalid token.')

        if session.expires_at < timezone.now():
            session.delete()
            raise exceptions.AuthenticationFailed('Session expired. Please log in again.')

        user_obj = session.user or session.doctor or session.admin

        if not user_obj:
            raise exceptions.AuthenticationFailed('User associated with this token no longer exists.')

        # Some models don't have is_active (like Admin). We should check if hasattr or just user/doctor
        if hasattr(user_obj, 'is_active') and not user_obj.is_active:
            raise exceptions.AuthenticationFailed('User account is disabled.')

        # For doctor, we might want to check status, but perhaps that's permission level.
        # Attach the session to the request for possible further use.
        request.auth_session = session

        # Returning user_obj acts as request.user in DRF views
        return (user_obj, token)
