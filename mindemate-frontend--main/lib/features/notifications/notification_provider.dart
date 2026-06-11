import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/app_models.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? errorMessage;

  NotificationState({
    required this.notifications,
    required this.isLoading,
    this.errorMessage,
  });

  factory NotificationState.initial() => NotificationState(notifications: [], isLoading: false);

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiClient _apiClient;

  NotificationNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(NotificationState.initial()) {
    fetchNotifications();
    setupPushNotifications();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.get('/notifications/user/');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => NotificationModel.fromJson(item))
            .toList();
        state = state.copyWith(notifications: list, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiClient.post('/notifications/user/mark-read/');
      if (response.statusCode == 200) {
        // Optimistically set all to read
        final updated = state.notifications.map((n) {
          return NotificationModel(
            notificationId: n.notificationId,
            notificationUuid: n.notificationUuid,
            title: n.title,
            body: n.body,
            notificationType: n.notificationType,
            relatedEntityType: n.relatedEntityType,
            relatedEntityId: n.relatedEntityId,
            isRead: true,
            createdAt: n.createdAt,
          );
        }).toList();
        state = state.copyWith(notifications: updated);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteNotification(int notifId) async {
    try {
      final response = await _apiClient.delete('/notifications/user/$notifId/');
      if (response.statusCode == 200 || response.statusCode == 204) {
        final updated = state.notifications.where((n) => n.notificationId != notifId).toList();
        state = state.copyWith(notifications: updated);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setupPushNotifications() async {
    // Only configure FCM push subscriptions on Android and iOS
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null) {
          // Subscribe token to backend
          await _apiClient.post('/notifications/subscribe/', data: {
            'endpoint': token,
            'p256dh': 'fcm_token_placeholder',
            'auth': 'fcm_auth_placeholder',
          });
        }
      }
    } catch (_) {
      // Fail silently if Firebase is not fully configured in native runner files
    }
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationNotifier(apiClient: apiClient);
});

class NotificationPreferencesNotifier extends StateNotifier<AsyncValue<Map<String, bool>>> {
  final ApiClient _apiClient;

  NotificationPreferencesNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchPreferences();
  }

  Future<void> fetchPreferences() async {
    try {
      final response = await _apiClient.get('/notifications/preferences/');
      if (response.statusCode == 200) {
        final data = Map<String, bool>.from(response.data);
        state = AsyncValue.data(data);
      } else {
        state = const AsyncValue.data({'email_notifications': false, 'push_notifications': false});
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> updatePreference(String key, bool value) async {
    try {
      final currentData = state.value ?? {'email_notifications': false, 'push_notifications': false};
      // Optimistically update
      state = AsyncValue.data({...currentData, key: value});

      final response = await _apiClient.patch(
        '/notifications/preferences/',
        data: {key: value},
      );
      if (response.statusCode == 200) {
        final data = Map<String, bool>.from(response.data);
        state = AsyncValue.data(data);
        return true;
      }
      // Revert on failure
      state = AsyncValue.data(currentData);
      return false;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, AsyncValue<Map<String, bool>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationPreferencesNotifier(apiClient: apiClient);
});

