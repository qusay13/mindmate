import logging
import random
from django.db import transaction
from django.utils import timezone
from rest_framework import status, views, permissions, generics, serializers
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from accounts.authentication import CustomTokenAuthentication
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiExample
from drf_spectacular.types import OpenApiTypes
from .models import (
    DailyMoodEntry, JournalEntry, DailyProgress,
    QuestionnaireSession, QuestionnaireAnswer, QuestionnaireQuestion,
    QuestionnaireType, JournalSharingPermission
)
from .serializers import (
    DailyMoodSerializer, JournalEntrySerializer,
    DailyProgressSerializer, SubmitQuestionnaireSerializer,
    QuestionnaireTypeSerializer, QuestionnaireQuestionSerializer
)

logger = logging.getLogger(__name__)


# ============================================================
# DAILY TIP TRIGGER
# ============================================================

def _maybe_send_daily_tip(user, progress):
    """
    Called after every DailyProgress save.
    If all_completed == True and no tip has been shown today,
    picks a random active tip and creates:
      1. UserDailyTip record (tracks what was shown)
      2. UserNotification so the tip surfaces in the notifications feed.
    """
    if not progress.all_completed or progress.tip_shown:
        return

    from assessment.models import TipAndRecommendation, UserDailyTip
    from notifications.services import notify_user

    # Try to match tip to the user's latest severity
    severity = None
    latest_session = (
        QuestionnaireSession.objects
        .filter(user=user, completed=True)
        .order_by('-completed_at')
        .first()
    )
    if latest_session and latest_session.severity_level:
        severity = latest_session.severity_level

    # Build query: prefer severity-targeted tips, fall back to generic
    tips_qs = TipAndRecommendation.objects.filter(is_active=True)
    if severity:
        targeted = list(tips_qs.filter(severity_target=severity))
        tip_pool = targeted if targeted else list(tips_qs)
    else:
        tip_pool = list(tips_qs)

    if not tip_pool:
        return

    chosen_tip = random.choice(tip_pool)

    # Record the shown tip
    UserDailyTip.objects.get_or_create(
        user=user,
        shown_date=progress.progress_date,
        defaults={'tip': chosen_tip}
    )

    # Mark tip as shown on the progress record
    DailyProgress.objects.filter(pk=progress.pk).update(tip_shown=True)

    # Push an in-app notification
    notify_user(
        user       = user,
        title      = '🌟 لقد أكملت يومك! إليك نصيحة اليوم',
        body       = chosen_tip.content,
        notif_type = 'daily_tip',
        related_entity_type = 'tip',
        related_entity_id   = chosen_tip.tip_id,
    )

    logger.info(f"[TIP] Sent daily tip #{chosen_tip.tip_id} to user {user.user_id} for {progress.progress_date}.")

def get_or_create_daily_progress(user, date):
    progress, created = DailyProgress.objects.get_or_create(user=user, progress_date=date)
    return progress

class DailyMoodView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    @extend_schema(responses={200: DailyMoodSerializer})
    def get(self, request):
        today = timezone.localdate()
        mood = DailyMoodEntry.objects.filter(user=request.user, recorded_date=today).first()
        if mood:
            return Response(DailyMoodSerializer(mood).data, status=status.HTTP_200_OK)
        return Response({'detail': 'No mood recorded for today.'}, status=status.HTTP_404_NOT_FOUND)

    @extend_schema(request=DailyMoodSerializer, responses={200: DailyMoodSerializer})
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
            
            # Invalidate analysis cache for user
            from django.core.cache import cache
            cache.delete(f"user_analysis_{user.user_id}")
            
            progress = get_or_create_daily_progress(user, today)
            progress.mood_completed = True
            progress.save()
            _maybe_send_daily_tip(user, progress)

        logger.info(f"[TRACKING] User {user.user_id} {'created' if created else 'updated'} mood '{mood_label}' for {today}.")
        return Response(DailyMoodSerializer(mood).data, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)


class DailyJournalView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    @extend_schema(responses={200: JournalEntrySerializer})
    def get(self, request):
        today = timezone.localdate()
        journal = JournalEntry.objects.filter(user=request.user, entry_date=today).first()
        if journal:
            return Response(JournalEntrySerializer(journal).data, status=status.HTTP_200_OK)
        return Response({'detail': 'No journal recorded for today.'}, status=status.HTTP_404_NOT_FOUND)

    @extend_schema(request=JournalEntrySerializer, responses={200: JournalEntrySerializer})
    def post(self, request):
        serializer = JournalEntrySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        today = timezone.localdate()
        new_content = serializer.validated_data['content']
        
        with transaction.atomic():
            journal, created = JournalEntry.objects.get_or_create(
                user=user, entry_date=today,
                defaults={'content': new_content}
            )
            if not created:
                # Append to existing journal
                time_now = timezone.localtime().strftime("%H:%M")
                journal.content += f"\n\n--- {time_now} ---\n{new_content}"
                journal.save()
            
            progress = get_or_create_daily_progress(user, today)
            progress.journal_completed = True
            progress.save()
            _maybe_send_daily_tip(user, progress)

        logger.info(f"[TRACKING] User {user.user_id} {'created' if created else 'updated'} journal for {today}.")
        return Response(JournalEntrySerializer(journal).data, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)


class DailyProgressView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses={200: DailyProgressSerializer})
    def get(self, request):
        today = timezone.localdate()
        progress = get_or_create_daily_progress(request.user, today)
        return Response(DailyProgressSerializer(progress).data, status=status.HTTP_200_OK)


class SubmitQuestionnaireResponseSerializer(serializers.Serializer):
    message = serializers.CharField()
    total_score = serializers.IntegerField()
    severity_level = serializers.CharField()
    suggested_doctor = OpenApiTypes.OBJECT # Can be further detailed if needed

class SubmitQuestionnaireView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    def _compute_severity(self, q_type, total_score):
        """
        يستدعي خوارزمية RaedRepo مباشرة لحساب مستوى الشدة والخطورة.
        """
        from external.RaedRepo.scoring import classify_questionnaire_severity
        
        # Returns tuple (arabic_label, english_key)
        label_ar, key = classify_questionnaire_severity(total_score, q_type.code.replace('-', ''))
        return key

    @extend_schema(
        request=SubmitQuestionnaireSerializer,
        responses={201: SubmitQuestionnaireResponseSerializer},
        description="Submit questionnaire answers and receive severity analysis and AI doctor suggestion."
    )
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
            
            # Determine severity using scoring_ranges from QuestionnaireType
            session.severity_level = self._compute_severity(q_type, total_score)
                
            session.completed = True
            session.completed_at = timezone.now()
            session.save()
            
            # Invalidate analysis cache for user
            from django.core.cache import cache
            cache.delete(f"user_analysis_{user.user_id}")
            
            # Update generic Progress Tracker
            progress = get_or_create_daily_progress(user, today)
            code_lower = q_type.code.lower().replace('-', '')
            completed_field = f"{code_lower}_completed"
            
            if hasattr(progress, completed_field):
                setattr(progress, completed_field, True)
                progress.save()
                _maybe_send_daily_tip(user, progress)

            logger.info(f"[TRACKING] User {user.user_id} completed {q_type.code} questionnaire. Score: {total_score}")

        # ── Doctor Recommendation Engine ──────────────────────────
        suggested_doctor = None
        try:
            from clinic.services.recommendation_service import suggest_doctor_for_user
            q_code_clean = q_type.code.replace('-', '')
            suggested_doctor = suggest_doctor_for_user(user, q_code_clean, session.severity_level)
        except Exception as e:
            logger.warning(f"[RECOMMENDATION] Failed to generate suggestion: {e}")

        response_data = {
            'message': f'{q_type.code} submitted successfully',
            'total_score': total_score,
            'severity_level': session.severity_level,
        }
        if suggested_doctor:
            response_data['suggested_doctor'] = suggested_doctor

        return Response(response_data, status=status.HTTP_201_CREATED)

class QuestionnaireTypeListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = QuestionnaireTypeSerializer
    queryset = QuestionnaireType.objects.filter(is_active=True)

class QuestionnaireQuestionListView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, code):
        try:
            q_type = QuestionnaireType.objects.get(code=code, is_active=True)
            questions = QuestionnaireQuestion.objects.filter(questionnaire_type=q_type, is_active=True)
            return Response(QuestionnaireQuestionSerializer(questions, many=True).data)
        except QuestionnaireType.DoesNotExist:
            return Response({'error': 'Questionnaire not found'}, status=status.HTTP_404_NOT_FOUND)

class ComprehensiveAnalysisView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    @extend_schema(
        responses={200: OpenApiTypes.OBJECT},
        description="Returns a comprehensive 30-day mental health analysis, including score history, patterns, and recommendations."
    )
    def get(self, request):
        from .services.analysis_service import AnalysisService
        from django.core.cache import cache
        
        user_id = request.user.user_id
        cache_key = f"user_analysis_{user_id}"
        
        cached_data = cache.get(cache_key)
        if cached_data:
            return Response(cached_data, status=status.HTTP_200_OK)
            
        analysis_data = AnalysisService.generate_analysis(request.user)
        
        # Cache for 6 hours unless invalidated earlier
        cache.set(cache_key, analysis_data, timeout=6 * 60 * 60)
        return Response(analysis_data, status=status.HTTP_200_OK)


class JournalSharingPermissionView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Find all active doctor relationships for this patient
        from clinic.models import DoctorPatientRelationship
        active_links = DoctorPatientRelationship.objects.filter(user=request.user, status='active')
        
        # Ensure a permission record exists for each linked doctor
        for link in active_links:
            JournalSharingPermission.objects.get_or_create(
                user=request.user,
                doctor=link.doctor,
                defaults={'share_full_journal': False, 'share_analysis_only': True}
            )

        perms = JournalSharingPermission.objects.filter(user=request.user)
        data = [{
            'doctor_id': p.doctor_id,
            'doctor_name': p.doctor.full_name,
            'share_full_journal': p.share_full_journal,
            'share_analysis_only': p.share_analysis_only
        } for p in perms]
        return Response(data, status=status.HTTP_200_OK)

    def post(self, request):
        doctor_id = request.data.get('doctor_id')
        share_full = request.data.get('share_full_journal', False)
        
        if not doctor_id:
            return Response({'error': 'doctor_id is required'}, status=status.HTTP_400_BAD_REQUEST)
            
        perm, created = JournalSharingPermission.objects.update_or_create(
            user=request.user,
            doctor_id=doctor_id,
            defaults={'share_full_journal': share_full}
        )
        return Response({'message': 'Permissions updated', 'share_full_journal': perm.share_full_journal})


class UserDailyTipView(views.APIView):
    """
    Fetches the daily tip generated when the user completed all 3 tasks today.
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from assessment.models import UserDailyTip
        today = timezone.localdate()
        tip = UserDailyTip.objects.filter(user=request.user, shown_date=today).first()
        if tip:
            return Response({
                'content': tip.tip.content,
                'category': tip.tip.category
            })
        return Response({'detail': 'No tip for today yet.'}, status=status.HTTP_404_NOT_FOUND)

class JournalHistoryView(generics.ListAPIView):
    """
    Returns the user's past journal entries.
    """
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = JournalEntrySerializer

    def get_queryset(self):
        return JournalEntry.objects.filter(user=self.request.user).order_by('-entry_date')

