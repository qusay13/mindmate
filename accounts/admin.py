from django.contrib import admin
from .models import User, Doctor, Admin as AdminModel, UserSession, AuthToken

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['email', 'full_name', 'is_active', 'is_onboarded', 'created_at']
    list_filter = ['is_active', 'is_onboarded', 'created_at']
    search_fields = ['email', 'full_name']

@admin.register(Doctor)
class DoctorAdmin(admin.ModelAdmin):
    list_display = ['full_name', 'email', 'status', 'specialization', 'created_at']
    list_filter = ['status', 'created_at']
    search_fields = ['email', 'full_name']

@admin.register(AdminModel)
class AdminUserAdmin(admin.ModelAdmin):
    list_display = ['email', 'full_name', 'created_at']
    search_fields = ['email', 'full_name']

@admin.register(UserSession)
class UserSessionAdmin(admin.ModelAdmin):
    list_display = ['session_id', 'user', 'doctor', 'admin', 'expires_at']
    list_filter = ['expires_at']
    readonly_fields = ['session_id']

@admin.register(AuthToken)
class AuthTokenAdmin(admin.ModelAdmin):
    list_display = ['token_id', 'user', 'doctor', 'token_type', 'is_used', 'is_expired']
    list_filter = ['token_type', 'expires_at']
    readonly_fields = ['token_id']
