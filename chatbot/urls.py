from django.urls import path
from .views import ChatbotConversationView, ChatbotMessageView

urlpatterns = [
    path('conversation/', ChatbotConversationView.as_view(), name='chatbot-conversation'),
    path('message/', ChatbotMessageView.as_view(), name='chatbot-send-message'),
]
