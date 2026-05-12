"""
Fix questionnaire sessions to include actual answer records.
This is needed for Domain Averages to show correct scores.
Run: python fix_questionnaire_answers.py
"""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

import random
from accounts.models import User
from tracking.models import (
    QuestionnaireSession, QuestionnaireAnswer, QuestionnaireQuestion
)

DEMO_EMAILS = [
    'patient_depression@mindmate.test',
    'patient_anxiety@mindmate.test',
    'patient_stress@mindmate.test',
]

# Score distributions per condition (fraction of max score per question to hit target)
CONDITION_BIAS = {
    'patient_depression@mindmate.test': {'PHQ9': 0.80, 'GAD7': 0.35, 'PSS10': 0.50},
    'patient_anxiety@mindmate.test':   {'PHQ9': 0.35, 'GAD7': 0.85, 'PSS10': 0.65},
    'patient_stress@mindmate.test':    {'PHQ9': 0.35, 'GAD7': 0.50, 'PSS10': 0.85},
}

total_fixed = 0
for email in DEMO_EMAILS:
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        print(f"User {email} not found, skipping")
        continue

    sessions = QuestionnaireSession.objects.filter(user=user, completed=True)
    bias = CONDITION_BIAS.get(email, {})

    for session in sessions:
        if session.answers.exists():
            print(f"  ⏭️  {user.full_name} | {session.questionnaire_type.code} already has answers")
            continue

        q_code = session.questionnaire_type.code.replace('-', '')
        target_bias = bias.get(q_code, 0.50)

        questions = QuestionnaireQuestion.objects.filter(
            questionnaire_type=session.questionnaire_type,
            is_active=True
        ).order_by('question_order')

        if not questions.exists():
            print(f"  ⚠️  No questions for {session.questionnaire_type.code}")
            continue

        total_score = 0
        created_answers = 0
        for q in questions:
            # Determine score based on bias and add some randomness
            options = q.options  # list of dicts [{label, score}, ...]
            if not options:
                continue

            max_score = max(opt['score'] for opt in options)
            target_score = int(max_score * target_bias)
            # Add ±1 variation
            target_score = max(0, min(max_score, target_score + random.randint(-1, 1)))

            # Find the closest option
            best_opt_idx = 0
            best_opt_score = 0
            min_diff = float('inf')
            for idx, opt in enumerate(options):
                diff = abs(opt['score'] - target_score)
                if diff < min_diff:
                    min_diff = diff
                    best_opt_idx = idx
                    best_opt_score = opt['score']

            QuestionnaireAnswer.objects.create(
                session=session,
                question=q,
                selected_option=best_opt_idx,
                score=best_opt_score
            )
            total_score += best_opt_score
            created_answers += 1

        # Update session total score
        session.total_score = total_score
        session.save(update_fields=['total_score'])

        print(f"  ✅ {user.full_name} | {session.questionnaire_type.code} | {created_answers} answers | score={total_score}")
        total_fixed += 1

print(f"\n✅ Fixed {total_fixed} questionnaire sessions with real answer data.")
print("Now clear the analysis cache for accurate results:")
print("  python manage.py shell -c \"from django.core.cache import cache; cache.clear(); print('Cache cleared')\"")
