import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/app_models.dart';
import 'progress_provider.dart';

class MoodNotifier extends StateNotifier<AsyncValue<MoodEntryModel?>> {
  final ApiClient _apiClient;
  final Ref _ref;

  MoodNotifier({required ApiClient apiClient, required Ref ref})
      : _apiClient = apiClient,
        _ref = ref,
        super(const AsyncValue.loading()) {
    fetchTodayMood();
  }

  Future<void> fetchTodayMood() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('/tracking/mood/');
      if (response.statusCode == 200) {
        state = AsyncValue.data(MoodEntryModel.fromJson(response.data));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      // 404 response on no mood logged today will fall here
      state = const AsyncValue.data(null);
    }
  }

  Future<bool> recordMood(int level, String reason) async {
    try {
      final response = await _apiClient.post(
        '/tracking/mood/',
        data: {
          'mood_level': level,
          'reason_note': reason,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final entry = MoodEntryModel.fromJson(response.data);
        state = AsyncValue.data(entry);
        // Refresh daily progress
        _ref.read(dailyProgressProvider.notifier).fetchProgress();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final moodProvider = StateNotifierProvider<MoodNotifier, AsyncValue<MoodEntryModel?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MoodNotifier(apiClient: apiClient, ref: ref);
});
