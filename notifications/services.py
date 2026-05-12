"""
notifications/services.py
=========================
Centralised helper for creating in-app notifications.
Import and call these functions from any app that needs to push a notification.

Usage example:
    from notifications.services import notify_user, notify_doctor

    notify_user(
        user      = patient,
        title     = "طلبك قُبل!",
        body      = f"وافق الدكتور {doctor.full_name} على طلبك.",
        notif_type= "doctor_request_accepted",
        related_entity_type = "request",
        related_entity_id   = request_obj.request_id,
    )
"""

from .models import UserNotification, DoctorNotification, AdminNotification


def notify_user(user, title, body=None, notif_type='general',
                related_entity_type=None, related_entity_id=None):
    """Creates a UserNotification record."""
    return UserNotification.objects.create(
        user                = user,
        title               = title,
        body                = body or '',
        notification_type   = notif_type,
        related_entity_type = related_entity_type,
        related_entity_id   = related_entity_id,
    )


def notify_doctor(doctor, title, body=None, notif_type='general',
                  related_entity_type=None, related_entity_id=None):
    """Creates a DoctorNotification record."""
    return DoctorNotification.objects.create(
        doctor              = doctor,
        title               = title,
        body                = body or '',
        notification_type   = notif_type,
        related_entity_type = related_entity_type,
        related_entity_id   = related_entity_id,
    )


def notify_admin(admin, title, body=None, notif_type='general',
                 related_entity_type=None, related_entity_id=None):
    """Creates an AdminNotification record."""
    return AdminNotification.objects.create(
        admin               = admin,
        title               = title,
        body                = body or '',
        notification_type   = notif_type,
        related_entity_type = related_entity_type,
        related_entity_id   = related_entity_id,
    )
