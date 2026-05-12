from rest_framework import generics, views, permissions, status
from rest_framework.response import Response
from django.utils import timezone
from accounts.authentication import CustomTokenAuthentication
from .models import UserNotification, DoctorNotification


# ============================================================
# PERMISSION HELPERS
# ============================================================

class IsUserPermission(permissions.BasePermission):
    def has_permission(self, request, view):
        return hasattr(request.user, 'user_id')


class IsDoctorPermission(permissions.BasePermission):
    def has_permission(self, request, view):
        return hasattr(request.user, 'doctor_id') and request.user.status == 'approved'


# ============================================================
# USER NOTIFICATIONS
# ============================================================

class UserNotificationListView(generics.ListAPIView):
    """
    GET /api/notifications/user/
    يعيد قائمة الإشعارات الخاصة بالمستخدم (الأحدث أولاً).
    Query params:
      ?unread=true  — إشعارات غير مقروءة فقط
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [IsUserPermission]

    def get_queryset(self):
        qs = UserNotification.objects.filter(user=self.request.user).order_by('-created_at')
        if self.request.query_params.get('unread') == 'true':
            qs = qs.filter(is_read=False)
        return qs[:50]   # أحدث 50 إشعار

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        data = [
            {
                'notification_id':     n.notification_id,
                'title':               n.title,
                'body':                n.body,
                'notification_type':   n.notification_type,
                'related_entity_type': n.related_entity_type,
                'related_entity_id':   n.related_entity_id,
                'is_read':             n.is_read,
                'created_at':          n.created_at,
                'read_at':             n.read_at,
            }
            for n in qs
        ]
        unread_count = UserNotification.objects.filter(user=request.user, is_read=False).count()
        return Response({'unread_count': unread_count, 'notifications': data})


class UserNotificationMarkReadView(views.APIView):
    """
    POST /api/notifications/user/mark-read/
    Body (optional): { "notification_ids": [1, 2, 3] }
    إذا لم يُرسَل الـ body يُعلَّم الكل مقروءاً.
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [IsUserPermission]

    def post(self, request):
        ids = request.data.get('notification_ids')
        now = timezone.now()

        qs = UserNotification.objects.filter(user=request.user, is_read=False)
        if ids:
            qs = qs.filter(notification_id__in=ids)

        updated = qs.update(is_read=True, read_at=now)
        return Response({'message': f'{updated} notification(s) marked as read.'})


class UserNotificationDeleteView(views.APIView):
    """
    DELETE /api/notifications/user/<notification_id>/
    يحذف إشعاراً واحداً للمستخدم.
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [IsUserPermission]

    def delete(self, request, notification_id):
        try:
            notif = UserNotification.objects.get(
                notification_id=notification_id,
                user=request.user
            )
            notif.delete()
            return Response({'message': 'Notification deleted.'}, status=status.HTTP_204_NO_CONTENT)
        except UserNotification.DoesNotExist:
            return Response({'error': 'Notification not found.'}, status=status.HTTP_404_NOT_FOUND)


# ============================================================
# DOCTOR NOTIFICATIONS
# ============================================================

class DoctorNotificationListView(generics.ListAPIView):
    """
    GET /api/notifications/doctor/
    يعيد قائمة الإشعارات الخاصة بالطبيب.
    Query params:
      ?unread=true  — إشعارات غير مقروءة فقط
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [IsDoctorPermission]

    def get_queryset(self):
        qs = DoctorNotification.objects.filter(doctor=self.request.user).order_by('-created_at')
        if self.request.query_params.get('unread') == 'true':
            qs = qs.filter(is_read=False)
        return qs[:50]

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        data = [
            {
                'notification_id':     n.notification_id,
                'title':               n.title,
                'body':                n.body,
                'notification_type':   n.notification_type,
                'related_entity_type': n.related_entity_type,
                'related_entity_id':   n.related_entity_id,
                'is_read':             n.is_read,
                'created_at':          n.created_at,
                'read_at':             n.read_at,
            }
            for n in qs
        ]
        unread_count = DoctorNotification.objects.filter(doctor=request.user, is_read=False).count()
        return Response({'unread_count': unread_count, 'notifications': data})


class DoctorNotificationMarkReadView(views.APIView):
    """
    POST /api/notifications/doctor/mark-read/
    Body (optional): { "notification_ids": [1, 2, 3] }
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [IsDoctorPermission]

    def post(self, request):
        ids = request.data.get('notification_ids')
        now = timezone.now()

        qs = DoctorNotification.objects.filter(doctor=request.user, is_read=False)
        if ids:
            qs = qs.filter(notification_id__in=ids)

        updated = qs.update(is_read=True, read_at=now)
        return Response({'message': f'{updated} notification(s) marked as read.'})


class DoctorNotificationDeleteView(views.APIView):
    """
    DELETE /api/notifications/doctor/<notification_id>/
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [IsDoctorPermission]

    def delete(self, request, notification_id):
        try:
            notif = DoctorNotification.objects.get(
                notification_id=notification_id,
                doctor=request.user
            )
            notif.delete()
            return Response({'message': 'Notification deleted.'}, status=status.HTTP_204_NO_CONTENT)
        except DoctorNotification.DoesNotExist:
            return Response({'error': 'Notification not found.'}, status=status.HTTP_404_NOT_FOUND)
