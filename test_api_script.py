import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test.client import Client
import json

def run_tests():
    c = Client()
    print("--- 1. Testing User Registration ---")
    user_payload = {
        "email": "testuser@example.com",
        "password": "strongPassword123!",
        "full_name": "Test User",
    }
    resp = c.post('/api/accounts/register/user/', data=json.dumps(user_payload), content_type='application/json')
    print("Status Code:", resp.status_code)
    print("Response:", resp.json())

    print("\n--- 2. Testing Doctor Registration ---")
    doc_payload = {
        "email": "testdoctor@example.com",
        "password": "doctorPassword123!",
        "full_name": "Test Doctor",
        "specialization": "Therapist"
    }
    resp = c.post('/api/accounts/register/doctor/', data=json.dumps(doc_payload), content_type='application/json')
    print("Status Code:", resp.status_code)
    print("Response:", resp.json())

    print("\n--- 3. Testing User Login ---")
    login_payload = {
        "email": "testuser@example.com",
        "password": "strongPassword123!",
        "role": "user"
    }
    resp = c.post('/api/accounts/login/', data=json.dumps(login_payload), content_type='application/json')
    print("Status Code:", resp.status_code)
    token = None
    try:
        login_data = resp.json()
        print("Response Keys:", list(login_data.keys()))
        token = login_data.get('token')
        print("Token retrieved:", "Yes" if token else "No")
    except Exception as e:
        print("Failed to parse JSON:", resp.content)

    if token:
        print("\n--- 4. Testing User Logout ---")
        headers = {'HTTP_AUTHORIZATION': f'Bearer {token}'}
        resp = c.post('/api/accounts/logout/', **headers)
        print("Status Code:", resp.status_code)
        print("Response:", resp.json())
        
        print("\n--- 5. Testing Logout Again (Should fail on used or invalid token) ---")
        resp = c.post('/api/accounts/logout/', **headers)
        print("Status Code:", resp.status_code)
        try:
            print("Response:", resp.json())
        except:
            print("Response:", resp.content)

if __name__ == '__main__':
    run_tests()
