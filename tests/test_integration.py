"""
tests/test_integration.py
=========================
Layer 8: Integration Tests.
Verifies the complete end-to-end notification lifecycle pipeline.
"""

import pytest
from unittest.mock import patch
from django.conf import settings

from accounts.models import User, Doctor
from notifications.models import UserNotification, PushSubscription, NotificationDeliveryLog
from notifications.services import notify_user

@pytest.mark.django_db
class TestIntegrationPipeline:
    @patch('notifications.tasks.send_mail')
    @patch('pywebpush.webpush')
    def test_end_to_end_notification_pipeline(self, mock_webpush, mock_send_mail, user):
        """
        Tests the complete multi-channel notification lifecycle:
        1. User registers push subscription endpoint.
        2. Central dispatcher triggers notification.
        3. Database record is persisted with UUID and meta.
        4. Celery email and web push tasks execute eagerly.
        5. Delivery logs verify success.
        """
        # Step 1: User registers push subscription
        sub = PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/integration-endpoint',
            p256dh='dh_val', auth='auth_val'
        )
        
        # Step 2: Central dispatcher is triggered
        original_vapid = getattr(settings, 'VAPID_PRIVATE_KEY', None)
        settings.VAPID_PRIVATE_KEY = 'mock_key'
        
        notif = notify_user(
            user=user,
            title='Daily Assessment Ready',
            body='Please log your mood and journals today.',
            notif_type='assessment',
            event_key='daily_check_today_123',
            is_sensitive=False,
            url='/assessments'
        )
        
        # Step 3: Validate database record
        assert notif is not None
        assert UserNotification.objects.filter(event_key='daily_check_today_123').exists()
        assert notif.notification_uuid is not None
        
        # Step 4: Verify task dispatches
        mock_send_mail.assert_called_once()
        mock_webpush.assert_called_once()
        
        # Step 5: Verify delivery logs are recorded
        email_log = NotificationDeliveryLog.objects.get(
            notification_uuid=str(notif.notification_uuid),
            channel='email'
        )
        push_log = NotificationDeliveryLog.objects.get(
            notification_uuid=str(notif.notification_uuid),
            channel='push'
        )
        
        assert email_log.status == 'success'
        assert push_log.status == 'success'
        
        # Cleanup VAPID overrides
        settings.VAPID_PRIVATE_KEY = original_vapid
