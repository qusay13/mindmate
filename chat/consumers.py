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

        # Extract token from query string
        query_string = self.scope['query_string'].decode()
        token = None
        for param in query_string.split('&'):
            if param.startswith('token='):
                token = param.split('=', 1)[1]
                break

        if not token:
            await self.close(code=4001)
            return

        # Authenticate
        user = await self.get_user_from_token(token)
        if not user:
            await self.close(code=4002)
            return

        self.user = user

        # Verify the user belongs to this conversation
        has_access = await self.verify_conversation_access(self.conversation_id, user)
        if not has_access:
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            msg_type = data.get('type', 'message')
        except (json.JSONDecodeError, AttributeError):
            return

        if msg_type == 'message':
            content = data.get('message', '').strip()
            if not content:
                return

            msg = await self.save_message(content)

            sender_id   = str(self.user.user_id) if hasattr(self.user, 'user_id') else str(self.user.doctor_id)
            sender_type = 'user' if hasattr(self.user, 'user_id') else 'doctor'

            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type':        'chat_message',
                    'id':          str(msg.id),
                    'message':     content,
                    'sender_type': sender_type,
                    'sender_id':   sender_id,
                    'created_at':  msg.created_at.isoformat(),
                }
            )
        
        elif msg_type == 'typing':
            is_typing = data.get('is_typing', False)
            sender_id = str(self.user.user_id) if hasattr(self.user, 'user_id') else str(self.user.doctor_id)
            
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_typing',
                    'sender_id': sender_id,
                    'is_typing': is_typing,
                }
            )
        
        elif msg_type == 'read_receipt':
            message_id = data.get('message_id')
            if message_id:
                await self.mark_message_as_seen(message_id)
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'chat_read_receipt',
                        'message_id': message_id,
                    }
                )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'message',
            'id':          event['id'],
            'message':     event['message'],
            'sender_type': event['sender_type'],
            'sender_id':   event['sender_id'],
            'created_at':  event['created_at'],
        }))

    async def chat_typing(self, event):
        # Don't send typing indicator back to the sender
        sender_id = str(self.user.user_id) if hasattr(self.user, 'user_id') else str(self.user.doctor_id)
        if event['sender_id'] != sender_id:
            await self.send(text_data=json.dumps({
                'type': 'typing',
                'sender_id': event['sender_id'],
                'is_typing': event['is_typing'],
            }))

    async def chat_read_receipt(self, event):
        await self.send(text_data=json.dumps({
            'type': 'read_receipt',
            'message_id': event['message_id'],
        }))

    # ── Database helpers ────────────────────────────────────

    @database_sync_to_async
    def get_user_from_token(self, token):
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        try:
            session = (
                UserSession.objects
                .select_related('user', 'doctor')
                .get(token_hash=token_hash)
            )
            if session.expires_at < timezone.now():
                session.delete()
                return None
            return session.user or session.doctor
        except UserSession.DoesNotExist:
            return None

    @database_sync_to_async
    def verify_conversation_access(self, conversation_id, user):
        try:
            conv = Conversation.objects.get(id=conversation_id)
            if hasattr(user, 'user_id') and conv.patient and conv.patient.user_id == user.user_id:
                return True
            if hasattr(user, 'doctor_id') and conv.doctor and conv.doctor.doctor_id == user.doctor_id:
                return True
            return False
        except Conversation.DoesNotExist:
            return False

    @database_sync_to_async
    def save_message(self, content):
        sender_type = 'user'   if hasattr(self.user, 'user_id')   else 'doctor'
        sender_id   = self.user.user_id if hasattr(self.user, 'user_id') else self.user.doctor_id

        msg = Message.objects.create(
            conversation_id=self.conversation_id,
            sender_type=sender_type,
            sender_id=sender_id,
            content=content,
        )

        try:
            from notifications.services import notify_user, notify_doctor
            conv = Conversation.objects.select_related('patient', 'doctor').get(id=self.conversation_id)
            if sender_type == 'user':
                notify_doctor(
                    doctor=conv.doctor,
                    title=f"رسالة جديدة من {conv.patient.full_name}",
                    body=content[:50] + ("..." if len(content) > 50 else ""),
                    notif_type='new_message',
                    related_entity_type='message'
                )
            else:
                notify_user(
                    user=conv.patient,
                    title=f"رسالة جديدة من د. {conv.doctor.full_name}",
                    body=content[:50] + ("..." if len(content) > 50 else ""),
                    notif_type='new_message',
                    related_entity_type='message'
                )
        except Exception as e:
            print(f"Error sending notification: {e}")

        return msg

    @database_sync_to_async
    def mark_message_as_seen(self, message_id):
        try:
            Message.objects.filter(id=message_id).update(is_seen=True)
        except Exception as e:
            print(f"Error marking message as seen: {e}")
