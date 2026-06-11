import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/models/app_models.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/network/api_client.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  AuthNotifier({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage,
        super(AuthState.initial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _secureStorage.getAccessToken();
      if (!mounted) return;
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      // Fetch user profile to verify token validity
      final response = await _apiClient.get('/accounts/profile/user/');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        await _secureStorage.clearAll();
        if (!mounted) return;
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _secureStorage.clearAll();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      } else {
        // Do not clear storage on network errors or transient issues.
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'لم نتمكن من الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.',
        );
      }
    } catch (e) {
      await _secureStorage.clearAll();
      if (!mounted) return;
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _apiClient.post(
        '/accounts/login/',
        data: {
          'email': email,
          'password': password,
          'role': 'user', // Patient-only mobile app
        },
      );
      if (!mounted) return false;

      if (response.statusCode == 200) {
        final authResponse = AuthResponseModel.fromJson(response.data);
        await _secureStorage.saveAccessToken(authResponse.token);
        await _secureStorage.saveUserRole(authResponse.role);
        if (!mounted) return true;
        
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: authResponse.user,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'فشل تسجيل الدخول. يرجى التحقق من البيانات.',
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'حدث خطأ أثناء الاتصال بالخادم. يرجى التحقق من بريدك وإدخالاتك.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phoneNumber,
    required String nationality,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _apiClient.post(
        '/accounts/register/user/',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'date_of_birth': dateOfBirth,
          'gender': gender,
          'phone_number': phoneNumber,
          'nationality': nationality,
        },
      );
      if (!mounted) return false;

      if (response.statusCode == 201) {
        // Automatically login the user upon registration
        return await login(email, password);
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'فشل إنشاء الحساب.',
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'حدث خطأ أثناء إنشاء الحساب. تأكد من إدخال كافة البيانات بشكل صحيح.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/accounts/logout/');
    } catch (_) {
      // Ignore errors on logout
    } finally {
      await _secureStorage.clearAll();
      if (mounted) {
        state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
      }
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phoneNumber,
    required String nationality,
    XFile? profileImage,
  }) async {
    try {
      final Map<String, dynamic> dataMap = {
        'full_name': fullName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'phone_number': phoneNumber,
        'nationality': nationality,
      };

      if (profileImage != null) {
        dataMap['profile_image'] = await MultipartFile.fromFile(
          profileImage.path,
          filename: profileImage.name,
        );
      }

      final formData = FormData.fromMap(dataMap);

      final response = await _apiClient.patch(
        '/accounts/profile/user/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        state = state.copyWith(user: user);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AuthNotifier(apiClient: apiClient, secureStorage: secureStorage);
});
