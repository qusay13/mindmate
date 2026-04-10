import os
import django
import json

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test.client import Client

def run_tests():
    c = Client()
    
    # Login
    login_payload = {
        "email": "testuser@example.com",
        "password": "strongPassword123!",
        "role": "user"
    }
    resp = c.post('/api/accounts/login/', data=json.dumps(login_payload), content_type='application/json')
    if resp.status_code != 200:
        print("Login Failed!")
        return
        
    token = resp.json().get('token')
    headers = {'HTTP_AUTHORIZATION': f'Bearer {token}'}
    
    print("\n--- Testing POST Mood ---")
    resp = c.post('/api/tracking/mood/', data=json.dumps({"mood_level": 5, "reason_note": "Great day"}), content_type='application/json', **headers)
    print("Status:", resp.status_code)
    print(resp.json())

    print("\n--- Testing POST Journal ---")
    resp = c.post('/api/tracking/journal/', data=json.dumps({"content": "Today I ran 5k and felt amazing."}), content_type='application/json', **headers)
    print("Status:", resp.status_code)
    print(resp.json())

    print("\n--- Testing GET Daily Progress ---")
    resp = c.get('/api/tracking/progress/', **headers)
    print("Status:", resp.status_code)
    print(resp.json())

if __name__ == '__main__':
    run_tests()
