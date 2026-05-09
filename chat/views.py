from rest_framework import generics, permissions
from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer
from accounts.authentication import CustomTokenAuthentication
from django.db.models import Q

class ConversationListView(generics.ListAPIView):
    serializer_class = ConversationSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, 'user_id'):
            return Conversation.objects.filter(patient=user)
        elif hasattr(user, 'doctor_id'):
            return Conversation.objects.filter(doctor=user)
        return Conversation.objects.none()

class MessageListView(generics.ListAPIView):
    serializer_class = MessageSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        conversation_id = self.kwargs['conversation_id']
        user = self.request.user
        
        try:
            conv = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Message.objects.none()

        # Check access
        if hasattr(user, 'user_id') and conv.patient != user:
            return Message.objects.none()
        if hasattr(user, 'doctor_id') and conv.doctor != user:
            return Message.objects.none()

        return Message.objects.filter(conversation=conv).order_by('created_at')
