import os
import django
import json

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test.client import Client
from survey.models import InitialSurveyQuestion
from accounts.models import User

def run_tests():
    c = Client()
    
    # 1. Create dummy questions if they don't exist
    if InitialSurveyQuestion.objects.count() == 0:
        InitialSurveyQuestion.objects.create(question_text="How are you?", question_type="text", display_order=1)
        InitialSurveyQuestion.objects.create(question_text="Select your mood", question_type="scale", display_order=2)
    
    # 2. Login to get token
    login_payload = {
        "email": "testuser@example.com",
        "password": "strongPassword123!",
        "role": "user"
    }
    resp = c.post('/api/accounts/login/', data=json.dumps(login_payload), content_type='application/json')
    if resp.status_code != 200:
        print("Login Failed! Status Code:", resp.status_code)
        print("Response:", resp.content)
        return
        
    token = resp.json().get('token')
    headers = {'HTTP_AUTHORIZATION': f'Bearer {token}'}
    
    print("\n--- Testing GET /api/survey/questions/ ---")
    resp = c.get('/api/survey/questions/', **headers)
    print("Status Code:", resp.status_code)
    try:
        questions = resp.json()
        print(f"Retrieved {len(questions)} questions")
    except:
        print("Response:", resp.content)
        return

    # Grab the IDs to submit
    q1_id = questions[0]['question_id']
    q2_id = questions[1]['question_id']

    # 3. Submit responses
    print("\n--- Testing POST /api/survey/submit/ ---")
    submit_payload = {
        "responses": [
            {"question": q1_id, "answer_text": "I am good"},
            {"question": q2_id, "answer_value": "8.5"}
        ]
    }
    resp = c.post('/api/survey/submit/', data=json.dumps(submit_payload), content_type='application/json', **headers)
    print("Status Code:", resp.status_code)
    print("Response:", resp.json())
    
    # Verify user state
    user = User.objects.get(email="testuser@example.com")
    print(f"User is_onboarded: {user.is_onboarded}")
    print(f"User initial_survey_completed: {user.initial_survey_completed}")

if __name__ == '__main__':
    run_tests()
