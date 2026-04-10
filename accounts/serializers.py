from rest_framework import serializers
from .models import User, Doctor, Admin

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'user_id', 'email', 'full_name', 'date_of_birth', 'gender', 
            'phone_number', 'nationality', 'profile_image', 'is_active', 
            'is_onboarded', 'initial_survey_completed', 'created_at'
        ]
        read_only_fields = ['user_id', 'created_at', 'is_active']

class DoctorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Doctor
        fields = [
            'doctor_id', 'email', 'full_name', 'nationality', 'specialization',
            'bio', 'profile_image', 'cv_file_path', 'status', 'is_active', 
            'created_at'
        ]
        read_only_fields = ['doctor_id', 'status', 'is_active', 'created_at']

class AdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = Admin
        fields = ['admin_id', 'email', 'full_name', 'created_at']
        read_only_fields = ['admin_id', 'created_at']

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'})

    class Meta:
        model = User
        fields = ['email', 'password', 'full_name', 'date_of_birth', 'gender', 'phone_number', 'nationality']

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user

class DoctorRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'})

    class Meta:
        model = Doctor
        fields = ['email', 'password', 'full_name', 'nationality', 'specialization', 'bio', 'profile_image', 'cv_file_path']

    def create(self, validated_data):
        password = validated_data.pop('password')
        doctor = Doctor(**validated_data)
        doctor.set_password(password)
        # Doctor status is 'pending' by default from model definition
        doctor.save()
        return doctor

class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(required=True, style={'input_type': 'password'})
    role = serializers.ChoiceField(choices=['user', 'doctor', 'admin'], required=True)
