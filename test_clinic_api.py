import os
import django
import json

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test.client import Client
from accounts.models import Doctor, User, Admin

def run_tests():
    c = Client()
    
    # Setup test data
    admin_email = "admin_clinic@example.com"
    user_email = "patient_clinic@example.com"
    doc_email = "doctor_clinic@example.com"
    password = "Password123!"

    if not Admin.objects.filter(email=admin_email).exists():
        admin = Admin(email=admin_email, full_name="Admin")
        admin.set_password(password)
        admin.save()
        
    if not User.objects.filter(email=user_email).exists():
        user = User(email=user_email, full_name="Test Patient")
        user.set_password(password)
        user.save()
        
    doc = Doctor.objects.filter(email=doc_email).first()
    if not doc:
        doc = Doctor(email=doc_email, full_name="Dr. Test", whatsapp_number="+1234567890")
        doc.set_password(password)
        doc.save()

    # Login functions
    def login(email, role):
        resp = c.post('/api/accounts/login/', data=json.dumps({"email": email, "password": password, "role": role}), content_type='application/json')
        return resp.json().get('token')

    admin_token = login(admin_email, 'admin')
    user_token = login(user_email, 'user')
    doc_token = login(doc_email, 'doctor')
    
    h_admin = {'HTTP_AUTHORIZATION': f'Bearer {admin_token}'}
    h_user = {'HTTP_AUTHORIZATION': f'Bearer {user_token}'}

    print("\n--- 1. Admin Approves Doctor ---")
    resp = c.patch(f'/api/clinic/doctors/{doc.doctor_id}/approve/', data=json.dumps({"status": "approved"}), content_type="application/json", **h_admin)
    print("Status:", resp.status_code, resp.json())

    print("\n--- 2. Unlinked Patient Views Profile ---")
    resp = c.get(f'/api/clinic/doctors/{doc.doctor_id}/', **h_user)
    print("Masked Whatsapp:", resp.json().get('whatsapp_number'))

    print("\n--- 3. Unlinked Patient Tries Contact API ---")
    resp = c.get(f'/api/clinic/doctors/{doc.doctor_id}/contact/', **h_user)
    print("Status:", resp.status_code, resp.json())

    print("\n--- 4. Patient Links With Doctor ---")
    resp = c.post('/api/clinic/link/', data=json.dumps({"doctor_id": str(doc.doctor_id)}), content_type="application/json", **h_user)
    print("Status:", resp.status_code, resp.json())

    print("\n--- 5. Duplicate Linking Protection ---")
    resp = c.post('/api/clinic/link/', data=json.dumps({"doctor_id": str(doc.doctor_id)}), content_type="application/json", **h_user)
    print("Status:", resp.status_code, resp.json())

    print("\n--- 6. Linked Patient Views Profile ---")
    resp = c.get(f'/api/clinic/doctors/{doc.doctor_id}/', **h_user)
    print("Masked Whatsapp:", resp.json().get('whatsapp_number'))

    print("\n--- 7. Linked Patient Tries Contact API ---")
    resp = c.get(f'/api/clinic/doctors/{doc.doctor_id}/contact/', **h_user)
    print("Status:", resp.status_code, resp.json())


if __name__ == '__main__':
    run_tests()
