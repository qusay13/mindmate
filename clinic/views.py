from rest_framework import status, views, permissions, generics
from rest_framework.response import Response
from django.db import transaction
from django.utils import timezone
from .models import DoctorPatientRelationship, DoctorPatientRequest
from accounts.models import Doctor
from .serializers import (
    DoctorApprovalSerializer, DoctorProfileLiteSerializer, 
    DoctorPatientLinkSerializer, DoctorContactSerializer
)
from accounts.authentication import CustomTokenAuthentication
from .services.doctor_service import can_view_whatsapp

class IsAdminPermission(permissions.BasePermission):
    def has_permission(self, request, view):
        return hasattr(request.user, 'admin_id')

class AdminApproveDoctorView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsAdminPermission]

    def patch(self, request, doctor_id):
        try:
            doctor = Doctor.objects.get(pk=doctor_id)
        except Doctor.DoesNotExist:
            return Response({'error': 'Doctor not found'}, status=status.HTTP_404_NOT_FOUND)
            
        serializer = DoctorApprovalSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        doctor.status = serializer.validated_data['status']
        if doctor.status == 'approved':
            doctor.approved_at = timezone.now()
        else:
            doctor.rejection_reason = serializer.validated_data.get('rejection_reason', '')
            
        doctor.save()
        return Response({'message': f'Doctor {doctor.status} successfully'}, status=status.HTTP_200_OK)

class DoctorListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = DoctorProfileLiteSerializer

    def get_queryset(self):
        return Doctor.objects.filter(status='approved', is_active=True)

class DoctorDetailView(generics.RetrieveAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = DoctorProfileLiteSerializer
    queryset = Doctor.objects.filter(status='approved', is_active=True)
    lookup_field = 'pk'
    lookup_url_kwarg = 'doctor_id'

class DoctorContactView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, doctor_id):
        try:
            doctor = Doctor.objects.get(pk=doctor_id, status='approved', is_active=True)
        except Doctor.DoesNotExist:
            return Response({'error': 'Doctor not found'}, status=status.HTTP_404_NOT_FOUND)
            
        user = request.user
        
        # Privacy guard
        if not hasattr(user, 'user_id'):
            return Response({'error': 'Only patients can request contact info'}, status=status.HTTP_403_FORBIDDEN)
            
        if not can_view_whatsapp(user, doctor):
            return Response({'error': 'Unauthorized. You must link with this doctor first.'}, status=status.HTTP_403_FORBIDDEN)
            
        if not doctor.is_whatsapp_visible or not doctor.whatsapp_number:
            return Response({'error': 'WhatsApp contact is currently unavailable for this doctor.'}, status=status.HTTP_404_NOT_FOUND)
            
        serializer = DoctorContactSerializer(doctor)
        return Response(serializer.data, status=status.HTTP_200_OK)

class PatientDoctorLinkView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = DoctorPatientLinkSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        if not hasattr(user, 'user_id'):
            return Response({'error': 'Only patients can link to a doctor.'}, status=status.HTTP_403_FORBIDDEN)
            
        try:
            doctor = Doctor.objects.get(pk=serializer.validated_data['doctor_id'], status='approved', is_active=True)
        except Doctor.DoesNotExist:
            return Response({'error': 'Doctor not found or unavailable'}, status=status.HTTP_404_NOT_FOUND)
            
        # Check duplicate directly
        if DoctorPatientRelationship.objects.filter(user=user, doctor=doctor).exists():
            return Response({'error': 'You are already linked to this doctor.'}, status=status.HTTP_400_BAD_REQUEST)
            
        with transaction.atomic():
            request_obj = DoctorPatientRequest.objects.create(
                user=user,
                doctor=doctor,
                request_type=serializer.validated_data['request_type'],
                status='accepted',
                responded_at=timezone.now()
            )
            
            DoctorPatientRelationship.objects.create(
                doctor=doctor,
                user=user,
                request=request_obj,
                status='active'
            )
            
        return Response({'message': 'Linked with doctor successfully!'}, status=status.HTTP_201_CREATED)
