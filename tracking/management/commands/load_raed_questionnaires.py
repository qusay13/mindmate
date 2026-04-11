import sys
import os
from django.core.management.base import BaseCommand
from django.db import transaction

# Append project root and RaedRepo to path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../../'))
sys.path.append(project_root)
sys.path.append(os.path.join(project_root, 'external', 'RaedRepo'))

from tracking.models import QuestionnaireType, QuestionnaireQuestion
from external.RaedRepo.questionnaires import get_all_questions, QUESTIONNAIRE_INFO

class Command(BaseCommand):
    help = 'Load standard Arabic questionnaires from RaedRepo into the database'

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("Starting to load RaedRepo questionnaires..."))

        all_questions = get_all_questions()

        with transaction.atomic():
            # Clear old ones
            QuestionnaireType.objects.all().delete()

            for q_code, info in QUESTIONNAIRE_INFO.items():
                self.stdout.write(f"Processing {q_code}...")
                
                # Convert severity thresholds to json format for the model if needed (or simply keep it empty since we will use RaedRepo's scoring directly now)
                q_type = QuestionnaireType.objects.create(
                    code=q_code,
                    name=info['name_ar'],
                    description=f"{info['name_short_ar']} assessment",
                    max_score=info['max_score'],
                    scoring_ranges=None, # We'll rely on RaedRepo's logic directly via code
                    is_active=True
                )

                # Get items
                items = all_questions.get(q_code, [])
                for item in items:
                    # Format options
                    options_json = []
                    for i, opt_ar in enumerate(item.options_ar):
                        options_json.append({
                            "label": opt_ar,
                            "score": item.option_scores[i]
                        })

                    QuestionnaireQuestion.objects.create(
                        questionnaire_type=q_type,
                        question_text=item.text_ar,
                        question_order=item.question_index, # 1-based usually
                        options=options_json,
                        is_active=True
                    )

                self.stdout.write(self.style.SUCCESS(f"Successfully loaded {len(items)} questions for {q_code}"))
        
        self.stdout.write(self.style.SUCCESS("All questionnaires loaded successfully!"))
