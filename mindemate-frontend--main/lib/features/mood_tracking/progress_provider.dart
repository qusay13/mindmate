import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class DailyProgressModel {
  final String progressId;
  final String progressDate;
  final int completion;
  final List<String> missing;
  final List<String> completed;
  final int streak;
  final bool moodCompleted;
  final bool phq9Completed;
  final bool gad7Completed;
  final bool pss10Completed;
  final bool questionnaireCompleted;
  final bool journalCompleted;
  final bool allCompleted;
  final bool tipShown;

  DailyProgressModel({
    required this.progressId,
    required this.progressDate,
    required this.completion,
    required this.missing,
    required this.completed,
    required this.streak,
    required this.moodCompleted,
    required this.phq9Completed,
    required this.gad7Completed,
    required this.pss10Completed,
    required this.questionnaireCompleted,
    required this.journalCompleted,
    required this.allCompleted,
    required this.tipShown,
  });

  factory DailyProgressModel.fromJson(Map<String, dynamic> json) {
    return DailyProgressModel(
      progressId: json['progress_id']?.toString() ?? '',
      progressDate: json['progress_date'] ?? '',
      completion: json['completion'] ?? 0,
      missing: List<String>.from(json['missing'] ?? []),
      completed: List<String>.from(json['completed'] ?? []),
      streak: json['streak'] ?? 0,
      moodCompleted: json['mood_completed'] ?? false,
      phq9Completed: json['phq9_completed'] ?? false,
      gad7Completed: json['gad7_completed'] ?? false,
      pss10Completed: json['pss10_completed'] ?? false,
      questionnaireCompleted: json['questionnaire_completed'] ?? false,
      journalCompleted: json['journal_completed'] ?? false,
      allCompleted: json['all_completed'] ?? false,
      tipShown: json['tip_shown'] ?? false,
    );
  }
}

class DailyProgressNotifier extends StateNotifier<AsyncValue<DailyProgressModel?>> {
  final ApiClient _apiClient;

  DailyProgressNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchProgress();
  }

  Future<void> fetchProgress() async {
    try {
      final response = await _apiClient.get('/tracking/progress/');
      if (response.statusCode == 200) {
        state = AsyncValue.data(DailyProgressModel.fromJson(response.data));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final dailyProgressProvider = StateNotifierProvider<DailyProgressNotifier, AsyncValue<DailyProgressModel?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DailyProgressNotifier(apiClient: apiClient);
});

class DailyTipNotifier extends StateNotifier<AsyncValue<Map<String, String>?>> {
  final ApiClient _apiClient;

  DailyTipNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchDailyTip();
  }

  Future<void> fetchDailyTip() async {
    try {
      final response = await _apiClient.get('/tracking/daily-tip/');
      if (response.statusCode == 200) {
        state = AsyncValue.data({
          'content': response.data['content']?.toString() ?? '',
          'category': response.data['category']?.toString() ?? '',
        });
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }
}

final dailyTipProvider = StateNotifierProvider<DailyTipNotifier, AsyncValue<Map<String, String>?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DailyTipNotifier(apiClient: apiClient);
});
