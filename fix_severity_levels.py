"""
Fix demo data: recompute severity levels using the actual RaedRepo scoring algorithm
instead of the hardcoded 'severe'/'moderate' values from setup_demo_data.py
"""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from accounts.models import User
from tracking.models import QuestionnaireSession
from external.RaedRepo.scoring import classify_questionnaire_severity

DEMO_EMAILS = [
    'patient_depression@mindmate.test',
    'patient_anxiety@mindmate.test',
    'patient_stress@mindmate.test',
]

for email in DEMO_EMAILS:
    u = User.objects.get(email=email)
    sessions = QuestionnaireSession.objects.filter(user=u, completed=True).select_related('questionnaire_type')
    print(f"\n=== {u.full_name} ===")
    for s in sessions:
        q_code = s.questionnaire_type.code.replace('-', '')
        score = s.total_score or 0
        try:
            label_ar, severity_key = classify_questionnaire_severity(score, q_code)
        except Exception as e:
            print(f"  ERROR computing {q_code} score={score}: {e}")
            severity_key = 'moderate'
        
        old = s.severity_level
        s.severity_level = severity_key
        s.save(update_fields=['severity_level'])
        print(f"  {q_code}: score={score} | {old!r} → {severity_key!r}")

print("\n✅ Severity levels recomputed!")
