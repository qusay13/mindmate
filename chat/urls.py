from django.urls import path
from .views import (
    ConversationListView, MessageListView,
    ConversationArchiveView, ConversationDeleteView,
    ConversationMarkReadView, ChatFileUploadView
)

urlpatterns = [
    path('conversations/', ConversationListView.as_view(), name='conversation-list'),
    path('conversations/<uuid:conversation_id>/messages/', MessageListView.as_view(), name='message-list'),
    path('conversations/<uuid:conversation_id>/archive/', ConversationArchiveView.as_view(), name='conversation-archive'),
    path('conversations/<uuid:conversation_id>/mark-read/', ConversationMarkReadView.as_view(), name='conversation-mark-read'),
    path('conversations/<uuid:conversation_id>/', ConversationDeleteView.as_view(), name='conversation-delete'),
    path('upload/', ChatFileUploadView.as_view(), name='chat-file-upload'),
]
