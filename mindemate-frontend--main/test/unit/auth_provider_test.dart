import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mindmate/core/network/api_client.dart';
import 'package:mindmate/core/storage/secure_storage_service.dart';
import 'package:mindmate/features/auth/auth_provider.dart';

class MockApiClient implements ApiClient {
  String? returnToken;
  bool shouldFail = false;
  dynamic mockResponseData;
  int mockResponseStatusCode = 200;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      if (shouldFail) {
        return Future.value(Response(requestOptions: RequestOptions(), statusCode: 400, data: null));
      }
      return Future.value(Response(requestOptions: RequestOptions(), statusCode: mockResponseStatusCode, data: mockResponseData));
    }
    if (invocation.memberName == #post) {
      if (shouldFail) {
        return Future.value(Response(requestOptions: RequestOptions(), statusCode: 400, data: null));
      }
      return Future.value(Response(requestOptions: RequestOptions(), statusCode: mockResponseStatusCode, data: mockResponseData));
    }
    return super.noSuchMethod(invocation);
  }
}

class MockSecureStorage implements SecureStorageService {
  String? mockToken = 'mock_jwt_token';

  @override
  Future<String?> getAccessToken() async => mockToken;

  @override
  Future<void> saveAccessToken(String token) async {
    mockToken = token;
  }

  @override
  Future<void> saveUserRole(String role) async {}

  @override
  Future<void> clearAll() async {
    mockToken = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthNotifier Tests', () {
    late MockApiClient mockApiClient;
    late MockSecureStorage mockSecureStorage;
    late ProviderContainer container;

    setUp(() {
      mockApiClient = MockApiClient();
      mockSecureStorage = MockSecureStorage();

      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApiClient),
          secureStorageServiceProvider.overrideWithValue(mockSecureStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial checkAuthStatus sets unauthenticated if no token is found', () async {
      mockSecureStorage.mockToken = null;
      
      final notifier = container.read(authProvider.notifier);
      await notifier.checkAuthStatus();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
    });

    test('login sets authenticated state and saves token on success', () async {
      mockApiClient.mockResponseData = {
        'token': 'real_jwt_token',
        'expires_at': '2026-06-06',
        'role': 'user',
        'user': {
          'user_id': 'user123',
          'email': 'user@test.com',
          'full_name': 'Test User',
          'is_active': true,
          'is_onboarded': true,
          'initial_survey_completed': true,
          'created_at': '2026-06-06',
        }
      };
      mockApiClient.mockResponseStatusCode = 200;

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.login('user@test.com', 'password123');

      expect(success, true);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.userId, 'user123');
      expect(mockSecureStorage.mockToken, 'real_jwt_token');
    });

    test('login sets error status on failure', () async {
      mockApiClient.shouldFail = true;

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.login('user@test.com', 'wrong');

      expect(success, false);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, isNotNull);
    });
  });
}
