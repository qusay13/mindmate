"""
tests/conftest.py
=================
Shared fixtures for the MindMate test suite.
Provides pre-built User, Doctor, Admin, and authenticated API clients.
"""

import hashlib
import uuid
import pytest
from datetime import timedelta
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import User, Doctor, Admin, UserSession


# ──────────────────────────────────────────────
# Model Fixtures
# ──────────────────────────────────────────────

@pytest.fixture
def user(db):
    """Create a standard patient user."""
    return User.objects.create_user(
        email='patient@mindmate.test',
        password='securepass123',
        full_name='Test Patient',
    )


@pytest.fixture
def user_b(db):
    """Create a second patient for isolation tests."""
    return User.objects.create_user(
        email='patient_b@mindmate.test',
        password='securepass123',
        full_name='Test Patient B',
    )


@pytest.fixture
def doctor(db):
    """Create an approved doctor."""
    doc = Doctor.objects.create(
        email='doctor@mindmate.test',
        full_name='Dr. Test',
        specialization='General Psychiatry',
        status='approved',
    )
    doc.set_password('securepass123')
    doc.save()
    return doc


@pytest.fixture
def pending_doctor(db):
    """Create a doctor still in pending status."""
    doc = Doctor.objects.create(
        email='pending_doc@mindmate.test',
        full_name='Dr. Pending',
        status='pending',
    )
    doc.set_password('securepass123')
    doc.save()
    return doc


@pytest.fixture
def admin(db):
    """Create an admin user."""
    return Admin.objects.create_user(
        email='admin@mindmate.test',
        password='securepass123',
        full_name='Test Admin',
    )


# ──────────────────────────────────────────────
# Authentication Helpers
# ──────────────────────────────────────────────

def _create_session(user_obj=None, doctor_obj=None, admin_obj=None):
    """Create a UserSession and return the raw token string."""
    raw_token = str(uuid.uuid4())
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    UserSession.objects.create(
        user=user_obj,
        doctor=doctor_obj,
        admin=admin_obj,
        token_hash=token_hash,
        expires_at=timezone.now() + timedelta(days=7),
    )
    return raw_token


@pytest.fixture
def api_client():
    """Unauthenticated DRF API client."""
    return APIClient()


@pytest.fixture
def user_client(user):
    """Authenticated API client for a patient user."""
    client = APIClient()
    token = _create_session(user_obj=user)
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
    return client


@pytest.fixture
def doctor_client(doctor):
    """Authenticated API client for an approved doctor."""
    client = APIClient()
    token = _create_session(doctor_obj=doctor)
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
    return client


@pytest.fixture
def admin_client(admin):
    """Authenticated API client for an admin."""
    client = APIClient()
    token = _create_session(admin_obj=admin)
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
    return client
