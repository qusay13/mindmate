import uuid
from django.db import models
from django.conf import settings

class Conversation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    patient = models.ForeignKey(
        'accounts.User',
        on_delete=models.CASCADE,
        related_name='patient_conversations'
    )

    doctor = models.ForeignKey(
        'accounts.Doctor',
        on_delete=models.CASCADE,
        related_name='doctor_conversations'
    )

    is_archived_by_patient = models.BooleanField(default=False)
    is_archived_by_doctor = models.BooleanField(default=False)
    is_deleted_by_patient = models.BooleanField(default=False)
    is_deleted_by_doctor = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.patient} - {self.doctor}"

class Message(models.Model):

    class MessageType(models.TextChoices):
        TEXT = 'TEXT', 'Text'
        IMAGE = 'IMAGE', 'Image'
        FILE = 'FILE', 'File'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages'
    )

    sender_type = models.CharField(max_length=10, choices=[('user', 'User'), ('doctor', 'Doctor')])
    sender_id = models.UUIDField()

    content = models.TextField(blank=True)

    message_type = models.CharField(
        max_length=10,
        choices=MessageType.choices,
        default=MessageType.TEXT
    )

    is_seen = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', '-created_at']),
        ]

    def __str__(self):
        return f"Message {self.id} in {self.conversation}"
