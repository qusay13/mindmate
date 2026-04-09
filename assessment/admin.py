from django.contrib import admin
from .models import Assessment, TipAndRecommendation, UserDailyTip

@admin.register(Assessment)
class AssessmentAdmin(admin.ModelAdmin):
    list_display = ['user', 'assessment_type', 'overall_severity', 'is_critical', 'created_from_days', 'assessed_at']
    list_filter = ['assessment_type', 'overall_severity', 'is_critical', 'assessed_at']
    search_fields = ['user__email', 'dominant_condition']
    readonly_fields = ['assessed_at']

@admin.register(TipAndRecommendation)
class TipAndRecommendationAdmin(admin.ModelAdmin):
    list_display = ['tip_type', 'category', 'content', 'severity_target', 'is_active']
    list_filter = ['tip_type', 'category', 'severity_target', 'is_active']
    search_fields = ['content']

@admin.register(UserDailyTip)
class UserDailyTipAdmin(admin.ModelAdmin):
    list_display = ['user', 'tip', 'shown_date']
    list_filter = ['shown_date']
    search_fields = ['user__email']
