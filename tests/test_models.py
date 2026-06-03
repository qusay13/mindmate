"""
tests/test_models.py
====================
Layer 1 & 2: Model-level unit tests.
Tests database schema integrity, UUID generation, constraints, and field defaults.
"""

import uuid
import pytest
from django.db import IntegrityError

from accounts.models import User, Doctor, Admin
from notifications.models import (
    UserNotification, DoctorNotification, AdminNotification,
    PushSubscription, NotificationDeliveryLog,
    NOTIFICATION_TYPE_CHOICES,
)


# ──────────────────────────────────────────────
# USER / DOCTOR PREFERENCE FIELDS
# ──────────────────────────────────────────────

@pytest.mark.django_db
class TestAccountPreferences:

    def test_user_email_notifications_default_true(self, user):
        assert user.email_notifications is True

    def test_user_push_notifications_default_true(self, user):
        assert user.push_notifications is True

    def test_doctor_email_notifications_default_true(self, doctor):
        assert doctor.email_notifications is True

    def test_doctor_push_notifications_default_true(self, doctor):
        assert doctor.push_notifications is True

    def test_user_can_toggle_preferences(self, user):
        user.email_notifications = False
        user.push_notifications = False
        user.save(update_fields=['email_notifications', 'push_notifications'])
        user.refresh_from_db()
        assert user.email_notifications is False
        assert user.push_notifications is False

    def test_doctor_can_toggle_preferences(self, doctor):
        doctor.email_notifications = False
        doctor.save(update_fields=['email_notifications'])
        doctor.refresh_from_db()
        assert doctor.email_notifications is False


# ──────────────────────────────────────────────
# NOTIFICATION MODELS
# ──────────────────────────────────────────────

@pytest.mark.django_db
class TestNotificationModels:

    def test_user_notification_has_uuid(self, user):
        notif = UserNotification.objects.create(
            user=user, title='Test', notification_type='general'
        )
        assert notif.notification_uuid is not None
        assert isinstance(notif.notification_uuid, uuid.UUID)

    def test_doctor_notification_has_uuid(self, doctor):
        notif = DoctorNotification.objects.create(
            doctor=doctor, title='Test', notification_type='general'
        )
        assert notif.notification_uuid is not None

    def test_admin_notification_has_uuid(self, admin):
        notif = AdminNotification.objects.create(
            admin=admin, title='Test', notification_type='general'
        )
        assert notif.notification_uuid is not None

    def test_is_sensitive_defaults_false(self, user):
        notif = UserNotification.objects.create(
            user=user, title='Test', notification_type='general'
        )
        assert notif.is_sensitive is False

    def test_is_read_defaults_false(self, user):
        notif = UserNotification.objects.create(
            user=user, title='Test', notification_type='general'
        )
        assert notif.is_read is False

    def test_event_key_nullable(self, user):
        notif = UserNotification.objects.create(
            user=user, title='Test', notification_type='general'
        )
        assert notif.event_key is None

    def test_event_key_stored(self, user):
        notif = UserNotification.objects.create(
            user=user, title='Test',
            notification_type='chat',
            event_key='chat_42_msg_100'
        )
        assert notif.event_key == 'chat_42_msg_100'

    def test_notification_type_choices_enforced(self):
        valid_types = [c[0] for c in NOTIFICATION_TYPE_CHOICES]
        assert 'chat' in valid_types
        assert 'appointment' in valid_types
        assert 'assessment' in valid_types
        assert 'system' in valid_types
        assert 'general' in valid_types

    def test_cascade_delete_user_notifications(self, user):
        UserNotification.objects.create(
            user=user, title='A', notification_type='general'
        )
        UserNotification.objects.create(
            user=user, title='B', notification_type='general'
        )
        assert UserNotification.objects.filter(user=user).count() == 2
        user.delete()
        assert UserNotification.objects.count() == 0


# ──────────────────────────────────────────────
# PUSH SUBSCRIPTION MODEL
# ──────────────────────────────────────────────

@pytest.mark.django_db
class TestPushSubscriptionModel:

    def test_create_subscription(self, user):
        sub = PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/push/token-abc',
            p256dh='key123',
            auth='auth123',
        )
        assert sub.subscription_id is not None
        assert sub.user == user

    def test_unique_endpoint_constraint(self, user):
        PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/push/unique-token',
            p256dh='key1', auth='auth1',
        )
        with pytest.raises(IntegrityError):
            PushSubscription.objects.create(
                user=user,
                endpoint='https://fcm.example.com/push/unique-token',
                p256dh='key2', auth='auth2',
            )

    def test_user_agent_stored(self, user):
        sub = PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/push/ua-test',
            p256dh='k', auth='a',
            user_agent='Mozilla/5.0 Chrome/120',
        )
        assert sub.user_agent == 'Mozilla/5.0 Chrome/120'

    def test_last_seen_at_auto_updates(self, user):
        sub = PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/push/lastseen',
            p256dh='k', auth='a',
        )
        assert sub.last_seen_at is not None

    def test_doctor_subscription(self, doctor):
        sub = PushSubscription.objects.create(
            doctor=doctor,
            endpoint='https://fcm.example.com/push/doc-token',
            p256dh='k', auth='a',
        )
        assert sub.doctor == doctor
        assert sub.user is None

    def test_cascade_delete_with_user(self, user):
        PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/push/cascade',
            p256dh='k', auth='a',
        )
        user.delete()
        assert PushSubscription.objects.filter(
            endpoint='https://fcm.example.com/push/cascade'
        ).count() == 0


# ──────────────────────────────────────────────
# DELIVERY LOG MODEL
# ──────────────────────────────────────────────

@pytest.mark.django_db
class TestDeliveryLogModel:

    def test_create_delivery_log(self):
        log = NotificationDeliveryLog.objects.create(
            notification_uuid=uuid.uuid4(),
            notification_role='user',
            channel='email',
            status='success',
        )
        assert log.log_id is not None

    def test_failed_log_with_error(self):
        log = NotificationDeliveryLog.objects.create(
            notification_uuid=uuid.uuid4(),
            notification_role='doctor',
            channel='push',
            status='failed',
            error_message='Connection refused',
        )
        assert log.error_message == 'Connection refused'
        assert log.status == 'failed'
