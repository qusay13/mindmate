import random
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from accounts.models import User
from tracking.models import (
    DailyMoodEntry, QuestionnaireSession, QuestionnaireAnswer, 
    QuestionnaireType, QuestionnaireQuestion, DailyProgress
)
from django.core.cache import cache

class Command(BaseCommand):
    help = 'Seeds 25 days of data for ALL users indicating depression/anxiety for testing'

    def handle(self, *args, **options):
        users = User.objects.all()
        if not users.exists():
            self.stdout.write(self.style.ERROR('No users found'))
            return

        phq9_type = QuestionnaireType.objects.get(code='PHQ9')
        gad7_type = QuestionnaireType.objects.get(code='GAD7')
        phq9_questions = list(QuestionnaireQuestion.objects.filter(questionnaire_type=phq9_type))
        gad7_questions = list(QuestionnaireQuestion.objects.filter(questionnaire_type=gad7_type))

        depression_notes = [
            "أشعر بحزن عميق اليوم ولا أرغب في الخروج من السرير.",
            "فقدت الاهتمام بكثير من الأشياء التي كنت أحبها.",
            "أجد صعوبة في التركيز، أشعر وكأن عقلي مشوش.",
            "نومي متقطع، أشعر بالتعب حتى بعد ساعات طوال.",
            "أشعر وكأني عبء على من حولي.",
            "شهيتي للطعام منعدمة تقريباً.",
            "اليوم كان صعباً جداً، لم أستطع إنجاز أي شيء.",
            "أشعر بفراغ كبير في داخلي.",
            "الغد يبدو كجبل مستحيل التسلق.",
            "أتساءل متى سأشعر بالتحسن ثانية."
        ]

        today = timezone.localdate()

        for user in users:
            self.stdout.write(f'Seeding data for {user.email}...')
            
            # Clear existing data
            DailyMoodEntry.objects.filter(user=user).delete()
            QuestionnaireSession.objects.filter(user=user).delete()
            DailyProgress.objects.filter(user=user).delete()
            cache.delete(f"user_analysis_{user.user_id}")

            for i in range(26, -1, -1):
                date = today - timedelta(days=i)
                
                # 1. Mood (Depressed pattern)
                mood_level = random.choice([1, 1, 2])
                mood_label = {1: 'Very Bad', 2: 'Bad', 3: 'Neutral'}[mood_level]
                
                DailyMoodEntry.objects.create(
                    user=user,
                    recorded_date=date,
                    mood_level=mood_level,
                    mood_label=mood_label,
                    reason_note=random.choice(depression_notes)
                )

                # 2. PHQ-9 (Depression) - High scores
                phq_session = QuestionnaireSession.objects.create(
                    user=user,
                    questionnaire_type=phq9_type,
                    session_date=date,
                    completed=True,
                    completed_at=timezone.now()
                )
                
                phq_total = 0
                for q in phq9_questions:
                    score = random.choice([2, 3])
                    phq_total += score
                    QuestionnaireAnswer.objects.create(
                        session=phq_session,
                        question=q,
                        selected_option=score,
                        score=score
                    )
                phq_session.severity_level = 'Severe' if phq_total >= 20 else 'Moderately Severe'
                phq_session.save()

                # 3. GAD-7 (Anxiety) - Every other day
                if i % 2 == 0:
                    gad_session = QuestionnaireSession.objects.create(
                        user=user,
                        questionnaire_type=gad7_type,
                        session_date=date,
                        completed=True,
                        completed_at=timezone.now()
                    )
                    gad_total = 0
                    for q in gad7_questions:
                        score = random.choice([1, 2, 3])
                        gad_total += score
                        QuestionnaireAnswer.objects.create(
                            session=gad_session,
                            question=q,
                            selected_option=score,
                            score=score
                        )
                    gad_session.severity_level = 'Severe' if gad_total >= 15 else 'Moderate'
                    gad_session.save()

                # 4. Progress
                DailyProgress.objects.create(
                    user=user,
                    progress_date=date,
                    mood_completed=True,
                    journal_completed=True,
                    questionnaire_completed=True,
                    phq9_completed=True,
                    gad7_completed=(i % 2 == 0),
                    pss10_completed=False,
                    all_completed=(i % 2 == 0) # simplified
                )

        self.stdout.write(self.style.SUCCESS('Successfully seeded all users'))
