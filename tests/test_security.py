"""
tests/test_security.py
======================
Layer 7: Security Tests.
Tests database-level injection protection, permission barriers, and tenant isolation.
"""

import pytest
from notifications.models import PushSubscription, UserNotification, DoctorNotification

@pytest.mark.django_db
class TestSecurityAndIsolation:
    def test_user_injection_prevention(self, user_client, user, user_b):
        """
        Verify that an authenticated user cannot register a push subscription 
        for another user by providing their user ID. The backend must ignore 
        outside variables and strictly map it to request.user.
        """
        # Hitting subscribe endpoint
        resp = user_client.post('/api/notifications/subscribe/', {
            'endpoint': 'https://fcm.example.com/push/exploit',
            'keys': {'p256dh': 'p', 'auth': 'a'},
            'user_id': str(user_b.user_id),  # Attacker attempts injection
            'user': str(user_b.user_id)
        }, format='json')
        
        assert resp.status_code == 201
        
        # Verify the subscription is registered to 'user' (request.user), NOT 'user_b'
        sub = PushSubscription.objects.get(endpoint='https://fcm.example.com/push/exploit')
        assert sub.user == user
        assert sub.user != user_b

    def test_patient_cannot_access_doctor_notifications(self, user_client, doctor):
        """
        Ensure that a patient cannot hit the doctor notifications endpoint.
        """
        resp = user_client.get('/api/notifications/doctor/')
        # Should be blocked either by DRF permissions or logic
        assert resp.status_code in [403, 400]

    def test_doctor_cannot_access_patient_notifications(self, doctor_client, user):
        """
        Ensure that a doctor cannot retrieve patient notifications.
        """
        resp = doctor_client.get('/api/notifications/user/')
        assert resp.status_code in [403, 400]

    def test_user_cannot_delete_other_users_notification(self, user_client, user_b):
        """
        Prevent deleting notifications belonging to another patient.
        """
        n = UserNotification.objects.create(user=user_b, title='Secret', notification_type='general')
        resp = user_client.delete(f'/api/notifications/user/{n.notification_id}/')
        assert resp.status_code in [404, 403]
