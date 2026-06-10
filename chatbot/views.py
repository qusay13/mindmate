from rest_framework import views, status, response, permissions
from .models import ChatbotConversation, ChatbotMessage
from .serializers import ChatbotConversationSerializer, ChatbotMessageSerializer
from .services.ai_service import AIService
from accounts.authentication import CustomTokenAuthentication

# Initialize AI Service
ai_service = AIService()

class ChatbotConversationView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        conv = ChatbotConversation.objects.filter(
            user=request.user, 
            status='active'
        ).order_by('-started_at').first()

        if not conv:
            conv = ChatbotConversation.objects.create(
                user=request.user, 
                status='active'
            )
        serializer = ChatbotConversationSerializer(conv)
        return response.Response(serializer.data)

class ChatbotMessageView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        content = request.data.get('message')
        if not content:
            return response.Response({'error': 'Message content is required'}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Get current active conversation
        conv = ChatbotConversation.objects.filter(user=request.user, status='active').first()
        if not conv:
            conv = ChatbotConversation.objects.create(user=request.user)

        # 2. Get history (last 10 messages for context)
        history = ChatbotMessage.objects.filter(conversation=conv).order_by('-sent_at')[:10]
        history = list(reversed(history))

        # 3. Save User Message
        user_msg = ChatbotMessage.objects.create(
            conversation=conv,
            sender='user',
            content=content
        )

        # 4. Generate AI Response
        bot_response_content = ai_service.get_response(history, content)
        
        bot_msg = ChatbotMessage.objects.create(
            conversation=conv,
            sender='bot',
            content=bot_response_content
        )

        return response.Response({
            'user_message': ChatbotMessageSerializer(user_msg).data,
            'bot_message': ChatbotMessageSerializer(bot_msg).data
        }, status=status.HTTP_201_CREATED)
