from django.urls import path
from .views import (
    UserNotificationListView,
    UserNotificationMarkReadView,
    UserNotificationDeleteView,
    DoctorNotificationListView,
    DoctorNotificationMarkReadView,
    DoctorNotificationDeleteView,
)

urlpatterns = [
    # ── User Notifications ──────────────────────────────────
    path('user/',                          UserNotificationListView.as_view(),      name='user-notifications-list'),
    path('user/mark-read/',                UserNotificationMarkReadView.as_view(),  name='user-notifications-mark-read'),
    path('user/<int:notification_id>/',    UserNotificationDeleteView.as_view(),    name='user-notification-delete'),

    # ── Doctor Notifications ─────────────────────────────────
    path('doctor/',                        DoctorNotificationListView.as_view(),    name='doctor-notifications-list'),
    path('doctor/mark-read/',              DoctorNotificationMarkReadView.as_view(),name='doctor-notifications-mark-read'),
    path('doctor/<int:notification_id>/',  DoctorNotificationDeleteView.as_view(),  name='doctor-notification-delete'),
]
