"""
tests/test_tasks.py
===================
Layer 5 & 6: Celery Tasks and Web Push delivery tests.
Tests async workers, HTML styling compilation, exception resilience, and auto-pruning.
"""

import json
import uuid
import pytest
from unittest.mock import patch, MagicMock
from django.conf import settings
from pywebpush import WebPushException

from accounts.models import User, Doctor
from notifications.models import PushSubscription, NotificationDeliveryLog
from notifications.tasks import send_notification_email_task, send_web_push_task

@pytest.mark.django_db
class TestEmailTasks:
    @patch('notifications.tasks.send_mail')
    def test_email_task_success_logs_correctly(self, mock_send_mail, user):
        notif_uuid = str(uuid.uuid4())
        send_notification_email_task(
            notification_uuid_str=notif_uuid,
            user_id_str=str(user.user_id),
            role='user',
            title='Clinical Update',
            body='Check your portal'
        )
        
        # Verify call arguments
        mock_send_mail.assert_called_once()
        # Verify Delivery Log
        log = NotificationDeliveryLog.objects.get(notification_uuid=notif_uuid)
        assert log.status == 'success'
        assert log.channel == 'email'

    @patch('notifications.tasks.send_mail')
    def test_email_task_failure_logs_correctly(self, mock_send_mail, user):
        mock_send_mail.side_effect = Exception("SMTP Connection Failed")
        notif_uuid = str(uuid.uuid4())
        
        with pytest.raises(Exception):
            send_notification_email_task(
                notification_uuid_str=notif_uuid,
                user_id_str=str(user.user_id),
                role='user',
                title='Failing Email',
                body='Will fail'
            )
            
        log = NotificationDeliveryLog.objects.get(notification_uuid=notif_uuid)
        assert log.status == 'failed'
        assert 'SMTP Connection Failed' in log.error_message

    @patch('notifications.tasks.send_mail')
    def test_celery_retry_on_smtp_exception(self, mock_send_mail, user):
        """
        Verify that an SMTP failure raises an exception to trigger the Celery retry handler.
        Since autoretry_for=(Exception,) is set on the task, raising the exception
        is the exact mechanism Celery intercepts to perform backoff scheduling.
        """
        mock_send_mail.side_effect = Exception("SMTP Temporary Timeout")
        notif_uuid = str(uuid.uuid4())
        
        with pytest.raises(Exception) as exc_info:
            send_notification_email_task(
                notification_uuid_str=notif_uuid,
                user_id_str=str(user.user_id),
                role='user',
                title='Retry Testing',
                body='Simulated SMTP failure'
            )
        
        assert "SMTP Temporary Timeout" in str(exc_info.value)


@pytest.mark.django_db
class TestWebPushTasks:
    @patch('pywebpush.webpush')
    def test_push_task_success_logs(self, mock_webpush, user):
        sub = PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/api/success',
            p256dh='k', auth='a'
        )
        
        notif_uuid = str(uuid.uuid4())
        payload = {
            'notification_uuid': notif_uuid,
            'title': 'Test Push',
            'body': 'Payload text',
            'is_sensitive': False
        }
        
        original_vapid = getattr(settings, 'VAPID_PRIVATE_KEY', None)
        settings.VAPID_PRIVATE_KEY = 'mock_key'
        
        send_web_push_task(notif_uuid, str(user.user_id), 'user', payload)
        
        mock_webpush.assert_called_once()
        log = NotificationDeliveryLog.objects.get(notification_uuid=notif_uuid)
        assert log.status == 'success'
        assert log.channel == 'push'
        
        settings.VAPID_PRIVATE_KEY = original_vapid

    @patch('pywebpush.webpush')
    def test_push_sensitive_payload_masking(self, mock_webpush, user):
        sub = PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/api/sensitive',
            p256dh='k', auth='a'
        )
        
        notif_uuid = str(uuid.uuid4())
        payload = {
            'notification_uuid': notif_uuid,
            'title': 'Private Health Assessment Results',
            'body': 'Patient diagnosed with clinical anxiety and mood swings.',
            'is_sensitive': True
        }
        
        original_vapid = getattr(settings, 'VAPID_PRIVATE_KEY', None)
        settings.VAPID_PRIVATE_KEY = 'mock_key'
        
        send_web_push_task(notif_uuid, str(user.user_id), 'user', payload)
        
        sent_data = json.loads(mock_webpush.call_args[1]['data'])
        assert sent_data['title'] == 'Secure Alert'
        assert sent_data['body'] == 'You have a new secure notification'
        
        settings.VAPID_PRIVATE_KEY = original_vapid

    @patch('pywebpush.webpush')
    def test_dead_endpoint_auto_pruned(self, mock_webpush, user):
        sub = PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/api/dead',
            p256dh='k', auth='a'
        )
        
        mock_resp = MagicMock()
        mock_resp.status_code = 410
        mock_webpush.side_effect = WebPushException("Subscription no longer active", response=mock_resp)
        
        notif_uuid = str(uuid.uuid4())
        payload = {'notification_uuid': notif_uuid, 'title': 'Alert', 'body': 'Text'}
        
        original_vapid = getattr(settings, 'VAPID_PRIVATE_KEY', None)
        settings.VAPID_PRIVATE_KEY = 'mock_key'
        
        send_web_push_task(notif_uuid, str(user.user_id), 'user', payload)
        
        assert not PushSubscription.objects.filter(endpoint=sub.endpoint).exists()
        
        settings.VAPID_PRIVATE_KEY = original_vapid
