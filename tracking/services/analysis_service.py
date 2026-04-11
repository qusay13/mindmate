import os
import sys

# Ensure RaedRepo is accessible
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../../'))
if project_root not in sys.path:
    sys.path.append(project_root)
raed_path = os.path.join(project_root, 'external', 'RaedRepo')
if raed_path not in sys.path:
    sys.path.append(raed_path)

from datetime import timedelta
from django.utils import timezone
from collections import defaultdict
from external.RaedRepo.models import MoodEntry, QuestionnaireResponse
from external.RaedRepo.scoring import compute_daily_analysis, compute_fifteen_day_analysis, compute_thirty_day_analysis
from tracking.models import DailyMoodEntry, QuestionnaireSession, QuestionnaireAnswer
from dataclasses import asdict

class AnalysisService:
    @staticmethod
    def _fetch_user_data(user):
        """Fetches and maps Django models to RaedRepo dataclasses for the last 30 days"""
        today = timezone.localdate()
        thirty_days_ago = today - timedelta(days=30)
        
        # 1. Fetch Moods
        django_moods = DailyMoodEntry.objects.filter(
            user=user, recorded_date__gte=thirty_days_ago
        ).order_by('recorded_date')
        
        mood_entries = []
        for dm in django_moods:
            mood_entries.append(MoodEntry(
                entry_id=str(dm.mood_id),
                user_id=str(user.user_id),
                entry_date=dm.recorded_date.isoformat(),
                mood_value=dm.mood_level,
                mood_label=dm.mood_label,
                note=dm.reason_note,
                timestamp=dm.created_at.isoformat()
            ))

        # 2. Fetch Questionnaire Responses
        sessions = QuestionnaireSession.objects.filter(
            user=user, session_date__gte=thirty_days_ago, completed=True
        ).prefetch_related('answers', 'questionnaire_type')
        
        questionnaire_responses = []
        for session in sessions:
            q_code = session.questionnaire_type.code.replace('-', '')
            for answer in session.answers.all():
                questionnaire_responses.append(QuestionnaireResponse(
                    response_id=str(answer.answer_id),
                    user_id=str(user.user_id),
                    question_id=str(answer.question.question_id),
                    questionnaire_type=q_code,
                    question_index=answer.question.question_order,
                    answer_index=answer.selected_option,
                    answer_value=answer.score,
                    response_date=session.session_date.isoformat(),
                    timestamp=answer.answered_at.isoformat()
                ))

        return mood_entries, questionnaire_responses

    @classmethod
    def generate_analysis(cls, user):
        """Generates Daily, 15-day, and 30-day analysis dicts"""
        mood_entries, questionnaire_responses = cls._fetch_user_data(user)
        
        if not mood_entries and not questionnaire_responses:
            return {"detail": "No data available capable of being analyzed."}
            
        # Group by date
        dates = set(m.entry_date for m in mood_entries)
        dates.update(q.response_date for q in questionnaire_responses)
        sorted_dates = sorted(list(dates))
        
        moods_by_date = {d: [] for d in sorted_dates}
        for m in mood_entries:
            moods_by_date[m.entry_date].append(m)
            
        qs_by_date = {d: [] for d in sorted_dates}
        for q in questionnaire_responses:
            qs_by_date[q.response_date].append(q)

        # Generate Daily Analyses
        daily_analyses = []
        for d in sorted_dates:
            da = compute_daily_analysis(
                user_id=str(user.user_id),
                analysis_date=d,
                mood_entries=moods_by_date[d],
                questionnaire_responses=qs_by_date[d]
            )
            daily_analyses.append(da)

        # Generate 15 & 30 Days
        fifteen_day_analysis = None
        thirty_day_analysis = None
        
        if len(daily_analyses) >= 3:
            fifteen_day_analysis = compute_fifteen_day_analysis(str(user.user_id), daily_analyses)
            
        if len(daily_analyses) >= 15:
            thirty_day_analysis = compute_thirty_day_analysis(str(user.user_id), daily_analyses)

        return {
            "daily_analyses": [asdict(d) for d in daily_analyses] if daily_analyses else [],
            "fifteen_day_analysis": asdict(fifteen_day_analysis) if fifteen_day_analysis else None,
            "thirty_day_analysis": asdict(thirty_day_analysis) if thirty_day_analysis else None,
        }
