from django.db import models
from django.utils import timezone


# ============================================================
# DAILY MOOD TRACKER
# ============================================================

class DailyMoodEntry(models.Model):
    MOOD_LABELS = [
        ('very_bad',  'Very Bad'),
        ('bad',       'Bad'),
        ('neutral',   'Neutral'),
        ('good',      'Good'),
        ('very_good', 'Very Good'),
    ]

    mood_id       = models.AutoField(primary_key=True)
    user          = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='mood_entries')
    mood_level    = models.IntegerField()   # 1–5, validated at serializer level
    mood_label    = models.CharField(max_length=50, choices=MOOD_LABELS, blank=True, null=True)
    reason_note   = models.TextField(blank=True, null=True)
    recorded_date = models.DateField(default=timezone.localdate)
    created_at    = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table        = 'daily_mood_entries'
        unique_together = [('user', 'recorded_date')]
        indexes         = [models.Index(fields=['user', 'recorded_date'])]

    def __str__(self):
        return f"Mood(user={self.user_id}, level={self.mood_level}, date={self.recorded_date})"


# ============================================================
# QUESTIONNAIRE TYPES (PHQ-9 / GAD-7 / PSS-10)
# ============================================================

class QuestionnaireType(models.Model):
    questionnaire_type_id = models.AutoField(primary_key=True)
    code                  = models.CharField(max_length=20, unique=True)
    name                  = models.CharField(max_length=100)
    description           = models.TextField(blank=True, null=True)
    max_score             = models.IntegerField()
    scoring_ranges        = models.JSONField(blank=True, null=True)
    is_active             = models.BooleanField(default=True)

    class Meta:
        db_table = 'questionnaire_types'

    def __str__(self):
        return f"{self.code} — {self.name}"


# ============================================================
# QUESTIONNAIRE QUESTIONS
# ============================================================

class QuestionnaireQuestion(models.Model):
    question_id           = models.AutoField(primary_key=True)
    questionnaire_type    = models.ForeignKey(QuestionnaireType, on_delete=models.CASCADE, related_name='questions')
    question_text         = models.TextField()
    question_order        = models.IntegerField()
    options               = models.JSONField()
    is_active             = models.BooleanField(default=True)

    class Meta:
        db_table = 'questionnaire_questions'
        ordering = ['question_order']

    def __str__(self):
        return f"{self.questionnaire_type.code} Q{self.question_order}: {self.question_text[:50]}"


# ============================================================
# QUESTIONNAIRE SESSIONS
# ============================================================

class QuestionnaireSession(models.Model):
    session_id            = models.AutoField(primary_key=True)
    user                  = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='questionnaire_sessions')
    questionnaire_type    = models.ForeignKey(QuestionnaireType, on_delete=models.CASCADE, related_name='sessions')
    total_score           = models.IntegerField(blank=True, null=True)
    severity_level        = models.CharField(max_length=30, blank=True, null=True)
    completed             = models.BooleanField(default=False)
    session_date          = models.DateField(default=timezone.localdate)
    started_at            = models.DateTimeField(auto_now_add=True)
    completed_at          = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table        = 'questionnaire_sessions'
        unique_together = [('user', 'questionnaire_type', 'session_date')]
        indexes         = [models.Index(fields=['user', 'session_date'])]

    def __str__(self):
        return f"QSession({self.questionnaire_type.code}, user={self.user_id}, date={self.session_date})"


# ============================================================
# QUESTIONNAIRE ANSWERS
# ============================================================

class QuestionnaireAnswer(models.Model):
    answer_id       = models.AutoField(primary_key=True)
    session         = models.ForeignKey(QuestionnaireSession,  on_delete=models.CASCADE, related_name='answers')
    question        = models.ForeignKey(QuestionnaireQuestion, on_delete=models.CASCADE, related_name='answers')
    selected_option = models.IntegerField()
    score           = models.IntegerField()
    answered_at     = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'questionnaire_answers'

    def __str__(self):
        return f"Answer(session={self.session_id}, question={self.question_id}, score={self.score})"


# ============================================================
# DAILY JOURNAL
# ============================================================

class JournalEntry(models.Model):
    journal_id = models.AutoField(primary_key=True)
    user       = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='journal_entries')
    content    = models.TextField()
    entry_date = models.DateField(default=timezone.localdate)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'journal_entries'
        indexes  = [models.Index(fields=['user', 'entry_date'])]

    def __str__(self):
        return f"Journal(user={self.user_id}, date={self.entry_date})"


# ============================================================
# JOURNAL ANALYSIS (DSM-5)
# ============================================================

class JournalAnalysis(models.Model):
    analysis_id      = models.AutoField(primary_key=True)
    journal          = models.OneToOneField(JournalEntry, on_delete=models.CASCADE, related_name='analysis')
    detected_symptoms = models.JSONField(blank=True, null=True)
    disorder_scores  = models.JSONField(blank=True, null=True)
    dominant_pattern = models.CharField(max_length=100, blank=True, null=True)
    raw_indicators   = models.JSONField(blank=True, null=True)
    analyzed_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'journal_analysis'

    def __str__(self):
        return f"Analysis(journal={self.journal_id}, pattern={self.dominant_pattern})"


# ============================================================
# JOURNAL SHARING PERMISSIONS
# ============================================================

class JournalSharingPermission(models.Model):
    permission_id       = models.AutoField(primary_key=True)
    user                = models.ForeignKey('accounts.User',   on_delete=models.CASCADE, related_name='journal_permissions')
    doctor              = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='journal_permissions')
    share_full_journal  = models.BooleanField(default=False)
    share_analysis_only = models.BooleanField(default=True)
    granted_at          = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table        = 'journal_sharing_permissions'
        unique_together = [('user', 'doctor')]

    def __str__(self):
        mode = 'full' if self.share_full_journal else 'analysis only'
        return f"JournalPerm(user={self.user_id} → doctor={self.doctor_id}, {mode})"


# ============================================================
# DAILY PROGRESS BAR (3 parts)
# ============================================================

class DailyProgress(models.Model):
    progress_id             = models.AutoField(primary_key=True)
    user                    = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='daily_progress')
    progress_date           = models.DateField(default=timezone.localdate)

    # Part 1 — Mood
    mood_completed          = models.BooleanField(default=False)

    # Part 2 — Questionnaires (per questionnaire)
    phq9_completed          = models.BooleanField(default=False)
    gad7_completed          = models.BooleanField(default=False)
    pss10_completed         = models.BooleanField(default=False)
    questionnaire_completed = models.BooleanField(default=False)  # auto-computed

    # Part 3 — Journal
    journal_completed       = models.BooleanField(default=False)

    # Overall
    all_completed           = models.BooleanField(default=False)  # auto-computed
    tip_shown               = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table        = 'daily_progress'
        unique_together = [('user', 'progress_date')]
        indexes         = [models.Index(fields=['user', 'progress_date'])]

    def save(self, *args, **kwargs):
        # Mirror the DB trigger logic in Django
        self.questionnaire_completed = self.phq9_completed and self.gad7_completed and self.pss10_completed
        self.all_completed           = self.mood_completed and self.questionnaire_completed and self.journal_completed
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Progress(user={self.user_id}, date={self.progress_date}, done={self.all_completed})"
