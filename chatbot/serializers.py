from rest_framework import serializers
from .models import ChatbotConversation, ChatbotMessage

class ChatbotMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatbotMessage
        fields = ['message_id', 'sender', 'content', 'sent_at']

class ChatbotConversationSerializer(serializers.ModelSerializer):
    messages = ChatbotMessageSerializer(many=True, read_only=True)
    
    class Meta:
        model = ChatbotConversation
        fields = ['conversation_id', 'status', 'started_at', 'messages']
