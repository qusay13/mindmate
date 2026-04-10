from django.urls import path
from .views import (
    DailyMoodView, DailyJournalView, DailyProgressView, 
    SubmitQuestionnaireView, QuestionnaireTypeListView, QuestionnaireQuestionListView
)


urlpatterns = [
    path('mood/', DailyMoodView.as_view(), name='daily-mood'),
    path('journal/', DailyJournalView.as_view(), name='daily-journal'),
    path('progress/', DailyProgressView.as_view(), name='daily-progress'),
    path('questionnaires/', QuestionnaireTypeListView.as_view(), name='questionnaire-types'),
    path('questionnaires/<str:code>/questions/', QuestionnaireQuestionListView.as_view(), name='questionnaire-questions'),
    path('questionnaires/submit/', SubmitQuestionnaireView.as_view(), name='submit-questionnaire'),
]

