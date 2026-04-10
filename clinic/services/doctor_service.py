from clinic.models import DoctorPatientRelationship

def can_view_whatsapp(user, doctor):
    if not hasattr(user, 'user_id'): 
        return False
    return DoctorPatientRelationship.objects.filter(
        user=user,
        doctor=doctor,
        status='active'
    ).exists()
