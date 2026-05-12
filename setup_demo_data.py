#!/usr/bin/env python
"""
MindMate Demo Data Setup Script
- Sets up doctor specializations
- Creates 3 demo users (depression, anxiety, stress)
- Populates 30 days of mood, journal, questionnaire data
Run: python setup_demo_data.py
"""
import os
import sys
import django
import random
from datetime import date, timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.utils import timezone
from accounts.models import Doctor, User, Admin
from clinic.models import DoctorConditionTag, DoctorPatientRelationship, DoctorPatientRequest
from tracking.models import (
    DailyMoodEntry, JournalEntry, DailyProgress,
    QuestionnaireSession, QuestionnaireAnswer, QuestionnaireQuestion, QuestionnaireType,
    JournalSharingPermission, JournalAnalysis
)

print("=" * 60)
print("MindMate Demo Data Setup")
print("=" * 60)

# ============================================================
# STEP 1: Update Doctor Specializations
# ============================================================
print("\n[1] Setting up doctor specializations...")

doctor_profiles = [
    {
        'email': 'qusay13@mindmate.com',
        'specialization': 'Depression & Mood Disorders',
        'bio': 'متخصص في علاج الاكتئاب واضطرابات المزاج. أساعد المرضى في التغلب على الاكتئاب من خلال العلاج المعرفي السلوكي وتقنيات الوعي الذاتي.',
        'condition': 'depression',
        'full_name': 'Dr. Ahmad Al-Rashid',
    },
    {
        'email': 'systest_doctor@mindmate.test',
        'specialization': 'Anxiety & Panic Disorders',
        'bio': 'أختص في علاج اضطرابات القلق ونوبات الهلع. خبرة 10 سنوات في مساعدة المرضى على التحرر من سيطرة القلق واستعادة حياتهم الطبيعية.',
        'condition': 'anxiety',
        'full_name': 'Dr. Sara Al-Mansoori',
    },
    {
        'email': 'qusay13@gmail.com',
        'specialization': 'Stress & Burnout Management',
        'bio': 'متخصص في إدارة التوتر والإرهاق الوظيفي. أوفر استراتيجيات مخصصة للتعامل مع ضغوط الحياة اليومية والعمل.',
        'condition': 'stress',
        'full_name': 'Dr. Omar Al-Khalidi',
    }
]

for profile in doctor_profiles:
    try:
        doc = Doctor.objects.get(email=profile['email'])
        doc.specialization = profile['specialization']
        doc.bio = profile['bio']
        doc.full_name = profile['full_name']
        doc.status = 'approved'
        doc.is_active = True
        doc.save()
        # Clear old tags
        DoctorConditionTag.objects.filter(doctor=doc).delete()
        DoctorConditionTag.objects.create(doctor=doc, condition=profile['condition'])
        print(f"  ✅ {doc.full_name} → {profile['specialization']}")
    except Doctor.DoesNotExist:
        print(f"  ⚠️  Doctor {profile['email']} not found, skipping...")

# ============================================================
# STEP 2: Create Demo Users
# ============================================================
print("\n[2] Creating demo users...")

demo_users = [
    {
        'email': 'patient_depression@mindmate.test',
        'password': 'Test1234!',
        'full_name': 'Layla Hassan',
        'condition': 'depression',
        'doctor_email': 'qusay13@mindmate.com',
        'mood_range': (1, 2),  # mostly very_bad, bad
        'journal_entries': [
            "أشعر بثقل شديد اليوم. لا أريد الخروج من السرير.",
            "يوم آخر من الفراغ. لا أجد معنى لأي شيء أفعله.",
            "حاولت التحدث مع أصدقائي لكنني عجزت. أشعر بالوحدة الشديدة.",
            "النوم لا يريحني. أستيقظ وأنا أكثر تعباً مما كنت قبل النوم.",
            "أفكر كثيراً في الماضي وأتمنى لو أنني لم أكن هنا.",
        ]
    },
    {
        'email': 'patient_anxiety@mindmate.test',
        'password': 'Test1234!',
        'full_name': 'Khalid Nasser',
        'condition': 'anxiety',
        'doctor_email': 'systest_doctor@mindmate.test',
        'mood_range': (2, 3),  # bad, neutral
        'journal_entries': [
            "قلقي لا يتوقف. أفكر في كل الأشياء السيئة التي يمكن أن تحدث.",
            "كنت في اجتماع العمل وشعرت بأن قلبي سيتوقف من شدة التوتر.",
            "لا أستطيع النوم. عقلي يعمل طوال الليل بأسوأ السيناريوهات.",
            "أتجنب الخروج خوفاً من مواجهة المواقف الصعبة.",
            "شعرت اليوم بأنني سأفقد السيطرة خلال محاضرة الجامعة.",
        ]
    },
    {
        'email': 'patient_stress@mindmate.test',
        'password': 'Test1234!',
        'full_name': 'Nora Al-Amri',
        'condition': 'stress',
        'doctor_email': 'qusay13@gmail.com',
        'mood_range': (2, 3),  # bad, neutral
        'journal_entries': [
            "العمل لا يتوقف. ثلاثة مشاريع في آن واحد وكلها عاجلة.",
            "يرأسي يصطدم كلما فكرت في الأسبوع القادم. المواعيد النهائية تضغطني.",
            "لا أتذكر آخر مرة استرحت فيها حقاً. حياتي كلها ضغط.",
            "أكثر من المطلوب مني في كل مكان - العمل، المنزل، الأسرة.",
            "أحاول أن أكون بخير لكن التوتر يتراكم يوماً بعد يوم.",
        ]
    }
]

# questionnaire score ranges per condition
def get_scores(condition, q_code):
    """Returns (min_score, max_score) for given condition and questionnaire"""
    if condition == 'depression':
        if q_code == 'PHQ9':  # depression scale 0-27
            return (18, 25)  # moderately severe to severe
        elif q_code == 'GAD7':  # anxiety
            return (5, 10)
        else:  # PSS10 stress
            return (15, 22)
    elif condition == 'anxiety':
        if q_code == 'PHQ9':
            return (5, 12)
        elif q_code == 'GAD7':  # anxiety scale 0-21
            return (15, 21)  # severe anxiety
        else:
            return (18, 28)
    else:  # stress
        if q_code == 'PHQ9':
            return (5, 10)
        elif q_code == 'GAD7':
            return (8, 14)
        else:  # PSS10 stress scale 0-40
            return (28, 38)  # high stress

mood_labels = {1: 'very_bad', 2: 'bad', 3: 'neutral', 4: 'good', 5: 'very_good'}

for user_data in demo_users:
    # Create or get user
    user, created = User.objects.get_or_create(
        email=user_data['email'],
        defaults={
            'full_name': user_data['full_name'],
            'is_active': True,
            'is_onboarded': True,
            'initial_survey_completed': True,
        }
    )
    if created:
        user.set_password(user_data['password'])
        user.save()
        print(f"  ✅ Created user: {user.email}")
    else:
        print(f"  ℹ️  User exists: {user.email}")

    # Link to their doctor
    try:
        doctor = Doctor.objects.get(email=user_data['doctor_email'])
        req, _ = DoctorPatientRequest.objects.get_or_create(
            user=user, doctor=doctor,
            defaults={'request_type': 'user_selected', 'status': 'accepted'}
        )
        rel, created_rel = DoctorPatientRelationship.objects.get_or_create(
            user=user, doctor=doctor,
            defaults={'status': 'active', 'request': req}
        )
        if created_rel:
            print(f"    🔗 Linked to {doctor.full_name}")
        # Enable journal sharing
        JournalSharingPermission.objects.get_or_create(
            user=user, doctor=doctor,
            defaults={'share_full_journal': True, 'share_analysis_only': False}
        )
    except Doctor.DoesNotExist:
        print(f"    ⚠️  Doctor {user_data['doctor_email']} not found")

    # Get questionnaire types
    qtypes = {qt.code.replace('-', ''): qt for qt in QuestionnaireType.objects.filter(is_active=True)}
    print(f"    Available questionnaire types: {list(qtypes.keys())}")

    # Generate 30 days of data
    today = date.today()
    journal_pool = user_data['journal_entries']

    for day_offset in range(30, 0, -1):
        entry_date = today - timedelta(days=day_offset)

        # Mood (always)
        mood_level = random.randint(*user_data['mood_range'])
        # Slight upward trend in last 5 days (showing they're seeking help)
        if day_offset <= 5:
            mood_level = min(mood_level + 1, 3)
        
        DailyMoodEntry.objects.get_or_create(
            user=user, recorded_date=entry_date,
            defaults={
                'mood_level': mood_level,
                'mood_label': mood_labels[mood_level],
                'reason_note': 'يوم صعب'
            }
        )

        # Journal (every 2-3 days)
        if day_offset % 3 != 0:
            journal_text = random.choice(journal_pool)
            JournalEntry.objects.get_or_create(
                user=user, entry_date=entry_date,
                defaults={'content': journal_text}
            )

        # Questionnaire (every 7 days, rotating)
        qtype_list = list(qtypes.values())
        if day_offset % 7 == 0 and qtype_list:
            q_idx = (day_offset // 7 - 1) % len(qtype_list)
            q_type = qtype_list[q_idx]
            
            q_code = q_type.code.replace('-', '')
            score_range = get_scores(user_data['condition'], q_code)
            target_score = random.randint(*score_range)
            
            session, sess_created = QuestionnaireSession.objects.get_or_create(
                user=user, questionnaire_type=q_type, session_date=entry_date,
                defaults={
                    'completed': True,
                    'total_score': target_score,
                    'severity_level': 'severe' if target_score > score_range[1] * 0.7 else 'moderate',
                    'completed_at': timezone.make_aware(
                        timezone.datetime.combine(entry_date, timezone.datetime.min.time())
                    )
                }
            )

        # Daily Progress
        progress, _ = DailyProgress.objects.get_or_create(
            user=user, progress_date=entry_date,
            defaults={
                'mood_completed': True,
                'journal_completed': day_offset % 3 != 0,
                'phq9_completed': day_offset % 7 == 0 and 'PHQ9' in qtypes,
                'gad7_completed': day_offset % 7 == 3 and 'GAD7' in qtypes,
                'pss10_completed': day_offset % 7 == 6 and 'PSS10' in qtypes,
            }
        )

    print(f"    📊 Generated 30 days of data for {user.full_name}")

print("\n✅ Demo data setup complete!")
print("\nDemo Users:")
for u in demo_users:
    print(f"  📧 {u['email']} | 🔑 {u['password']} | 🏥 {u['condition'].upper()}")
