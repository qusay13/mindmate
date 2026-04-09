from django.contrib import admin
from .models import (
    DailyMoodEntry,
    QuestionnaireType,
    QuestionnaireQuestion,
    QuestionnaireSession,
    QuestionnaireAnswer,
    JournalEntry,
    JournalAnalysis,
    JournalSharingPermission,
    DailyProgress,
)

@admin.register(DailyMoodEntry)
class DailyMoodEntryAdmin(admin.ModelAdmin):
    list_display = ['user', 'mood_level', 'recorded_date', 'created_at']
    list_filter = ['recorded_date', 'mood_level']
    search_fields = ['user__email']

@admin.register(QuestionnaireType)
class QuestionnaireTypeAdmin(admin.ModelAdmin):
    list_display = ['code', 'name', 'max_score', 'is_active']
    list_filter = ['is_active']

@admin.register(QuestionnaireQuestion)
class QuestionnaireQuestionAdmin(admin.ModelAdmin):
    list_display = ['questionnaire_type', 'question_order', 'question_text', 'is_active']
    list_filter = ['questionnaire_type', 'is_active']

@admin.register(QuestionnaireSession)
class QuestionnaireSessionAdmin(admin.ModelAdmin):
    list_display = ['user', 'questionnaire_type', 'total_score', 'severity_level', 'completed']
    list_filter = ['questionnaire_type', 'completed', 'session_date']
    search_fields = ['user__email']

@admin.register(QuestionnaireAnswer)
class QuestionnaireAnswerAdmin(admin.ModelAdmin):
    list_display = ['session', 'question', 'selected_option', 'score']
    list_filter = ['session__questionnaire_type']

@admin.register(JournalEntry)
class JournalEntryAdmin(admin.ModelAdmin):
    list_display = ['user', 'entry_date', 'created_at']
    list_filter = ['entry_date']
    search_fields = ['user__email', 'content']

@admin.register(JournalAnalysis)
class JournalAnalysisAdmin(admin.ModelAdmin):
    list_display = ['journal', 'dominant_pattern', 'analyzed_at']
    list_filter = ['analyzed_at']

@admin.register(JournalSharingPermission)
class JournalSharingPermissionAdmin(admin.ModelAdmin):
    list_display = ['user', 'doctor', 'share_full_journal', 'share_analysis_only']
    list_filter = ['share_full_journal', 'share_analysis_only']

@admin.register(DailyProgress)
class DailyProgressAdmin(admin.ModelAdmin):
    list_display = ['user', 'progress_date', 'all_completed', 'mood_completed', 'questionnaire_completed', 'journal_completed']
    list_filter = ['progress_date', 'all_completed']
    search_fields = ['user__email']
