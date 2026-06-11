import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/app_models.dart';
import '../mood_tracking/progress_provider.dart';
import '../auth/auth_provider.dart';


class QuestionnaireNotifier extends StateNotifier<AsyncValue<List<QuestionnaireModel>>> {
  final ApiClient _apiClient;

  QuestionnaireNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchTypes();
  }

  Future<void> fetchTypes() async {
    try {
      final response = await _apiClient.get('/tracking/questionnaires/');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => QuestionnaireModel.fromJson(item))
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

final questionnaireTypesProvider = StateNotifierProvider<QuestionnaireNotifier, AsyncValue<List<QuestionnaireModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return QuestionnaireNotifier(apiClient: apiClient);
});

class QuestionnaireQuestionsNotifier extends StateNotifier<AsyncValue<List<QuestionnaireQuestionModel>>> {
  final ApiClient _apiClient;
  final String _code;

  QuestionnaireQuestionsNotifier({required ApiClient apiClient, required String code})
      : _apiClient = apiClient,
        _code = code,
        super(const AsyncValue.loading()) {
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    try {
      final response = await _apiClient.get('/tracking/questionnaires/$_code/questions/');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => QuestionnaireQuestionModel.fromJson(item))
            .toList();
        // Sort questions by order
        list.sort((a, b) => a.questionOrder.compareTo(b.questionOrder));
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final questionnaireQuestionsProvider = StateNotifierProvider.family<
    QuestionnaireQuestionsNotifier,
    AsyncValue<List<QuestionnaireQuestionModel>>,
    String>((ref, code) {
  final apiClient = ref.watch(apiClientProvider);
  return QuestionnaireQuestionsNotifier(apiClient: apiClient, code: code);
});

class QuestionnaireSubmissionNotifier extends StateNotifier<AsyncValue<QuestionnaireResultModel?>> {
  final ApiClient _apiClient;
  final Ref _ref;

  QuestionnaireSubmissionNotifier({required ApiClient apiClient, required Ref ref})
      : _apiClient = apiClient,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<QuestionnaireResultModel?> submit({
    required String code,
    required List<Map<String, dynamic>> answers,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.post(
        '/tracking/questionnaires/submit/',
        data: {
          'questionnaire_code': code,
          'answers': answers,
        },
      );
      if (response.statusCode == 201) {
        final result = QuestionnaireResultModel.fromJson(response.data);
        state = AsyncValue.data(result);
        
        // Refresh daily progress and daily tip
        _ref.read(dailyProgressProvider.notifier).fetchProgress();
        _ref.read(dailyTipProvider.notifier).fetchDailyTip();
        return result;
      } else {
        state = const AsyncValue.data(null);
        return null;
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }
}

final questionnaireSubmissionProvider = StateNotifierProvider<
    QuestionnaireSubmissionNotifier, AsyncValue<QuestionnaireResultModel?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return QuestionnaireSubmissionNotifier(apiClient: apiClient, ref: ref);
});

class OnboardingQuestionsNotifier extends StateNotifier<AsyncValue<List<SurveyQuestionModel>>> {
  final ApiClient _apiClient;

  OnboardingQuestionsNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    try {
      final response = await _apiClient.get('/survey/questions/');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => SurveyQuestionModel.fromJson(item))
            .toList();
        list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final onboardingQuestionsProvider = StateNotifierProvider<
    OnboardingQuestionsNotifier, AsyncValue<List<SurveyQuestionModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OnboardingQuestionsNotifier(apiClient: apiClient);
});

class OnboardingSurveySubmissionNotifier extends StateNotifier<AsyncValue<bool>> {
  final ApiClient _apiClient;
  final Ref _ref;

  OnboardingSurveySubmissionNotifier({required ApiClient apiClient, required Ref ref})
      : _apiClient = apiClient,
        _ref = ref,
        super(const AsyncValue.data(false));

  Future<bool> submit({
    required List<Map<String, dynamic>> responses,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.post(
        '/survey/submit/',
        data: {
          'responses': responses,
        },
      );
      if (response.statusCode == 201) {
        state = const AsyncValue.data(true);
        // Refresh profile / auth state so user is marked as onboarded
        await _ref.read(authProvider.notifier).checkAuthStatus();
        return true;
      } else {
        state = const AsyncValue.data(false);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

final onboardingSurveySubmissionProvider = StateNotifierProvider<
    OnboardingSurveySubmissionNotifier, AsyncValue<bool>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OnboardingSurveySubmissionNotifier(apiClient: apiClient, ref: ref);
});
