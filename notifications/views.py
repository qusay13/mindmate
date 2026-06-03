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


# ============================================================
# WEB PUSH & PREFERENCES MANAGEMENT
# ============================================================

class PushSubscriptionView(views.APIView):
    """
    POST /api/notifications/subscribe/
    Body: { "endpoint": "...", "keys": { "p256dh": "...", "auth": "..." } }
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [permissions.IsAuthenticated]

    def post(self, request):
        endpoint = request.data.get('endpoint')
        keys = request.data.get('keys', {})
        p256dh = keys.get('p256dh')
        auth = keys.get('auth')

        if not endpoint or not p256dh or not auth:
            return Response({'error': 'endpoint, p256dh, and auth are required'}, status=status.HTTP_400_BAD_REQUEST)

        user_agent = request.META.get('HTTP_USER_AGENT', '')
        user = request.user
        
        from accounts.models import User, Doctor
        from .models import PushSubscription

        sub_kwargs = {
            'endpoint': endpoint,
            'defaults': {
                'p256dh': p256dh,
                'auth': auth,
                'user_agent': user_agent,
            }
        }

        if isinstance(user, User):
            sub_kwargs['user'] = user
        elif isinstance(user, Doctor):
            sub_kwargs['doctor'] = user
        else:
            return Response({'error': 'Only users and doctors can register push subscriptions'}, status=status.HTTP_400_BAD_REQUEST)

        # Update or create dynamically linked to secure endpoint
        sub, created = PushSubscription.objects.update_or_create(
            endpoint=endpoint,
            defaults={
                'user': sub_kwargs.get('user'),
                'doctor': sub_kwargs.get('doctor'),
                'p256dh': p256dh,
                'auth': auth,
                'user_agent': user_agent,
            }
        )

        return Response({'message': 'Push subscription registered successfully', 'created': created}, status=status.HTTP_201_CREATED)


class PushUnsubscribeView(views.APIView):
    """
    POST /api/notifications/unsubscribe/
    Body: { "endpoint": "..." }
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [permissions.IsAuthenticated]

    def post(self, request):
        endpoint = request.data.get('endpoint')
        if not endpoint:
            return Response({'error': 'endpoint is required'}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        from accounts.models import User, Doctor
        from .models import PushSubscription

        qs = PushSubscription.objects.filter(endpoint=endpoint)
        if isinstance(user, User):
            qs = qs.filter(user=user)
        elif isinstance(user, Doctor):
            qs = qs.filter(doctor=user)
        else:
            return Response({'error': 'Unauthorized role'}, status=status.HTTP_403_FORBIDDEN)

        deleted, _ = qs.delete()
        return Response({'message': 'Push subscription removed successfully', 'deleted_count': deleted}, status=status.HTTP_200_OK)


class NotificationPreferencesView(views.APIView):
    """
    GET /api/notifications/preferences/
    PATCH /api/notifications/preferences/
    Body: { "email_notifications": true, "push_notifications": false }
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            'email_notifications': getattr(user, 'email_notifications', True),
            'push_notifications': getattr(user, 'push_notifications', True)
        })

    def patch(self, request):
        user = request.user
        email_pref = request.data.get('email_notifications')
        push_pref = request.data.get('push_notifications')

        update_fields = []
        if email_pref is not None:
            user.email_notifications = bool(email_pref)
            update_fields.append('email_notifications')
        if push_pref is not None:
            user.push_notifications = bool(push_pref)
            update_fields.append('push_notifications')

        if update_fields:
            user.save(update_fields=update_fields)

        return Response({
            'message': 'Preferences updated successfully',
            'email_notifications': getattr(user, 'email_notifications', True),
            'push_notifications': getattr(user, 'push_notifications', True)
        }, status=status.HTTP_200_OK)

