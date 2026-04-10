from rest_framework import serializers
from .models import InitialSurveyQuestion, InitialSurveyResponse

class InitialSurveyQuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = InitialSurveyQuestion
        fields = ['question_id', 'question_text', 'question_type', 'category', 'options', 'display_order']

class InitialSurveyResponseSerializer(serializers.Serializer):
    question_id = serializers.IntegerField(required=True)
    answer_text = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    answer_value = serializers.FloatField(required=False, allow_null=True)
    score = serializers.FloatField(required=False, allow_null=True)  # AI future scoring

    def validate(self, data):
        try:
            question = InitialSurveyQuestion.objects.get(pk=data['question_id'])
        except InitialSurveyQuestion.DoesNotExist:
            raise serializers.ValidationError({"question_id": "Question does not exist."})

        if not question.is_active:
            raise serializers.ValidationError({"question_id": "This question is no longer active."})

        # Validation based on question type
        if question.question_type == 'scale' and data.get('answer_value') is None:
            raise serializers.ValidationError(f"answer_value is required for scale type questions (Q{question.question_id}).")
        
        if question.question_type in ['multiple_choice', 'text', 'yes_no'] and not data.get('answer_text'):
            raise serializers.ValidationError(f"answer_text is required for {question.question_type} type questions (Q{question.question_id}).")
        
        data['question'] = question
        return data

class SubmitSurveySerializer(serializers.Serializer):
    responses = InitialSurveyResponseSerializer(many=True, allow_empty=False)

    def validate_responses(self, responses):
        seen_questions = set()
        for response in responses:
            qid = response['question_id']
            if qid in seen_questions:
                raise serializers.ValidationError(f"Duplicate answer detected for question_id {qid}.")
            seen_questions.add(qid)
        return responses

