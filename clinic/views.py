from rest_framework import status, views, permissions, generics
from rest_framework.response import Response
from django.db import transaction
from django.utils import timezone
from .models import DoctorPatientRelationship, DoctorPatientRequest
from accounts.models import Doctor
from chat.models import Conversation
from .serializers import (
    DoctorApprovalSerializer, DoctorProfileLiteSerializer, 
    DoctorPatientLinkSerializer, DoctorContactSerializer, PatientSerializer,
    DoctorPatientRequestSerializer
)
from tracking.models import DailyMoodEntry, JournalEntry, JournalAnalysis, JournalSharingPermission
from tracking.serializers import DailyMoodSerializer, JournalEntrySerializer, JournalAnalysisSerializer
from accounts.authentication import CustomTokenAuthentication
from .services.doctor_service import can_view_whatsapp

class IsDoctorPermission(permissions.BasePermission):
    def has_permission(self, request, view):
        return hasattr(request.user, 'doctor_id') and request.user.status == 'approved'

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

class AdminDoctorListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsAdminPermission]
    serializer_class = DoctorProfileLiteSerializer

    def get_queryset(self):
        return Doctor.objects.all().order_by('-created_at')

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
            # Create a PENDING request
            request_obj = DoctorPatientRequest.objects.create(
                user=user,
                doctor=doctor,
                request_type=serializer.validated_data['request_type'],
                status='pending'
            )

        return Response({
            'message': 'Link request sent to the doctor. Please wait for approval.',
            'request_id': request_obj.request_id
        }, status=status.HTTP_201_CREATED)


class DoctorPatientListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsDoctorPermission]
    serializer_class = PatientSerializer

    def get_queryset(self):
        from accounts.models import User
        doctor = self.request.user
        relationships = DoctorPatientRelationship.objects.filter(doctor=doctor, status='active')
        patient_ids = relationships.values_list('user_id', flat=True)
        return User.objects.filter(user_id__in=patient_ids)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['doctor'] = self.request.user
        return context


class DoctorPatientDetailView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsDoctorPermission]

    def get(self, request, patient_id):
        from accounts.models import User
        try:
            patient = User.objects.get(user_id=patient_id)
            # Verify relationship
            if not DoctorPatientRelationship.objects.filter(doctor=request.user, user=patient, status='active').exists():
                return Response({'error': 'You are not linked to this patient.'}, status=status.HTTP_403_FORBIDDEN)
            
            serializer = PatientSerializer(patient, context={'doctor': request.user})
            return Response(serializer.data)
        except User.DoesNotExist:
            return Response({'error': 'Patient not found.'}, status=status.HTTP_404_NOT_FOUND)


class DoctorPatientMoodHistoryView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsDoctorPermission]
    serializer_class = DailyMoodSerializer

    def get_queryset(self):
        patient_id = self.kwargs['patient_id']
        # Verify relationship
        if not DoctorPatientRelationship.objects.filter(doctor=self.request.user, user_id=patient_id, status='active').exists():
            return DailyMoodEntry.objects.none()
        
        return DailyMoodEntry.objects.filter(user_id=patient_id).order_by('-recorded_date')[:30]


class DoctorPatientJournalHistoryView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsDoctorPermission]
    serializer_class = JournalEntrySerializer

    def get_queryset(self):
        patient_id = self.kwargs['patient_id']
        doctor = self.request.user
        
        # Verify relationship
        if not DoctorPatientRelationship.objects.filter(doctor=doctor, user_id=patient_id, status='active').exists():
            return JournalEntry.objects.none()
        
        # Check permissions
        try:
            perm = JournalSharingPermission.objects.get(user_id=patient_id, doctor=doctor)
            if not perm.share_full_journal:
                return JournalEntry.objects.none() # Or return only allowed ones? Usually all or none.
        except JournalSharingPermission.DoesNotExist:
            return JournalEntry.objects.none()

        return JournalEntry.objects.filter(user_id=patient_id).order_by('-entry_date')[:10]


class DoctorPatientAnalysisListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsDoctorPermission]
    serializer_class = JournalAnalysisSerializer

    def get_queryset(self):
        patient_id = self.kwargs['patient_id']
        doctor = self.request.user
        
        # Verify relationship
        if not DoctorPatientRelationship.objects.filter(doctor=doctor, user_id=patient_id, status='active').exists():
            return JournalAnalysis.objects.none()
        
        # Check permissions
        try:
            perm = JournalSharingPermission.objects.get(user_id=patient_id, doctor=doctor)
            if not perm.share_analysis_only and not perm.share_full_journal:
                return JournalAnalysis.objects.none()
        except JournalSharingPermission.DoesNotExist:
            return JournalAnalysis.objects.none()

        return JournalAnalysis.objects.filter(journal__user_id=patient_id).order_by('-analyzed_at')[:10]


class DoctorPatientRequestListView(generics.ListAPIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsDoctorPermission]
    serializer_class = DoctorPatientRequestSerializer

    def get_queryset(self):
        return DoctorPatientRequest.objects.filter(doctor=self.request.user, status='pending').order_by('-requested_at')


class DoctorRequestActionView(views.APIView):
    authentication_classes = [CustomTokenAuthentication]
    permission_classes = [IsDoctorPermission]

    def post(self, request, request_id):
        action = request.data.get('action') # 'accept' or 'reject'
        if action not in ['accept', 'reject']:
            return Response({'error': 'Invalid action. Use accept or reject.'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            req_obj = DoctorPatientRequest.objects.get(request_id=request_id, doctor=request.user, status='pending')
        except DoctorPatientRequest.DoesNotExist:
            return Response({'error': 'Request not found or already processed.'}, status=status.HTTP_404_NOT_FOUND)
        
        with transaction.atomic():
            if action == 'accept':
                req_obj.status = 'accepted'
                req_obj.responded_at = timezone.now()
                req_obj.save()
                
                # Create Relationship
                DoctorPatientRelationship.objects.create(
                    doctor=req_obj.doctor,
                    user=req_obj.user,
                    request=req_obj,
                    status='active'
                )
                
                # Create Conversation
                Conversation.objects.get_or_create(
                    patient=req_obj.user,
                    doctor=req_obj.doctor
                )
                
                return Response({'message': 'Request accepted successfully.'})
            else:
                req_obj.status = 'rejected'
                req_obj.responded_at = timezone.now()
                req_obj.save()
                return Response({'message': 'Request rejected.'})
