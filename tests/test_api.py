"""
tests/test_api.py
=================
Layer 3: REST API endpoint tests.
Tests subscribe, unsubscribe, preferences, notification CRUD via real HTTP calls.
"""

import pytest
from notifications.models import PushSubscription, UserNotification, DoctorNotification

@pytest.mark.django_db
class TestPushSubscribeAPI:
    def test_subscribe_success(self, user_client, user):
        resp = user_client.post('/api/notifications/subscribe/', {
            'endpoint': 'https://fcm.example.com/push/api-test',
            'keys': {'p256dh': 'pk1', 'auth': 'ak1'},
        }, format='json')
        assert resp.status_code == 201
        assert resp.data['created'] is True
        assert PushSubscription.objects.filter(user=user).exists()

    def test_subscribe_requires_auth(self, api_client):
        resp = api_client.post('/api/notifications/subscribe/', {
            'endpoint': 'https://fcm.example.com/push/no-auth',
            'keys': {'p256dh': 'pk', 'auth': 'ak'},
        }, format='json')
        assert resp.status_code in [401, 403]

    def test_subscribe_missing_fields(self, user_client):
        resp = user_client.post('/api/notifications/subscribe/', {
            'endpoint': 'https://fcm.example.com/push/missing',
        }, format='json')
        assert resp.status_code == 400

    def test_subscribe_update_existing(self, user_client, user):
        user_client.post('/api/notifications/subscribe/', {
            'endpoint': 'https://fcm.example.com/push/update-test',
            'keys': {'p256dh': 'old_key', 'auth': 'old_auth'},
        }, format='json')
        resp = user_client.post('/api/notifications/subscribe/', {
            'endpoint': 'https://fcm.example.com/push/update-test',
            'keys': {'p256dh': 'new_key', 'auth': 'new_auth'},
        }, format='json')
        assert resp.status_code == 201
        assert resp.data['created'] is False
        sub = PushSubscription.objects.get(endpoint='https://fcm.example.com/push/update-test')
        assert sub.p256dh == 'new_key'

    def test_doctor_can_subscribe(self, doctor_client, doctor):
        resp = doctor_client.post('/api/notifications/subscribe/', {
            'endpoint': 'https://fcm.example.com/push/doctor',
            'keys': {'p256dh': 'dk', 'auth': 'da'},
        }, format='json')
        assert resp.status_code == 201
        assert PushSubscription.objects.filter(doctor=doctor).exists()


@pytest.mark.django_db
class TestPushUnsubscribeAPI:
    def test_unsubscribe_success(self, user_client, user):
        PushSubscription.objects.create(
            user=user,
            endpoint='https://fcm.example.com/push/unsub',
            p256dh='k', auth='a',
        )
        resp = user_client.post('/api/notifications/unsubscribe/', {
            'endpoint': 'https://fcm.example.com/push/unsub',
        }, format='json')
        assert resp.status_code == 200
        assert resp.data['deleted_count'] == 1

    def test_unsubscribe_requires_auth(self, api_client):
        resp = api_client.post('/api/notifications/unsubscribe/', {
            'endpoint': 'https://fcm.example.com/push/unsub',
        }, format='json')
        assert resp.status_code in [401, 403]


@pytest.mark.django_db
class TestPreferencesAPI:
    def test_get_preferences(self, user_client):
        resp = user_client.get('/api/notifications/preferences/')
        assert resp.status_code == 200
        assert 'email_notifications' in resp.data
        assert 'push_notifications' in resp.data

    def test_patch_preferences(self, user_client, user):
        resp = user_client.patch('/api/notifications/preferences/', {
            'email_notifications': False,
            'push_notifications': False,
        }, format='json')
        assert resp.status_code == 200
        user.refresh_from_db()
        assert user.email_notifications is False
        assert user.push_notifications is False

    def test_doctor_patch_preferences(self, doctor_client, doctor):
        resp = doctor_client.patch('/api/notifications/preferences/', {
            'email_notifications': False,
        }, format='json')
        assert resp.status_code == 200
        doctor.refresh_from_db()
        assert doctor.email_notifications is False


@pytest.mark.django_db
class TestUserNotificationCRUD:
    def test_list_notifications(self, user_client, user):
        UserNotification.objects.create(user=user, title='N1', notification_type='general')
        resp = user_client.get('/api/notifications/user/')
        assert resp.status_code == 200
        assert resp.data['unread_count'] == 1

    def test_mark_read(self, user_client, user):
        n = UserNotification.objects.create(user=user, title='Unread', notification_type='general')
        resp = user_client.post('/api/notifications/user/mark-read/', {
            'notification_ids': [n.notification_id],
        }, format='json')
        assert resp.status_code == 200
        n.refresh_from_db()
        assert n.is_read is True
