"""
notifications/services.py
=========================
Centralised dispatcher service for multi-channel notifications (Database, Email, Web Push).
Handles message idempotency, preference screening, and offloads delivery to Celery tasks.
"""

import uuid
import logging
from .models import UserNotification, DoctorNotification, AdminNotification
from .tasks import send_notification_email_task, send_web_push_task

logger = logging.getLogger(__name__)


def notify_user(user, title, body=None, notif_type='general',
                related_entity_type=None, related_entity_id=None,
                event_key=None, is_sensitive=False, url=None):
    """
    Saves a UserNotification record and triggers Celery dispatch pipelines (Email & Web Push)
    if preferences are enabled. Enforces idempotency via event_key.
    Handles broker connection errors gracefully.
    """
    # 1. Enforce strict idempotency (avoid duplicate dispatches on retry/race condition)
    if event_key and UserNotification.objects.filter(event_key=event_key).exists():
        return UserNotification.objects.get(event_key=event_key)

    # 2. Persist database notification
    notif = UserNotification.objects.create(
        user                = user,
        title               = title,
        body                = body or '',
        notification_type   = notif_type,
        related_entity_type = related_entity_type,
        related_entity_id   = related_entity_id,
        is_sensitive        = is_sensitive,
        event_key           = event_key,
    )

    # 3. Asynchronous SMTP Email Dispatch (screened by preferences)
    if getattr(user, 'email_notifications', True):
        try:
            send_notification_email_task.delay(
                notification_uuid_str = str(notif.notification_uuid),
                user_id_str           = str(user.user_id),
                role                  = 'user',
                title                 = title,
                body                  = body or ''
            )
        except Exception as ex:
            logger.error(f"Failed to queue email notification task for user {user.user_id}: {ex}")

    # 4. Asynchronous VAPID Web Push Dispatch (screened by preferences)
    if getattr(user, 'push_notifications', True):
        payload = {
            "notification_uuid":   str(notif.notification_uuid),
            "type":                notif_type,
            "title":               title,
            "body":                body or '',
            "url":                 url or '/dashboard',
            "is_sensitive":        is_sensitive,
            "related_entity_type": related_entity_type,
            "related_entity_id":   related_entity_id,
        }
        try:
            send_web_push_task.delay(
                notification_uuid_str = str(notif.notification_uuid),
                user_id_str           = str(user.user_id),
                role                  = 'user',
                payload               = payload
            )
        except Exception as ex:
            logger.error(f"Failed to queue push notification task for user {user.user_id}: {ex}")

    return notif


def notify_doctor(doctor, title, body=None, notif_type='general',
                  related_entity_type=None, related_entity_id=None,
                  event_key=None, is_sensitive=False, url=None):
    """
    Saves a DoctorNotification record and triggers Celery dispatch pipelines (Email & Web Push)
    if preferences are enabled. Enforces idempotency via event_key.
    Handles broker connection errors gracefully.
    """
    # 1. Enforce strict idempotency
    if event_key and DoctorNotification.objects.filter(event_key=event_key).exists():
        return DoctorNotification.objects.get(event_key=event_key)

    # 2. Persist database notification
    notif = DoctorNotification.objects.create(
        doctor              = doctor,
        title               = title,
        body                = body or '',
        notification_type   = notif_type,
        related_entity_type = related_entity_type,
        related_entity_id   = related_entity_id,
        is_sensitive        = is_sensitive,
        event_key           = event_key,
    )

    # 3. Asynchronous SMTP Email Dispatch
    if getattr(doctor, 'email_notifications', True):
        try:
            send_notification_email_task.delay(
                notification_uuid_str = str(notif.notification_uuid),
                user_id_str           = str(doctor.doctor_id),
                role                  = 'doctor',
                title                 = title,
                body                  = body or ''
            )
        except Exception as ex:
            logger.error(f"Failed to queue email notification task for doctor {doctor.doctor_id}: {ex}")

    # 4. Asynchronous VAPID Web Push Dispatch
    if getattr(doctor, 'push_notifications', True):
        payload = {
            "notification_uuid":   str(notif.notification_uuid),
            "type":                notif_type,
            "title":               title,
            "body":                body or '',
            "url":                 url or '/',
            "is_sensitive":        is_sensitive,
            "related_entity_type": related_entity_type,
            "related_entity_id":   related_entity_id,
        }
        try:
            send_web_push_task.delay(
                notification_uuid_str = str(notif.notification_uuid),
                user_id_str           = str(doctor.doctor_id),
                role                  = 'doctor',
                payload               = payload
            )
        except Exception as ex:
            logger.error(f"Failed to queue push notification task for doctor {doctor.doctor_id}: {ex}")

    return notif


def notify_admin(admin, title, body=None, notif_type='general',
                 related_entity_type=None, related_entity_id=None,
                 event_key=None, is_sensitive=False, url=None):
    """
    Saves an AdminNotification record. Enforces idempotency via event_key.
    Note: Admin notifications are database-only logs in the current architecture.
    """
    # 1. Enforce strict idempotency
    if event_key and AdminNotification.objects.filter(event_key=event_key).exists():
        return AdminNotification.objects.get(event_key=event_key)

    # 2. Persist database notification
    notif = AdminNotification.objects.create(
        admin               = admin,
        title               = title,
        body                = body or '',
        notification_type   = notif_type,
        related_entity_type = related_entity_type,
        related_entity_id   = related_entity_id,
        is_sensitive        = is_sensitive,
        event_key           = event_key,
    )

    return notif

