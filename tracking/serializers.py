from rest_framework import serializers
from .models import (
    DailyMoodEntry, 
    JournalEntry, 
    QuestionnaireSession, 
    DailyProgress,
    QuestionnaireType
)

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

class DailyProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyProgress
        fields = [
            'progress_id', 'progress_date', 
            'mood_completed', 'phq9_completed', 'gad7_completed', 
            'pss10_completed', 'questionnaire_completed', 
            'journal_completed', 'all_completed', 'tip_shown'
        ]

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
