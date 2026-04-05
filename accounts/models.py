import uuid
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager
from django.core.exceptions import ValidationError


# ============================================================
# USER
# ============================================================

class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user  = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user


class User(AbstractBaseUser):
    GENDER_CHOICES = [
        ('male',              'Male'),
        ('female',            'Female'),
        ('other',             'Other'),
        ('prefer_not_to_say', 'Prefer not to say'),
    ]

    user_id                    = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email                      = models.EmailField(unique=True)
    full_name                  = models.CharField(max_length=150, blank=True, null=True)
    date_of_birth              = models.DateField(blank=True, null=True)
    gender                     = models.CharField(max_length=20, choices=GENDER_CHOICES, blank=True, null=True)
    phone_number               = models.CharField(max_length=20, blank=True, null=True)
    nationality                = models.CharField(max_length=100, blank=True, null=True)
    profile_image              = models.ImageField(upload_to='profiles/', blank=True, null=True)
    is_active                  = models.BooleanField(default=True)
    is_onboarded               = models.BooleanField(default=False)
    initial_survey_completed   = models.BooleanField(default=False)
    data_collection_start_date = models.DateField(blank=True, null=True)
    deleted_at                 = models.DateTimeField(blank=True, null=True)
    created_at                 = models.DateTimeField(auto_now_add=True)
    updated_at                 = models.DateTimeField(auto_now=True)

    USERNAME_FIELD  = 'email'
    REQUIRED_FIELDS = []

    objects = UserManager()

    class Meta:
        db_table = 'users'
        indexes  = [models.Index(fields=['email'])]

    def __str__(self):
        return self.email

    @property
    def is_deleted(self):
        return self.deleted_at is not None


# ============================================================
# DOCTOR
# ============================================================

class DoctorManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required for Doctor')
        email = self.normalize_email(email)
        user  = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user


class Doctor(AbstractBaseUser):
    STATUS_CHOICES = [
        ('pending',  'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    doctor_id        = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email            = models.EmailField(unique=True)
    full_name        = models.CharField(max_length=150)
    nationality      = models.CharField(max_length=100, blank=True, null=True)
    specialization   = models.CharField(max_length=150, blank=True, null=True)
    bio              = models.TextField(blank=True, null=True)
    profile_image    = models.ImageField(upload_to='profiles/', blank=True, null=True)
    cv_file_path     = models.FileField(upload_to='cvs/', blank=True, null=True)
    status           = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    rejection_reason = models.TextField(blank=True, null=True)
    is_active        = models.BooleanField(default=True)
    approved_at      = models.DateTimeField(blank=True, null=True)
    deleted_at       = models.DateTimeField(blank=True, null=True)
    created_at       = models.DateTimeField(auto_now_add=True)
    updated_at       = models.DateTimeField(auto_now=True)

    USERNAME_FIELD  = 'email'
    REQUIRED_FIELDS = []

    objects = DoctorManager()

    class Meta:
        db_table = 'doctors'
        indexes  = [
            models.Index(fields=['email']),
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return f"{self.full_name} ({self.status})"

    @property
    def is_approved(self):
        return self.status == 'approved'


# ============================================================
# ADMIN
# ============================================================

class AdminManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required for Admin')
        email = self.normalize_email(email)
        user  = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user


class Admin(AbstractBaseUser):
    admin_id      = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email         = models.EmailField(unique=True)
    full_name     = models.CharField(max_length=150, blank=True, null=True)
    created_at    = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD  = 'email'
    REQUIRED_FIELDS = []

    objects = AdminManager()

    class Meta:
        db_table = 'admins'

    def __str__(self):
        return self.email


# ============================================================
# USER SESSIONS
# ============================================================

class UserSession(models.Model):
    session_id  = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user        = models.ForeignKey('accounts.User',   on_delete=models.CASCADE, null=True, blank=True, related_name='sessions')
    doctor      = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, null=True, blank=True, related_name='sessions')
    admin       = models.ForeignKey('accounts.Admin',  on_delete=models.CASCADE, null=True, blank=True, related_name='sessions')
    token_hash  = models.TextField()
    device_info = models.JSONField(blank=True, null=True)
    ip_address  = models.GenericIPAddressField(blank=True, null=True)
    expires_at  = models.DateTimeField()
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'user_sessions'
        indexes  = [
            models.Index(fields=['token_hash']),
            models.Index(fields=['expires_at']),
        ]

    def clean(self):
        filled = sum([
            self.user_id   is not None,
            self.doctor_id is not None,
            self.admin_id  is not None,
        ])
        if filled != 1:
            raise ValidationError('Session must belong to exactly one role: user, doctor, or admin.')

    def __str__(self):
        owner = self.user or self.doctor or self.admin
        return f"Session({owner})"


# ============================================================
# AUTH TOKENS — Email Verification & Password Reset
# ============================================================

class AuthToken(models.Model):
    TYPE_CHOICES = [
        ('email_verification', 'Email Verification'),
        ('password_reset',     'Password Reset'),
    ]

    token_id   = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user       = models.ForeignKey('accounts.User',   on_delete=models.CASCADE, null=True, blank=True, related_name='auth_tokens')
    doctor     = models.ForeignKey('accounts.Doctor', on_delete=models.CASCADE, null=True, blank=True, related_name='auth_tokens')
    token_hash = models.TextField(unique=True)
    token_type = models.CharField(max_length=30, choices=TYPE_CHOICES)
    expires_at = models.DateTimeField()
    used_at    = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'auth_tokens'
        indexes  = [
            models.Index(fields=['token_hash']),
            models.Index(fields=['expires_at']),
        ]

    def clean(self):
        filled = sum([self.user_id is not None, self.doctor_id is not None])
        if filled != 1:
            raise ValidationError('AuthToken must belong to either a user or a doctor, not both.')

    @property
    def is_used(self):
        return self.used_at is not None

    @property
    def is_expired(self):
        from django.utils import timezone
        return timezone.now() > self.expires_at

    def __str__(self):
        owner = self.user or self.doctor
        return f"AuthToken({self.token_type} | {owner})"
