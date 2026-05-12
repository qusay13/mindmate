"""
Doctor Recommendation Service
Maps questionnaire results → condition → matching doctor specialization
"""
from clinic.models import DoctorConditionTag, DoctorPatientRelationship
from accounts.models import Doctor

# Maps questionnaire code → primary condition
QUESTIONNAIRE_CONDITION_MAP = {
    'PHQ9': 'depression',
    'GAD7': 'anxiety',
    'PSS10': 'stress',
}

# Minimum severity levels that trigger a recommendation
RECOMMEND_THRESHOLD = {'moderate', 'moderately_severe', 'severe', 'high', 'very_high', 'high_perceived_stress', 'moderate_perceived_stress'}


def suggest_doctor_for_user(user, questionnaire_code, severity_level):
    """
    After a questionnaire is completed with moderate+ severity,
    suggest a doctor whose condition tag matches the questionnaire type.

    Returns: dict with doctor info or None
    """
    if not severity_level or severity_level.lower() not in RECOMMEND_THRESHOLD:
        return None  # No recommendation needed for mild/minimal

    condition = QUESTIONNAIRE_CONDITION_MAP.get(questionnaire_code)
    if not condition:
        return None

    # Check if user is already linked to an appropriate doctor
    already_linked_doctors = DoctorPatientRelationship.objects.filter(
        user=user, status='active'
    ).values_list('doctor_id', flat=True)

    # Find doctors with matching condition tag (not already linked)
    matching_tags = DoctorConditionTag.objects.filter(
        condition=condition,
        doctor__status='approved',
        doctor__is_active=True,
    ).exclude(doctor_id__in=already_linked_doctors).select_related('doctor')

    if not matching_tags.exists():
        # If all matching doctors are already linked, return None
        return None

    # Pick the best match (first available)
    doctor = matching_tags.first().doctor

    return {
        'doctor_id': str(doctor.doctor_id),
        'full_name': doctor.full_name,
        'specialization': doctor.specialization,
        'bio': doctor.bio,
        'condition_match': condition,
        'severity': severity_level,
        'message': f'بناءً على نتائج تقييمك، نوصي بالتواصل مع متخصص في {_condition_label(condition)}.',
    }


def get_best_doctor_for_condition(condition):
    """Public helper to get the best doctor for a given condition string."""
    tag = DoctorConditionTag.objects.filter(
        condition=condition,
        doctor__status='approved',
        doctor__is_active=True,
    ).select_related('doctor').first()
    return tag.doctor if tag else None


def _condition_label(condition):
    labels = {
        'depression': 'الاكتئاب واضطرابات المزاج',
        'anxiety': 'القلق واضطرابات الهلع',
        'stress': 'التوتر والإرهاق النفسي',
        'trauma': 'الصدمات النفسية',
        'ocd': 'الوسواس القهري',
        'general': 'الصحة النفسية العامة',
    }
    return labels.get(condition, 'الصحة النفسية')
