import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/app_models.dart';
import '../mood_tracking/progress_provider.dart';

class JournalNotifier extends StateNotifier<AsyncValue<JournalEntryModel?>> {
  final ApiClient _apiClient;
  final Ref _ref;

  JournalNotifier({required ApiClient apiClient, required Ref ref})
      : _apiClient = apiClient,
        _ref = ref,
        super(const AsyncValue.loading()) {
    fetchTodayJournal();
  }

  Future<void> fetchTodayJournal() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('/tracking/journal/');
      if (response.statusCode == 200) {
        state = AsyncValue.data(JournalEntryModel.fromJson(response.data));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  Future<bool> recordJournal(String content) async {
    try {
      final response = await _apiClient.post(
        '/tracking/journal/',
        data: {
          'content': content,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final entry = JournalEntryModel.fromJson(response.data);
        state = AsyncValue.data(entry);
        // Refresh daily progress and journal history
        _ref.read(dailyProgressProvider.notifier).fetchProgress();
        _ref.read(journalHistoryProvider.notifier).fetchHistory();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final journalProvider = StateNotifierProvider<JournalNotifier, AsyncValue<JournalEntryModel?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return JournalNotifier(apiClient: apiClient, ref: ref);
});

class JournalHistoryNotifier extends StateNotifier<AsyncValue<List<JournalEntryModel>>> {
  final ApiClient _apiClient;

  JournalHistoryNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      final response = await _apiClient.get('/tracking/journal/history/');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => JournalEntryModel.fromJson(item))
            .toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final journalHistoryProvider = StateNotifierProvider<JournalHistoryNotifier, AsyncValue<List<JournalEntryModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return JournalHistoryNotifier(apiClient: apiClient);
});
