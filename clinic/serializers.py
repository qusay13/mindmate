from rest_framework import serializers
from accounts.models import Doctor
from .models import DoctorPatientRequest, DoctorPatientRelationship
from .services.doctor_service import can_view_whatsapp

class DoctorApprovalSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=['approved', 'rejected'])
    rejection_reason = serializers.CharField(required=False, allow_blank=True)

class DoctorProfileLiteSerializer(serializers.ModelSerializer):
    whatsapp_number = serializers.SerializerMethodField()
    
    class Meta:
        model = Doctor
        fields = [
            'doctor_id', 'full_name', 'specialization', 'nationality', 
            'bio', 'profile_image', 'whatsapp_number', 'is_whatsapp_visible'
        ]

    def get_whatsapp_number(self, obj):
        # Privacy Control
        request = self.context.get('request')
        if not request or not hasattr(request, 'user'):
            return None
            
        user = request.user
        
        # Admin or same doctor can see
        if hasattr(user, 'admin_id') or (hasattr(user, 'doctor_id') and user.doctor_id == obj.doctor_id):
            return obj.whatsapp_number
            
        if not obj.is_whatsapp_visible:
            return None
            
        if can_view_whatsapp(user, obj):
            # Mask it for profile listing, user must call contact/ to get full
            if obj.whatsapp_number and len(obj.whatsapp_number) > 6:
                return obj.whatsapp_number[:4] + "****" + obj.whatsapp_number[-3:]
            return "***"
        return None

class DoctorContactSerializer(serializers.Serializer):
    whatsapp_link = serializers.SerializerMethodField()
    whatsapp_number = serializers.SerializerMethodField()
    
    def get_whatsapp_link(self, obj):
        if not obj.whatsapp_number:
            return None
        clean_num = obj.whatsapp_number.replace('+', '').replace(' ', '')
        return f"https://wa.me/{clean_num}"
        
    def get_whatsapp_number(self, obj):
        return obj.whatsapp_number

class DoctorPatientLinkSerializer(serializers.Serializer):
    doctor_id = serializers.UUIDField(required=True)
    request_type = serializers.ChoiceField(choices=['system_suggested', 'user_selected'], default='user_selected')
