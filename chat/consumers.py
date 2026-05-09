import json
import hashlib
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone
from .models import Conversation, Message
from accounts.models import UserSession

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group_name = f'chat_{self.conversation_id}'

        # Get token from query string
        query_string = self.scope['query_string'].decode()
        token = None
        for param in query_string.split('&'):
            if param.startswith('token='):
                token = param.split('=')[1]
                break

        if not token:
            await self.close()
            return

        # Authenticate user
        user = await self.get_user_from_token(token)
        if not user:
            await self.close()
            return

        self.user = user

        # Verify ownership
        has_access = await self.verify_conversation_access(self.conversation_id, user)
        if not has_access:
            await self.close()
            return

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    async def receive(self, text_data):
        data = json.loads(text_data)
        content = data.get('message', '')

        if content:
            msg = await self.save_message(content)
            
            # Identify sender ID
            sender_id = str(self.user.user_id) if hasattr(self.user, 'user_id') else str(self.user.doctor_id)
            sender_type = 'user' if hasattr(self.user, 'user_id') else 'doctor'

            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_message',
                    'id': str(msg.id),
                    'message': content,
                    'sender_type': sender_type,
                    'sender_id': sender_id,
                    'created_at': msg.created_at.isoformat(),
                }
            )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'id': event['id'],
            'message': event['message'],
            'sender_type': event['sender_type'],
            'sender_id': event['sender_id'],
            'created_at': event['created_at'],
        }))

    @database_sync_to_async
    def get_user_from_token(self, token):
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        try:
            session = UserSession.objects.select_related('user', 'doctor').get(token_hash=token_hash)
            if session.expires_at < timezone.now():
                return None
            return session.user or session.doctor
        except UserSession.DoesNotExist:
            return None

    @database_sync_to_async
    def verify_conversation_access(self, conversation_id, user):
        try:
            conv = Conversation.objects.get(id=conversation_id)
            if hasattr(user, 'user_id') and conv.patient.user_id == user.user_id:
                return True
            if hasattr(user, 'doctor_id') and conv.doctor.doctor_id == user.doctor_id:
                return True
            return False
        except Conversation.DoesNotExist:
            return False

    @database_sync_to_async
    def save_message(self, content):
        sender_type = 'user' if hasattr(self.user, 'user_id') else 'doctor'
        sender_id = self.user.user_id if hasattr(self.user, 'user_id') else self.user.doctor_id
        
        return Message.objects.create(
            conversation_id=self.conversation_id,
            sender_type=sender_type,
            sender_id=sender_id,
            content=content
        )
