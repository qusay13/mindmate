from django.db import models
from django.utils import timezone


# ============================================================
# AI ASSESSMENT ENGINE
# ============================================================

class Assessment(models.Model):
    TYPE_CHOICES = [
        ('preliminary', 'Preliminary'),  # بعد 15 يوم
        ('final',       'Final'),        # بعد 30 يوم
    ]
    SEVERITY_CHOICES = [
        ('normal',   'Normal'),
        ('mild',     'Mild'),
        ('moderate', 'Moderate'),
        ('severe',   'Severe'),
        ('critical', 'Critical'),
    ]

    assessment_id         = models.AutoField(primary_key=True)
    user                  = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='assessments')
    assessment_type       = models.CharField(max_length=20, choices=TYPE_CHOICES)
    depression_score      = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    anxiety_score         = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    stress_score          = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    confidence_score      = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    overall_severity      = models.CharField(max_length=30, choices=SEVERITY_CHOICES, blank=True, null=True)
    is_critical           = models.BooleanField(default=False)
    mood_trend            = models.JSONField(blank=True, null=True)
    questionnaire_summary = models.JSONField(blank=True, null=True)
    journal_summary       = models.JSONField(blank=True, null=True)
    dominant_condition    = models.CharField(max_length=100, blank=True, null=True)
    recommendations       = models.JSONField(blank=True, null=True)
    data_days_count       = models.IntegerField(blank=True, null=True)
    created_from_days     = models.IntegerField(blank=True, null=True)  # 15 أو 30
    assessed_at           = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'assessments'
        indexes  = [models.Index(fields=['user', 'assessment_type'])]

    def __str__(self):
        return f"Assessment({self.assessment_type}, user={self.user_id}, severity={self.overall_severity})"


# ============================================================
# TIPS & RECOMMENDATIONS
# ============================================================

class TipAndRecommendation(models.Model):
    TYPE_CHOICES = [
        ('tip',            'Tip'),
        ('quote',          'Quote'),
        ('recommendation', 'Recommendation'),
        ('guidance',       'Guidance'),
    ]

    tip_id          = models.AutoField(primary_key=True)
    category        = models.CharField(max_length=50)
    content         = models.TextField()
    tip_type        = models.CharField(max_length=30, choices=TYPE_CHOICES)
    severity_target = models.CharField(max_length=30, blank=True, null=True)
    is_active       = models.BooleanField(default=True)
    created_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tips_and_recommendations'

    def __str__(self):
        return f"Tip({self.tip_type}, category={self.category}): {self.content[:60]}"


# ============================================================
# USER DAILY TIPS
# ============================================================

class UserDailyTip(models.Model):
    id         = models.AutoField(primary_key=True)
    user       = models.ForeignKey('accounts.User',     on_delete=models.CASCADE, related_name='daily_tips')
    tip        = models.ForeignKey(TipAndRecommendation, on_delete=models.CASCADE, related_name='shown_to')
    shown_date = models.DateField(default=timezone.localdate)
    shown_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table        = 'user_daily_tips'
        unique_together = [('user', 'shown_date')]

    def __str__(self):
        return f"DailyTip(user={self.user_id}, date={self.shown_date})"
