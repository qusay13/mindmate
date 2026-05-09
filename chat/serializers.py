from rest_framework import serializers
from .models import Conversation, Message

class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = '__all__'

class ConversationSerializer(serializers.ModelSerializer):
    last_message = serializers.SerializerMethodField()
    other_party = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ['id', 'created_at', 'last_message', 'other_party']

    def get_last_message(self, obj):
        last_msg = obj.messages.order_by('-created_at').first()
        if last_msg:
            return MessageSerializer(last_msg).data
        return None

    def get_other_party(self, obj):
        user = self.context['request'].user
        if hasattr(user, 'user_id'):
            return {
                'id': obj.doctor.doctor_id,
                'name': obj.doctor.full_name,
                'role': 'doctor'
            }
        else:
            return {
                'id': obj.patient.user_id,
                'name': obj.patient.full_name,
                'role': 'patient'
            }
