from django.db import models


# ============================================================
# DOCTOR CONDITION TAGS
# ============================================================

class DoctorConditionTag(models.Model):
    CONDITION_CHOICES = [
        ('depression', 'Depression'),
        ('anxiety',    'Anxiety'),
        ('stress',     'Stress'),
        ('trauma',     'Trauma'),
        ('ocd',        'OCD'),
        ('general',    'General'),
    ]

    tag_id    = models.AutoField(primary_key=True)
    doctor    = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='condition_tags')
    condition = models.CharField(max_length=50, choices=CONDITION_CHOICES)

    class Meta:
        db_table        = 'doctor_condition_tags'
        unique_together = [('doctor', 'condition')]
        indexes         = [
            models.Index(fields=['condition']),
            models.Index(fields=['doctor']),
        ]

    def __str__(self):
        return f"{self.doctor.full_name} — {self.condition}"


# ============================================================
# DOCTOR-PATIENT REQUESTS
# ============================================================

class DoctorPatientRequest(models.Model):
    REQUEST_TYPE_CHOICES = [
        ('system_suggested', 'System Suggested'),
        ('user_selected',    'User Selected'),
    ]
    STATUS_CHOICES = [
        ('pending',  'Pending'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
    ]

    request_id      = models.AutoField(primary_key=True)
    user            = models.ForeignKey('accounts.User',   on_delete=models.CASCADE, related_name='doctor_requests')
    doctor          = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='patient_requests')
    request_type    = models.CharField(max_length=30, choices=REQUEST_TYPE_CHOICES)
    status          = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    assessment      = models.ForeignKey('assessment.Assessment', on_delete=models.SET_NULL, null=True, blank=True, related_name='doctor_requests')
    user_message    = models.TextField(blank=True, null=True)
    doctor_response = models.TextField(blank=True, null=True)
    requested_at    = models.DateTimeField(auto_now_add=True)
    responded_at    = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'doctor_patient_requests'
        indexes  = [
            models.Index(fields=['doctor', 'status']),
            models.Index(fields=['user',   'status']),
        ]

    def __str__(self):
        return f"Request(user={self.user_id} → doctor={self.doctor_id}, {self.status})"


# ============================================================
# DOCTOR-PATIENT RELATIONSHIPS
# ============================================================

class DoctorPatientRelationship(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('ended',  'Ended'),
    ]

    relationship_id = models.AutoField(primary_key=True)
    doctor          = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='patient_relationships')
    user            = models.ForeignKey('accounts.User',   on_delete=models.CASCADE, related_name='doctor_relationships')
    request         = models.ForeignKey(DoctorPatientRequest, on_delete=models.SET_NULL, null=True, blank=True, related_name='relationship')
    status          = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    started_at      = models.DateTimeField(auto_now_add=True)
    ended_at        = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table        = 'doctor_patient_relationships'
        unique_together = [('doctor', 'user')]

    def __str__(self):
        return f"Relationship(doctor={self.doctor_id} ↔ user={self.user_id}, {self.status})"


# ============================================================
# MESSAGES — USER → DOCTOR
# ============================================================

class DoctorPatientMessageUser(models.Model):
    message_id      = models.AutoField(primary_key=True)
    relationship    = models.ForeignKey(DoctorPatientRelationship, on_delete=models.CASCADE, related_name='user_messages')
    sender          = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='sent_messages')
    content         = models.TextField()
    is_read         = models.BooleanField(default=False)
    sent_at         = models.DateTimeField(auto_now_add=True)
    read_at         = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'doctor_patient_messages_user'
        indexes  = [models.Index(fields=['relationship', 'sent_at'])]

    def __str__(self):
        return f"UserMsg(rel={self.relationship_id}, sender={self.sender_id})"


# ============================================================
# MESSAGES — DOCTOR → USER
# ============================================================

class DoctorPatientMessageDoctor(models.Model):
    message_id   = models.AutoField(primary_key=True)
    relationship = models.ForeignKey(DoctorPatientRelationship, on_delete=models.CASCADE, related_name='doctor_messages')
    sender       = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='sent_messages')
    content      = models.TextField()
    is_read      = models.BooleanField(default=False)
    sent_at      = models.DateTimeField(auto_now_add=True)
    read_at      = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'doctor_patient_messages_doctor'
        indexes  = [models.Index(fields=['relationship', 'sent_at'])]

    def __str__(self):
        return f"DoctorMsg(rel={self.relationship_id}, sender={self.sender_id})"


# ============================================================
# DOCTOR REGISTRATION LOG
# ============================================================

class DoctorRegistrationLog(models.Model):
    ACTION_CHOICES = [
        ('submitted', 'Submitted'),
        ('approved',  'Approved'),
        ('rejected',  'Rejected'),
    ]

    log_id    = models.AutoField(primary_key=True)
    doctor    = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, related_name='registration_logs')
    admin     = models.ForeignKey('accounts.Admin',  on_delete=models.SET_NULL,  null=True, blank=True, related_name='registration_logs')
    action    = models.CharField(max_length=20, choices=ACTION_CHOICES)
    notes     = models.TextField(blank=True, null=True)
    action_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'doctor_registration_log'
        indexes  = [models.Index(fields=['doctor'])]

    def __str__(self):
        return f"RegLog(doctor={self.doctor_id}, action={self.action})"
