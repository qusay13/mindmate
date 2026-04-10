from django.urls import path
from .views import DailyMoodView, DailyJournalView, DailyProgressView, SubmitQuestionnaireView

urlpatterns = [
    path('mood/', DailyMoodView.as_view(), name='daily-mood'),
    path('journal/', DailyJournalView.as_view(), name='daily-journal'),
    path('progress/', DailyProgressView.as_view(), name='daily-progress'),
    path('questionnaires/submit/', SubmitQuestionnaireView.as_view(), name='submit-questionnaire'),
]
