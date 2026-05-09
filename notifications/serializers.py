from rest_framework import serializers
from .models import UserNotification, DoctorNotification, AdminNotification

class UserNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserNotification
        fields = [
            'notification_id', 'title', 'body', 'notification_type', 
            'related_entity_type', 'related_entity_id', 
            'is_read', 'created_at', 'read_at'
        ]
        read_only_fields = ['notification_id', 'created_at', 'read_at']

class DoctorNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorNotification
        fields = [
            'notification_id', 'title', 'body', 'notification_type', 
            'related_entity_type', 'related_entity_id', 
            'is_read', 'created_at', 'read_at'
        ]
        read_only_fields = ['notification_id', 'created_at', 'read_at']

class AdminNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdminNotification
        fields = [
            'notification_id', 'title', 'body', 'notification_type', 
            'related_entity_type', 'related_entity_id', 
            'is_read', 'created_at', 'read_at'
        ]
        read_only_fields = ['notification_id', 'created_at', 'read_at']
