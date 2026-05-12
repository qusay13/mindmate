from rest_framework import serializers
from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Message
        fields = '__all__'


class ConversationSerializer(serializers.ModelSerializer):
    last_message = serializers.SerializerMethodField()
    other_party  = serializers.SerializerMethodField()

    class Meta:
        model  = Conversation
        fields = ['id', 'created_at', 'last_message', 'other_party']

    def get_last_message(self, obj):
        last_msg = obj.messages.order_by('-created_at').first()
        if last_msg:
            return {
                'id':          str(last_msg.id),
                'content':     last_msg.content,
                'sender_type': last_msg.sender_type,
                'created_at':  last_msg.created_at,
            }
        return None

    def get_other_party(self, obj):
        """
        Returns the name/id of the person the logged-in user is talking to.
        Handles None gracefully in case the related user/doctor was soft-deleted.
        """
        request = self.context.get('request')
        user    = request.user if request else None

        if user and hasattr(user, 'user_id'):
            # Logged-in as patient → other party is the doctor
            doctor = obj.doctor
            if not doctor:
                return {'id': None, 'name': 'Unknown Doctor', 'role': 'doctor'}
            return {
                'id':   str(doctor.doctor_id),
                'name': doctor.full_name or 'Doctor',
                'role': 'doctor',
            }
        else:
            # Logged-in as doctor → other party is the patient
            patient = obj.patient
            if not patient:
                return {'id': None, 'name': 'Unknown Patient', 'role': 'patient'}
            return {
                'id':   str(patient.user_id),
                'name': patient.full_name or 'Patient',
                'role': 'patient',
            }
