import logging
from django.db import transaction
from django.utils import timezone
from rest_framework import status, views, permissions, generics
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from accounts.authentication import CustomTokenAuthentication
from .models import (
    DailyMoodEntry, JournalEntry, DailyProgress, 
    QuestionnaireSession, QuestionnaireAnswer, QuestionnaireQuestion
)
from .serializers import (
    DailyMoodSerializer, JournalEntrySerializer, 
    DailyProgressSerializer, SubmitQuestionnaireSerializer
)

logger = logging.getLogger(__name__)

def get_or_create_daily_progress(user, date):
    progress, created = DailyProgress.objects.get_or_create(user=user, progress_date=date)
    return progress

class DailyMoodView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    def get(self, request):
        today = timezone.localdate()
        mood = DailyMoodEntry.objects.filter(user=request.user, recorded_date=today).first()
        if mood:
            return Response(DailyMoodSerializer(mood).data, status=status.HTTP_200_OK)
        return Response({'detail': 'No mood recorded for today.'}, status=status.HTTP_404_NOT_FOUND)

    def post(self, request):
        serializer = DailyMoodSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        today = timezone.localdate()
        mood_level = serializer.validated_data['mood_level']
        
        # Derive mood_label
        labels = {1: 'very_bad', 2: 'bad', 3: 'neutral', 4: 'good', 5: 'very_good'}
        mood_label = labels.get(mood_level, 'neutral')
        
        with transaction.atomic():
            mood, created = DailyMoodEntry.objects.update_or_create(
                user=user, recorded_date=today,
                defaults={
                    'mood_level': mood_level,
                    'mood_label': mood_label,
                    'reason_note': serializer.validated_data.get('reason_note', '')
                }
            )
            
            progress = get_or_create_daily_progress(user, today)
            progress.mood_completed = True
            progress.save()
            
        logger.info(f"[TRACKING] User {user.user_id} {'created' if created else 'updated'} mood '{mood_label}' for {today}.")
        return Response(DailyMoodSerializer(mood).data, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)


class DailyJournalView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    def get(self, request):
        today = timezone.localdate()
        journal = JournalEntry.objects.filter(user=request.user, entry_date=today).first()
        if journal:
            return Response(JournalEntrySerializer(journal).data, status=status.HTTP_200_OK)
        return Response({'detail': 'No journal recorded for today.'}, status=status.HTTP_404_NOT_FOUND)

    def post(self, request):
        serializer = JournalEntrySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        today = timezone.localdate()
        
        with transaction.atomic():
            journal, created = JournalEntry.objects.update_or_create(
                user=user, entry_date=today,
                defaults={'content': serializer.validated_data['content']}
            )
            
            progress = get_or_create_daily_progress(user, today)
            progress.journal_completed = True
            progress.save()
            
        logger.info(f"[TRACKING] User {user.user_id} {'created' if created else 'updated'} journal for {today}.")
        return Response(JournalEntrySerializer(journal).data, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)


class DailyProgressView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        today = timezone.localdate()
        progress = get_or_create_daily_progress(request.user, today)
        return Response(DailyProgressSerializer(progress).data, status=status.HTTP_200_OK)


class SubmitQuestionnaireView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    def post(self, request):
        serializer = SubmitQuestionnaireSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        today = timezone.localdate()
        q_type = serializer.validated_data['questionnaire_code']
        answers_data = serializer.validated_data['answers']
        
        existing_session = QuestionnaireSession.objects.filter(user=user, questionnaire_type=q_type, session_date=today, completed=True).exists()
        if existing_session:
            return Response({'error': f"You have already completed {q_type.code} today."}, status=status.HTTP_400_BAD_REQUEST)
        
        with transaction.atomic():
            session = QuestionnaireSession.objects.create(
                user=user,
                questionnaire_type=q_type,
                session_date=today,
                completed=False
            )
            
            total_score = 0
            for ans_data in answers_data:
                try:
                    q_obj = QuestionnaireQuestion.objects.get(pk=ans_data['question_id'], questionnaire_type=q_type)
                except QuestionnaireQuestion.DoesNotExist:
                    raise views.exceptions.ValidationError(f"Question {ans_data['question_id']} does not belong to {q_type.code}.")
                
                QuestionnaireAnswer.objects.create(
                    session=session,
                    question=q_obj,
                    selected_option=ans_data['selected_option'],
                    score=ans_data['score']
                )
                total_score += ans_data['score']
                
            session.total_score = total_score
            
            # Basic fallback if RaedRepo logic is added later
            if total_score > 15:
                session.severity_level = 'Severe'
            elif total_score > 10:
                session.severity_level = 'Moderate'
            else:
                session.severity_level = 'Mild'
                
            session.completed = True
            session.completed_at = timezone.now()
            session.save()
            
            # Update generic Progress Tracker
            progress = get_or_create_daily_progress(user, today)
            code_lower = q_type.code.lower()
            completed_field = f"{code_lower}_completed"
            
            if hasattr(progress, completed_field):
                setattr(progress, completed_field, True)
                progress.save()
            
            logger.info(f"[TRACKING] User {user.user_id} completed {q_type.code} questionnaire. Score: {total_score}")
        
        return Response({
            'message': f'{q_type.code} submitted successfully', 
            'total_score': total_score,
            'severity_level': session.severity_level
        }, status=status.HTTP_201_CREATED)
