from django.db import models


# ============================================================
# INITIAL SURVEY QUESTIONS
# ============================================================

class InitialSurveyQuestion(models.Model):
    TYPE_CHOICES = [
        ('multiple_choice', 'Multiple Choice'),
        ('scale',           'Scale'),
        ('text',            'Text'),
        ('yes_no',          'Yes / No'),
    ]

    question_id   = models.AutoField(primary_key=True)
    question_text = models.TextField()
    question_type = models.CharField(max_length=30, choices=TYPE_CHOICES)
    category      = models.CharField(max_length=50, blank=True, null=True)
    options       = models.JSONField(blank=True, null=True)   # الخيارات لـ multiple_choice و yes_no
    display_order = models.IntegerField()
    is_active     = models.BooleanField(default=True)

    class Meta:
        db_table  = 'initial_survey_questions'
        ordering  = ['display_order']

    def __str__(self):
        return f"Q{self.display_order}: {self.question_text[:60]}"


# ============================================================
# INITIAL SURVEY RESPONSES
# ============================================================

class InitialSurveyResponse(models.Model):
    response_id  = models.AutoField(primary_key=True)
    user         = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='survey_responses')
    question     = models.ForeignKey(InitialSurveyQuestion, on_delete=models.CASCADE, related_name='responses')
    answer_text  = models.TextField(blank=True, null=True)
    answer_value = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    answered_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table    = 'initial_survey_responses'
        unique_together = [('user', 'question')]

    def __str__(self):
        return f"Response(user={self.user_id}, question={self.question_id})"
