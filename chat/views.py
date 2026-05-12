from rest_framework import generics, permissions
from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer
from accounts.authentication import CustomTokenAuthentication


class ConversationListView(generics.ListAPIView):
    serializer_class       = ConversationSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, 'user_id'):
            # Patient: conversations where this user is the patient and doctor exists
            return (
                Conversation.objects
                .filter(patient=user, doctor__isnull=False)
                .select_related('patient', 'doctor')
                .prefetch_related('messages')
                .order_by('-created_at')
            )
        elif hasattr(user, 'doctor_id'):
            # Doctor: conversations where this doctor is assigned and patient exists
            return (
                Conversation.objects
                .filter(doctor=user, patient__isnull=False)
                .select_related('patient', 'doctor')
                .prefetch_related('messages')
                .order_by('-created_at')
            )
        return Conversation.objects.none()


class MessageListView(generics.ListAPIView):
    serializer_class       = MessageSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [permissions.IsAuthenticated]

    def get_queryset(self):
        conversation_id = self.kwargs['conversation_id']
        user = self.request.user

        try:
            conv = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Message.objects.none()

        # Access control
        if hasattr(user, 'user_id') and (conv.patient is None or conv.patient != user):
            return Message.objects.none()
        if hasattr(user, 'doctor_id') and (conv.doctor is None or conv.doctor != user):
            return Message.objects.none()

        return Message.objects.filter(conversation=conv).order_by('created_at')
