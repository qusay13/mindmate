import uuid
from django.db import models

# ============================================================
# CHOICES DEFINITIONS
# ============================================================

NOTIFICATION_TYPE_CHOICES = [
    ('chat',        'Chat Message'),
    ('appointment', 'Appointment/Meeting'),
    ('assessment',  'Assessment/Daily Task'),
    ('system',      'System Alert/Tip'),
    ('general',     'General Notification'),
]


# ============================================================
# USER NOTIFICATIONS
# ============================================================

class UserNotification(models.Model):
    notification_id     = models.AutoField(primary_key=True)
    notification_uuid   = models.UUIDField(default=uuid.uuid4, editable=False, db_index=True)
    user                = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='notifications')
    title               = models.CharField(max_length=255)
    body                = models.TextField(blank=True, null=True)
    notification_type   = models.CharField(max_length=50, choices=NOTIFICATION_TYPE_CHOICES, default='general')
    related_entity_type = models.CharField(max_length=50, blank=True, null=True)
    related_entity_id   = models.IntegerField(blank=True, null=True)
    is_read             = models.BooleanField(default=False)
    is_sensitive        = models.BooleanField(default=False)
    event_key           = models.CharField(max_length=255, blank=True, null=True, db_index=True)
    created_at          = models.DateTimeField(auto_now_add=True)
    read_at             = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'user_notifications'
        indexes  = [models.Index(fields=['user', 'is_read'])]

    def __str__(self):
        return f"UserNotif(user={self.user_id}, type={self.notification_type}, read={self.is_read})"


# ============================================================
# DOCTOR NOTIFICATIONS
# ============================================================

class DoctorNotification(models.Model):
    notification_id     = models.AutoField(primary_key=True)
    notification_uuid   = models.UUIDField(default=uuid.uuid4, editable=False, db_index=True)
    doctor              = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='notifications')
    title               = models.CharField(max_length=255)
    body                = models.TextField(blank=True, null=True)
    notification_type   = models.CharField(max_length=50, choices=NOTIFICATION_TYPE_CHOICES, default='general')
    related_entity_type = models.CharField(max_length=50, blank=True, null=True)
    related_entity_id   = models.IntegerField(blank=True, null=True)
    is_read             = models.BooleanField(default=False)
    is_sensitive        = models.BooleanField(default=False)
    event_key           = models.CharField(max_length=255, blank=True, null=True, db_index=True)
    created_at          = models.DateTimeField(auto_now_add=True)
    read_at             = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'doctor_notifications'
        indexes  = [models.Index(fields=['doctor', 'is_read'])]

    def __str__(self):
        return f"DoctorNotif(doctor={self.doctor_id}, type={self.notification_type}, read={self.is_read})"


# ============================================================
# ADMIN NOTIFICATIONS
# ============================================================

class AdminNotification(models.Model):
    notification_id     = models.AutoField(primary_key=True)
    notification_uuid   = models.UUIDField(default=uuid.uuid4, editable=False, db_index=True)
    admin               = models.ForeignKey('accounts.Admin', on_delete=models.CASCADE, related_name='notifications')
    title               = models.CharField(max_length=255)
    body                = models.TextField(blank=True, null=True)
    notification_type   = models.CharField(max_length=50, choices=NOTIFICATION_TYPE_CHOICES, default='general')
    related_entity_type = models.CharField(max_length=50, blank=True, null=True)
    related_entity_id   = models.IntegerField(blank=True, null=True)
    is_read             = models.BooleanField(default=False)
    is_sensitive        = models.BooleanField(default=False)
    event_key           = models.CharField(max_length=255, blank=True, null=True, db_index=True)
    created_at          = models.DateTimeField(auto_now_add=True)
    read_at             = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'admin_notifications'
        indexes  = [models.Index(fields=['admin', 'is_read'])]

    def __str__(self):
        return f"AdminNotif(admin={self.admin_id}, type={self.notification_type}, read={self.is_read})"


# ============================================================
# WEB PUSH SUBSCRIPTIONS
# ============================================================

class PushSubscription(models.Model):
    subscription_id = models.AutoField(primary_key=True)
    user            = models.ForeignKey('accounts.User', on_delete=models.CASCADE, null=True, blank=True, related_name='push_subscriptions')
    doctor          = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, null=True, blank=True, related_name='push_subscriptions')
    endpoint        = models.TextField()
    p256dh          = models.CharField(max_length=255)
    auth            = models.CharField(max_length=255)
    user_agent      = models.TextField(blank=True, null=True)
    last_seen_at    = models.DateTimeField(auto_now=True)
    created_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'push_subscriptions'
        constraints = [
            models.UniqueConstraint(
                fields=['endpoint'],
                name='unique_push_endpoint'
            )
        ]

    def __str__(self):
        owner = self.user or self.doctor
        return f"PushSub({owner} | {self.endpoint[:30]}...)"


# ============================================================
# DELIVERY OBSERVED AUDIT LOGS
# ============================================================

class NotificationDeliveryLog(models.Model):
    CHANNEL_CHOICES = [
        ('websocket', 'WebSocket'),
        ('email',     'Email'),
        ('push',      'Web Push'),
    ]
    STATUS_CHOICES = [
        ('success', 'Success'),
        ('failed',  'Failed'),
        ('pending', 'Pending'),
    ]
    ROLE_CHOICES = [
        ('user',   'User'),
        ('doctor', 'Doctor'),
        ('admin',  'Admin'),
    ]

    log_id             = models.AutoField(primary_key=True)
    notification_uuid  = models.UUIDField(db_index=True)
    notification_role  = models.CharField(max_length=20, choices=ROLE_CHOICES)
    channel            = models.CharField(max_length=20, choices=CHANNEL_CHOICES)
    status             = models.CharField(max_length=20, choices=STATUS_CHOICES)
    error_message      = models.TextField(blank=True, null=True)
    created_at         = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notification_delivery_logs'

    def __str__(self):
        return f"NotifLog(uuid={self.notification_uuid}, channel={self.channel}, status={self.status})"
