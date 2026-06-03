"""
tests/test_notifications.py
============================
Layer 4: Service/Dispatcher tests.
Tests the centralised notify_user / notify_doctor / notify_admin functions
including idempotency, preference screening, and Celery task triggering.
"""

import pytest
from unittest.mock import patch

from accounts.models import User, Doctor
from notifications.models import UserNotification, DoctorNotification, AdminNotification
from notifications.services import notify_user, notify_doctor, notify_admin


@pytest.mark.django_db
class TestNotifyUserService:

    def test_creates_notification_record(self, user):
        notif = notify_user(user=user, title='Hello', body='World')
        assert notif is not None
        assert notif.title == 'Hello'
        assert notif.body == 'World'
        assert UserNotification.objects.filter(notification_id=notif.notification_id).exists()

    def test_notification_has_uuid(self, user):
        notif = notify_user(user=user, title='UUID Test')
        assert notif.notification_uuid is not None

    def test_default_type_is_general(self, user):
        notif = notify_user(user=user, title='Type Test')
        assert notif.notification_type == 'general'

    def test_custom_type(self, user):
        notif = notify_user(user=user, title='Chat Msg', notif_type='chat')
        assert notif.notification_type == 'chat'

    def test_sensitive_flag_stored(self, user):
        notif = notify_user(user=user, title='Private', is_sensitive=True)
        assert notif.is_sensitive is True

    def test_related_entity_stored(self, user):
        notif = notify_user(
            user=user, title='Link',
            related_entity_type='chatroom',
            related_entity_id=42,
        )
        assert notif.related_entity_type == 'chatroom'
        assert notif.related_entity_id == 42

    # ── Idempotency ──

    def test_prevents_duplicate_with_event_key(self, user):
        n1 = notify_user(user=user, title='First', event_key='chat_15')
        n2 = notify_user(user=user, title='Duplicate', event_key='chat_15')
        assert n1.notification_id == n2.notification_id
        assert UserNotification.objects.filter(event_key='chat_15').count() == 1

    def test_different_event_keys_create_separate(self, user):
        n1 = notify_user(user=user, title='A', event_key='key_a')
        n2 = notify_user(user=user, title='B', event_key='key_b')
        assert n1.notification_id != n2.notification_id

    def test_null_event_key_always_creates(self, user):
        n1 = notify_user(user=user, title='X')
        n2 = notify_user(user=user, title='Y')
        assert n1.notification_id != n2.notification_id

    # ── Preference Screening ──

    @patch('notifications.services.send_notification_email_task')
    @patch('notifications.services.send_web_push_task')
    def test_email_task_called_when_enabled(self, mock_push, mock_email, user):
        user.email_notifications = True
        user.save(update_fields=['email_notifications'])
        notify_user(user=user, title='Email Test')
        mock_email.delay.assert_called_once()

    @patch('notifications.services.send_notification_email_task')
    @patch('notifications.services.send_web_push_task')
    def test_email_task_skipped_when_disabled(self, mock_push, mock_email, user):
        user.email_notifications = False
        user.save(update_fields=['email_notifications'])
        notify_user(user=user, title='No Email')
        mock_email.delay.assert_not_called()

    @patch('notifications.services.send_notification_email_task')
    @patch('notifications.services.send_web_push_task')
    def test_push_task_called_when_enabled(self, mock_push, mock_email, user):
        user.push_notifications = True
        user.save(update_fields=['push_notifications'])
        notify_user(user=user, title='Push Test')
        mock_push.delay.assert_called_once()

    @patch('notifications.services.send_notification_email_task')
    @patch('notifications.services.send_web_push_task')
    def test_push_task_skipped_when_disabled(self, mock_push, mock_email, user):
        user.push_notifications = False
        user.save(update_fields=['push_notifications'])
        notify_user(user=user, title='No Push')
        mock_push.delay.assert_not_called()

    @patch('notifications.services.send_notification_email_task')
    @patch('notifications.services.send_web_push_task')
    def test_both_skipped_when_both_disabled(self, mock_push, mock_email, user):
        user.email_notifications = False
        user.push_notifications = False
        user.save(update_fields=['email_notifications', 'push_notifications'])
        notif = notify_user(user=user, title='Silent')
        mock_email.delay.assert_not_called()
        mock_push.delay.assert_not_called()
        # DB record still created
        assert notif is not None


@pytest.mark.django_db
class TestNotifyDoctorService:

    @patch('notifications.services.send_notification_email_task')
    @patch('notifications.services.send_web_push_task')
    def test_creates_doctor_notification(self, mock_push, mock_email, doctor):
        notif = notify_doctor(doctor=doctor, title='Patient linked')
        assert notif is not None
        assert DoctorNotification.objects.filter(notification_id=notif.notification_id).exists()

    def test_idempotency_for_doctor(self, doctor):
        n1 = notify_doctor(doctor=doctor, title='A', event_key='doc_ev_1')
        n2 = notify_doctor(doctor=doctor, title='B', event_key='doc_ev_1')
        assert n1.notification_id == n2.notification_id

    @patch('notifications.services.send_notification_email_task')
    @patch('notifications.services.send_web_push_task')
    def test_doctor_preferences_respected(self, mock_push, mock_email, doctor):
        doctor.email_notifications = False
        doctor.push_notifications = False
        doctor.save(update_fields=['email_notifications', 'push_notifications'])
        notify_doctor(doctor=doctor, title='Silent')
        mock_email.delay.assert_not_called()
        mock_push.delay.assert_not_called()


@pytest.mark.django_db
class TestNotifyAdminService:

    def test_creates_admin_notification(self, admin):
        notif = notify_admin(admin=admin, title='New doctor registration')
        assert notif is not None
        assert AdminNotification.objects.filter(notification_id=notif.notification_id).exists()

    def test_admin_idempotency(self, admin):
        n1 = notify_admin(admin=admin, title='A', event_key='admin_1')
        n2 = notify_admin(admin=admin, title='B', event_key='admin_1')
        assert n1.notification_id == n2.notification_id
