from django.db import models


# ============================================================
# USER NOTIFICATIONS
# ============================================================

class UserNotification(models.Model):
    notification_id     = models.AutoField(primary_key=True)
    user                = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='notifications')
    title               = models.CharField(max_length=255)
    body                = models.TextField(blank=True, null=True)
    notification_type   = models.CharField(max_length=50)
    related_entity_type = models.CharField(max_length=50, blank=True, null=True)
    related_entity_id   = models.IntegerField(blank=True, null=True)
    is_read             = models.BooleanField(default=False)
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
    doctor              = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='notifications')
    title               = models.CharField(max_length=255)
    body                = models.TextField(blank=True, null=True)
    notification_type   = models.CharField(max_length=50)
    related_entity_type = models.CharField(max_length=50, blank=True, null=True)
    related_entity_id   = models.IntegerField(blank=True, null=True)
    is_read             = models.BooleanField(default=False)
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
    admin               = models.ForeignKey('accounts.Admin', on_delete=models.CASCADE, related_name='notifications')
    title               = models.CharField(max_length=255)
    body                = models.TextField(blank=True, null=True)
    notification_type   = models.CharField(max_length=50)
    related_entity_type = models.CharField(max_length=50, blank=True, null=True)
    related_entity_id   = models.IntegerField(blank=True, null=True)
    is_read             = models.BooleanField(default=False)
    created_at          = models.DateTimeField(auto_now_add=True)
    read_at             = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'admin_notifications'
        indexes  = [models.Index(fields=['admin', 'is_read'])]

    def __str__(self):
        return f"AdminNotif(admin={self.admin_id}, type={self.notification_type}, read={self.is_read})"
