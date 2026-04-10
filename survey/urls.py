from django.urls import path
from .views import QuestionListView, SubmitSurveyView

urlpatterns = [
    path('questions/', QuestionListView.as_view(), name='survey-questions'),
    path('submit/', SubmitSurveyView.as_view(), name='survey-submit'),
]
