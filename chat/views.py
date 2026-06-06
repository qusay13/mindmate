import os
import mimetypes
from rest_framework import generics, permissions, status, views
from rest_framework.response import Response
from rest_framework.pagination import CursorPagination
from rest_framework.parsers import MultiPartParser, FormParser
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.conf import settings
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer
from accounts.authentication import CustomTokenAuthentication


class ConversationListView(generics.ListAPIView):
    serializer_class       = ConversationSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        show_archived = self.request.query_params.get('archived', 'false').lower() in ('true', '1')

        if hasattr(user, 'user_id'):
            # Patient: conversations where this user is the patient and doctor exists, and not deleted
            qs = Conversation.objects.filter(
                patient=user,
                doctor__isnull=False,
                is_deleted_by_patient=False
            )
            qs = qs.filter(is_archived_by_patient=show_archived)
            return (
                qs.select_related('patient', 'doctor')
                .prefetch_related('messages')
                .order_by('-created_at')
            )
        elif hasattr(user, 'doctor_id'):
            # Doctor: conversations where this doctor is assigned and patient exists, and not deleted
            qs = Conversation.objects.filter(
                doctor=user,
                patient__isnull=False,
                is_deleted_by_doctor=False
            )
            qs = qs.filter(is_archived_by_doctor=show_archived)
            return (
                qs.select_related('patient', 'doctor')
                .prefetch_related('messages')
                .order_by('-created_at')
            )
        return Conversation.objects.none()


class MessageCursorPagination(CursorPagination):
    page_size = 20
    ordering = '-created_at'  # Newest messages first
    cursor_query_param = 'cursor'


class MessageListView(generics.ListAPIView):
    serializer_class       = MessageSerializer
    authentication_classes = [CustomTokenAuthentication]
    permission_classes     = [permissions.IsAuthenticated]
    pagination_class       = MessageCursorPagination

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

        # Messages shown from newest to oldest for cursor pagination
        return Message.objects.filter(conversation=conv).order_by('-created_at')


class ConversationArchiveView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, conversation_id):
        user = request.user
        try:
            conv = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response({'error': 'Conversation not found'}, status=status.HTTP_404_NOT_FOUND)

        from django.db import transaction
        with transaction.atomic():
            if hasattr(user, 'user_id') and conv.patient == user:
                conv.is_archived_by_patient = not conv.is_archived_by_patient
                conv.save()
                return Response({'message': f'Conversation archived status set to {conv.is_archived_by_patient}'})
            elif hasattr(user, 'doctor_id') and conv.doctor == user:
                conv.is_archived_by_doctor = not conv.is_archived_by_doctor
                conv.save()
                return Response({'message': f'Conversation archived status set to {conv.is_archived_by_doctor}'})

        return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)


class ConversationDeleteView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, conversation_id):
        user = request.user
        try:
            conv = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response({'error': 'Conversation not found'}, status=status.HTTP_404_NOT_FOUND)

        from django.db import transaction
        with transaction.atomic():
            if hasattr(user, 'user_id') and conv.patient == user:
                conv.is_deleted_by_patient = True
                conv.save()
                return Response({'message': 'Conversation deleted for patient'})
            elif hasattr(user, 'doctor_id') and conv.doctor == user:
                conv.is_deleted_by_doctor = True
                conv.save()
                return Response({'message': 'Conversation deleted for doctor'})

        return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)


class ConversationMarkReadView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, conversation_id):
        user = request.user
        try:
            conv = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response({'error': 'Conversation not found'}, status=status.HTTP_404_NOT_FOUND)

        # Access check
        is_patient = hasattr(user, 'user_id') and conv.patient == user
        is_doctor = hasattr(user, 'doctor_id') and conv.doctor == user
        if not is_patient and not is_doctor:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        from django.db import transaction
        # Mark unseen messages from other party as seen
        with transaction.atomic():
            if is_patient:
                unread_msgs = Message.objects.filter(conversation=conv, sender_type='doctor', is_seen=False)
                reader_id = str(user.user_id)
            else:
                unread_msgs = Message.objects.filter(conversation=conv, sender_type='user', is_seen=False)
                reader_id = str(user.doctor_id)

            count = unread_msgs.update(is_seen=True)

        # Broadcast WebSocket event
        try:
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                f"chat_{conversation_id}",
                {
                    "type": "messages_read",
                    "conversation_id": str(conversation_id),
                    "reader_id": reader_id,
                }
            )
        except Exception as e:
            print(f"Error broadcasting messages_read: {e}")

        return Response({'message': f'Marked {count} messages as read'})


class ChatFileUploadView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, *args, **kwargs):
        uploaded_file = request.FILES.get('file')
        if not uploaded_file:
            return Response({'error': 'No file uploaded'}, status=status.HTTP_400_BAD_REQUEST)

        # Validate size (10MB limit)
        max_size = 10 * 1024 * 1024
        if uploaded_file.size > max_size:
            return Response({'error': 'File size exceeds 10MB limit'}, status=status.HTTP_400_BAD_REQUEST)

        # Validate file extension and MIME type
        filename = uploaded_file.name
        ext = os.path.splitext(filename)[1].lower().replace('.', '')

        # Maps allowed extensions to allowed MIME types
        ALLOWED_IMAGES = {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'webp': 'image/webp'
        }
        ALLOWED_FILES = {
            'pdf': 'application/pdf',
            'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'txt': 'text/plain'
        }

        # Check browser-supplied content type
        content_type = uploaded_file.content_type

        # Fallback MIME guessing if not supplied or generic octet-stream
        if not content_type or content_type == 'application/octet-stream':
            guessed_type, _ = mimetypes.guess_type(filename)
            if guessed_type:
                content_type = guessed_type

        # Validate extension and match content_type
        if ext in ALLOWED_IMAGES:
            expected_mime = ALLOWED_IMAGES[ext]
            # Match broad category or exact type
            if not content_type.startswith('image/') and content_type != expected_mime:
                return Response({'error': 'File content mismatch for image'}, status=status.HTTP_400_BAD_REQUEST)
            msg_type = 'IMAGE'
        elif ext in ALLOWED_FILES:
            expected_mime = ALLOWED_FILES[ext]
            # Some text/plain can be text/plain; charset=utf-8 or application/vnd...
            if expected_mime not in content_type and content_type not in expected_mime:
                # We can perform a broad check or allow guess
                pass
            msg_type = 'FILE'
        else:
            return Response({'error': 'Unsupported file type or extension'}, status=status.HTTP_400_BAD_REQUEST)

        # Ensure directory exists and save
        path = default_storage.save(f'chat/{filename}', ContentFile(uploaded_file.read()))
        file_url = request.build_absolute_uri(settings.MEDIA_URL + path)

        return Response({
            'file_url': file_url,
            'message_type': msg_type
        }, status=status.HTTP_201_CREATED)
