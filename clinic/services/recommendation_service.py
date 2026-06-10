"""
Doctor Recommendation Service
Maps questionnaire results → condition → matching doctor specialization
"""
from clinic.models import DoctorConditionTag, DoctorPatientRelationship
from accounts.models import Doctor

# Maps questionnaire code → primary condition
QUESTIONNAIRE_CONDITION_MAP = {
    'PHQ9': 'mood',
    'GAD7': 'anxiety_phobia_ptsd',
    'PSS10': 'psychosomatic',
}

# Minimum severity levels that trigger a recommendation
RECOMMEND_THRESHOLD = {'moderate', 'moderately_severe', 'severe', 'high', 'very_high', 'high_perceived_stress', 'moderate_perceived_stress'}


def suggest_doctor_for_user(user, questionnaire_code, severity_level):
    """
    After a questionnaire is completed with moderate+ severity,
    suggest a doctor whose condition tag matches the questionnaire type.

    Returns: dict with doctor info or None
    """
    from datetime import date
    from django.utils import timezone
    from tracking.models import JournalEntry

    # 1. Check age first (under 18 or 60+)
    age = None
    if user.date_of_birth:
        today = timezone.localdate()
        age = today.year - user.date_of_birth.year - ((today.month, today.day) < (user.date_of_birth.month, user.date_of_birth.day))

    condition = None

    if age is not None and age < 18:
        condition = 'child_adolescent'
    elif age is not None and age >= 60:
        condition = 'geriatric'
    else:
        # 2. Check questionnaire result
        if severity_level and severity_level.lower() in RECOMMEND_THRESHOLD:
            condition = QUESTIONNAIRE_CONDITION_MAP.get(questionnaire_code)

    # 3. If no condition from age/questionnaires, check journal keywords from the last 30 days
    if not condition:
        thirty_days_ago = timezone.localdate() - timezone.timedelta(days=30)
        journals = JournalEntry.objects.filter(user=user, entry_date__gte=thirty_days_ago)
        
        # Merge all journal texts
        journal_text = " ".join([j.content for j in journals]).lower()
        
        # Check keywords
        if any(kw in journal_text for kw in ['إدمان', 'مدمن', 'كحول', 'مخدرات', 'حبوب', 'شراب', 'حشيش', 'سموم', 'addiction', 'drugs', 'alcohol']):
            condition = 'addiction'
        elif any(kw in journal_text for kw in ['محكمة', 'قانون', 'جريمة', 'عقوبة', 'سجن', 'قضية', 'حكم', 'جنائي', 'forensic', 'court', 'prison']):
            condition = 'forensic'
        elif any(kw in journal_text for kw in ['فصام', 'شيزوفرينيا', 'هلوسة', 'أصوات', 'ذهان', 'أوهام', 'ضلالات', 'schizophrenia', 'hallucinations', 'voices']):
            condition = 'psychotic'
        elif any(kw in journal_text for kw in ['دماغ', 'أعصاب', 'صرع', 'تشنج', 'رعشة', 'نسيان', 'ارتجاج', 'brain', 'neurology', 'epilepsy', 'seizure']):
            condition = 'neuropsychiatry'

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
        'severity': severity_level or 'N/A',
        'message': f'بناءً على التقييم، نوصي بالتواصل مع متخصص في {_condition_label(condition)}.',
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
        'child_adolescent': 'طب نفس الأطفال والمراهقين',
        'geriatric': 'الطب النفسي للمسنين (الشيخوخة)',
        'addiction': 'طب الإدمان وعلاج الاعتماد',
        'forensic': 'الطب النفسي الشرعي والقانوني',
        'psychosomatic': 'الطب النفسي الجسدي',
        'neuropsychiatry': 'الفسيولوجيا العصبية السريرية والطب النفسي العصبي',
        'psychotic': 'الفصام والاضطرابات الذهانية',
        'mood': 'اضطرابات المزاج (الاكتئاب الحاد، والاضطراب ثنائي القطب)',
        'anxiety_phobia_ptsd': 'اضطرابات القلق، الرهاب، واضطراب ما بعد الصدمة (PTSD)',
    }
    return labels.get(condition, 'الصحة النفسية والعقلية')
