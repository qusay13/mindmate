import logging
from django.db import transaction
from django.utils import timezone
from rest_framework import status, views, permissions, generics
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from accounts.authentication import CustomTokenAuthentication
from .models import InitialSurveyQuestion, InitialSurveyResponse
from .serializers import InitialSurveyQuestionSerializer, SubmitSurveySerializer

logger = logging.getLogger(__name__)

class QuestionListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = InitialSurveyQuestionSerializer

    def get_queryset(self):
        return InitialSurveyQuestion.objects.filter(is_active=True).order_by('display_order')

class SubmitSurveyView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    def post(self, request):
        serializer = SubmitSurveySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        
        if not hasattr(user, 'initial_survey_completed'):
            return Response({'error': 'Only patients can submit the initial survey.'}, status=status.HTTP_403_FORBIDDEN)
            
        if user.initial_survey_completed:
            logger.warning(f"[WARNING] User {user.user_id} attempted to submit survey twice.")
            return Response({'error': 'Survey already completed'}, status=status.HTTP_400_BAD_REQUEST)
            
        responses_data = serializer.validated_data['responses']
        
        with transaction.atomic():
            for response in responses_data:
                # TODO: (Async processing) Send responses to an AI worker (e.g., Celery) to compute scores.
                InitialSurveyResponse.objects.create(
                    user=user,
                    question=response['question'],
                    answer_text=response.get('answer_text'),
                    answer_value=response.get('answer_value')
                )
            
            user.initial_survey_completed = True
            user.is_onboarded = True
            user.data_collection_start_date = timezone.now().date()
            user.save(update_fields=['initial_survey_completed', 'is_onboarded', 'data_collection_start_date'])
        
        # Logging success
        logger.info(f"[SUCCESS] User {user.user_id} submitted initial survey with {len(responses_data)} responses at {timezone.now()}.")
            
        return Response({'message': 'Survey submitted successfully'}, status=status.HTTP_201_CREATED)

