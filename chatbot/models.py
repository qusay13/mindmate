from django.db import models


# ============================================================
# CHATBOT CONVERSATIONS
# ============================================================

class ChatbotConversation(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('closed', 'Closed'),
    ]

    conversation_id = models.AutoField(primary_key=True)
    user            = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='chatbot_conversations')
    status          = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    started_at      = models.DateTimeField(auto_now_add=True)
    ended_at        = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'chatbot_conversations'
        indexes  = [models.Index(fields=['user'])]

    def __str__(self):
        return f"Conversation(user={self.user_id}, status={self.status})"


# ============================================================
# CHATBOT MESSAGES
# ============================================================

class ChatbotMessage(models.Model):
    SENDER_CHOICES = [
        ('user', 'User'),
        ('bot',  'Bot'),
    ]

    message_id      = models.AutoField(primary_key=True)
    conversation    = models.ForeignKey(ChatbotConversation, on_delete=models.CASCADE, related_name='messages')
    sender          = models.CharField(max_length=10, choices=SENDER_CHOICES)
    content         = models.TextField()
    sent_at         = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'chatbot_messages'
        ordering = ['sent_at']

    def __str__(self):
        return f"ChatMsg(conv={self.conversation_id}, sender={self.sender})"
