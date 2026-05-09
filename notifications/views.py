from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from .models import UserNotification, DoctorNotification
from .serializers import UserNotificationSerializer, DoctorNotificationSerializer
from accounts.authentication import CustomTokenAuthentication

class UserNotificationListView(generics.ListAPIView):
    serializer_class = UserNotificationSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return UserNotification.objects.filter(user=self.request.user).order_by('-created_at')

class UserNotificationReadView(APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, notification_id):
        try:
            notif = UserNotification.objects.get(pk=notification_id, user=request.user)
            notif.is_read = True
            notif.read_at = timezone.now()
            notif.save()
            return Response({'message': 'Notification marked as read'})
        except UserNotification.DoesNotExist:
            return Response({'error': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

class DoctorNotificationListView(generics.ListAPIView):
    serializer_class = DoctorNotificationSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if not hasattr(self.request.user, 'doctor_id'):
            return DoctorNotification.objects.none()
        return DoctorNotification.objects.filter(doctor=self.request.user).order_by('-created_at')

class DoctorNotificationReadView(APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, notification_id):
        try:
            if not hasattr(request.user, 'doctor_id'):
                return Response({'error': 'Only doctors can access this'}, status=status.HTTP_403_FORBIDDEN)
            notif = DoctorNotification.objects.get(pk=notification_id, doctor=request.user)
            notif.is_read = True
            notif.read_at = timezone.now()
            notif.save()
            return Response({'message': 'Notification marked as read'})
        except DoctorNotification.DoesNotExist:
            return Response({'error': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)
