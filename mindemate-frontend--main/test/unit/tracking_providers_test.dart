import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mindmate/core/network/api_client.dart';
import 'package:mindmate/features/mood_tracking/mood_provider.dart';
import 'package:mindmate/features/mood_tracking/progress_provider.dart';

class MockApiClient implements ApiClient {
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

void main() {
  group('Tracking Providers Unit Tests', () {
    late MockApiClient mockApiClient;
    late ProviderContainer container;

    setUp(() {
      mockApiClient = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApiClient),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('MoodNotifier.fetchTodayMood sets state to data on 200 response', () async {
      mockApiClient.mockResponseData = {
        'mood_id': 12,
        'mood_level': 5,
        'mood_label': 'Very Good',
        'reason_note': 'Successful testing',
        'recorded_date': '2026-06-06',
        'created_at': '2026-06-06T12:00:00Z',
      };
      mockApiClient.mockResponseStatusCode = 200;

      final moodNotifier = container.read(moodProvider.notifier);
      await moodNotifier.fetchTodayMood();

      final moodState = container.read(moodProvider);
      expect(moodState.value?.moodId, '12');
      expect(moodState.value?.moodLevel, 5);
      expect(moodState.value?.moodLabel, 'Very Good');
    });

    test('DailyProgressNotifier.fetchProgress fetches daily progress model', () async {
      mockApiClient.mockResponseData = {
        'progress_id': 100,
        'progress_date': '2026-06-06',
        'completion': 33,
        'missing': ['journal', 'questionnaire'],
        'completed': ['mood'],
        'streak': 2,
        'mood_completed': true,
        'phq9_completed': false,
        'gad7_completed': false,
        'pss10_completed': false,
        'questionnaire_completed': false,
        'journal_completed': false,
        'all_completed': false,
        'tip_shown': false,
      };
      mockApiClient.mockResponseStatusCode = 200;

      final progressNotifier = container.read(dailyProgressProvider.notifier);
      await progressNotifier.fetchProgress();

      final progressState = container.read(dailyProgressProvider);
      expect(progressState.value?.progressId, '100');
      expect(progressState.value?.moodCompleted, true);
      expect(progressState.value?.completion, 33);
      expect(progressState.value?.streak, 2);
    });

    test('DailyTipNotifier.fetchDailyTip parses daily tip on success', () async {
      mockApiClient.mockResponseData = {
        'content': 'Stay active and hydrated!',
        'category': 'Self-care',
      };
      mockApiClient.mockResponseStatusCode = 200;

      final tipNotifier = container.read(dailyTipProvider.notifier);
      await tipNotifier.fetchDailyTip();

      final tipState = container.read(dailyTipProvider);
      expect(tipState.value?['content'], 'Stay active and hydrated!');
      expect(tipState.value?['category'], 'Self-care');
    });
  });
}
