import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/app_models.dart';

class AnalysisNotifier extends StateNotifier<AsyncValue<AnalysisReportModel?>> {
  final ApiClient _apiClient;

  AnalysisNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchAnalysis();
  }

  Future<void> fetchAnalysis() async {
    try {
      final response = await _apiClient.get('/tracking/analysis/');
      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic> && response.data.containsKey('detail')) {
          state = const AsyncValue.data(null);
        } else {
          state = AsyncValue.data(AnalysisReportModel.fromJson(response.data));
        }
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final analysisProvider = StateNotifierProvider<AnalysisNotifier, AsyncValue<AnalysisReportModel?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnalysisNotifier(apiClient: apiClient);
});
