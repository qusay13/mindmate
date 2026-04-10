from rest_framework import serializers
from .models import (
    DailyMoodEntry, 
    JournalEntry, 
    QuestionnaireSession, 
    DailyProgress,
    QuestionnaireType,
    QuestionnaireQuestion
)

class QuestionnaireTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuestionnaireType
        fields = ['questionnaire_type_id', 'code', 'name', 'description', 'max_score', 'scoring_ranges']

class QuestionnaireQuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuestionnaireQuestion
        fields = ['question_id', 'questionnaire_type', 'question_text', 'question_order', 'options']

class DailyMoodSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyMoodEntry
        fields = ['mood_id', 'mood_level', 'mood_label', 'reason_note', 'recorded_date', 'created_at']
        read_only_fields = ['mood_id', 'mood_label', 'recorded_date', 'created_at']

    def validate_mood_level(self, value):
        if not (1 <= value <= 5):
            raise serializers.ValidationError("Mood level must be between 1 and 5.")
        return value

class JournalEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = JournalEntry
        fields = ['journal_id', 'content', 'entry_date', 'created_at', 'updated_at']
        read_only_fields = ['journal_id', 'entry_date', 'created_at', 'updated_at']

from datetime import timedelta

class DailyProgressSerializer(serializers.ModelSerializer):
    completion = serializers.SerializerMethodField()
    missing = serializers.SerializerMethodField()
    completed = serializers.SerializerMethodField()
    streak = serializers.SerializerMethodField()

    class Meta:
        model = DailyProgress
        fields = [
            'progress_id', 'progress_date', 
            'completion', 'missing', 'completed', 'streak',
            'mood_completed', 'phq9_completed', 'gad7_completed', 
            'pss10_completed', 'questionnaire_completed', 
            'journal_completed', 'all_completed', 'tip_shown'
        ]

    def get_completion(self, obj):
        total = 3
        done = sum([obj.mood_completed, obj.journal_completed, obj.questionnaire_completed])
        return int((done / total) * 100)

    def get_missing(self, obj):
        m = []
        if not obj.mood_completed: m.append('mood')
        if not obj.journal_completed: m.append('journal')
        if not obj.questionnaire_completed: m.append('questionnaire')
        return m

    def get_completed(self, obj):
        c = []
        if obj.mood_completed: c.append('mood')
        if obj.journal_completed: c.append('journal')
        if obj.questionnaire_completed: c.append('questionnaire')
        return c

    def get_streak(self, obj):
        count = 0
        completed_dates = set(DailyProgress.objects.filter(
            user=obj.user, all_completed=True
        ).values_list('progress_date', flat=True))
        
        if obj.progress_date in completed_dates or obj.all_completed:
            count += 1
            
        cur_date = obj.progress_date - timedelta(days=1)
        while cur_date in completed_dates:
            count += 1
            cur_date -= timedelta(days=1)
            
        return count

class QuestionnaireAnswerSerializer(serializers.Serializer):
    question_id = serializers.IntegerField(required=True)
    selected_option = serializers.IntegerField(required=True)
    score = serializers.IntegerField(required=True)

class SubmitQuestionnaireSerializer(serializers.Serializer):
    questionnaire_code = serializers.CharField(required=True)
    answers = QuestionnaireAnswerSerializer(many=True, allow_empty=False)

    def validate_questionnaire_code(self, value):
        try:
            q_type = QuestionnaireType.objects.get(code=value, is_active=True)
        except QuestionnaireType.DoesNotExist:
            raise serializers.ValidationError(f"Invalid or inactive questionnaire code: {value}")
        return q_type

    def validate_answers(self, answers):
        seen_questions = set()
        for ans in answers:
            qid = ans['question_id']
            if qid in seen_questions:
                raise serializers.ValidationError(f"Duplicate answer detected for question_id {qid}.")
            seen_questions.add(qid)
        return answers
