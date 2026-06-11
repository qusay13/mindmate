import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/app_models.dart';

class DoctorsNotifier extends StateNotifier<AsyncValue<List<DoctorModel>>> {
  final ApiClient _apiClient;
  List<DoctorModel> _allDoctors = [];

  DoctorsNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchDoctors();
  }

  Future<void> fetchDoctors() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('/clinic/doctors/list/');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => DoctorModel.fromJson(item))
            .toList();
        _allDoctors = list;
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void searchAndFilter(String query, String? specialization) {
    if (state is! AsyncData) return;

    var filtered = _allDoctors;
    if (query.isNotEmpty) {
      filtered = filtered
          .where((doc) => doc.fullName.toLowerCase().contains(query.toLowerCase()) ||
              (doc.bio?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    }

    if (specialization != null && specialization != 'الكل') {
      filtered = filtered.where((doc) => doc.specialization == specialization).toList();
    }

    state = AsyncValue.data(filtered);
  }

  Future<bool> linkWithDoctor(String doctorId, {String requestType = 'user_selected'}) async {
    try {
      final response = await _apiClient.post(
        '/clinic/link/',
        data: {
          'doctor_id': doctorId,
          'request_type': requestType,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh doctor list to update status
        await fetchDoctors();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final doctorsProvider = StateNotifierProvider<DoctorsNotifier, AsyncValue<List<DoctorModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DoctorsNotifier(apiClient: apiClient);
});

class SuggestedDoctorNotifier extends StateNotifier<AsyncValue<DoctorModel?>> {
  final ApiClient _apiClient;

  SuggestedDoctorNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchSuggestion();
  }

  Future<void> fetchSuggestion() async {
    try {
      final response = await _apiClient.get('/clinic/suggest-doctor/');
      if (response.statusCode == 200 && response.data != null && response.data['suggestion'] != null) {
        state = AsyncValue.data(DoctorModel.fromJson(response.data['suggestion']));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }
}

final suggestedDoctorProvider = StateNotifierProvider<SuggestedDoctorNotifier, AsyncValue<DoctorModel?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SuggestedDoctorNotifier(apiClient: apiClient);
});

final linkedDoctorProvider = Provider<DoctorModel?>((ref) {
  final doctorsAsync = ref.watch(doctorsProvider);
  return doctorsAsync.maybeWhen(
    data: (doctors) {
      try {
        return doctors.firstWhere((doc) => doc.linkStatus == 'linked');
      } catch (_) {
        return null;
      }
    },
    orElse: () => null,
  );
});

