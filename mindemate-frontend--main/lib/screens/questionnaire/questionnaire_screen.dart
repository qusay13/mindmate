import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../main_scaffold.dart';
import '../../features/questionnaires/questionnaire_provider.dart';

class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  ConsumerState<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, dynamic> _answers = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final questionsState = ref.watch(onboardingQuestionsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.7),
        elevation: 0,
        centerTitle: true,
        leading: const SizedBox(),
        title: const Text(
          'MindMate - تقييم البداية',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: questionsState.when(
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(child: Text('لا توجد أسئلة متوفرة للاستبيان الأولي.'));
          }

          final currentQuestion = questions[_currentQuestionIndex];
          final totalQuestions = questions.length;

          // Initialize scale question with default value of 5.0
          if (currentQuestion.questionType == 'scale' && !_answers.containsKey(currentQuestion.questionId)) {
            _answers[currentQuestion.questionId] = 5.0;
          }

          final currentAnswer = _answers[currentQuestion.questionId];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الخطوة ${_currentQuestionIndex + 1} من $totalQuestions',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      'الرفاهية العاطفية',
                      style: TextStyle(
                        color: AppColors.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / totalQuestions,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  color: AppColors.primary,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 40),

                // Header
                const Text(
                  'كيف كان شعورك مؤخراً؟',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                const Text(
                  'خذ لحظة للتأمل... هذا يساعدنا في تخصيص رحلتك.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 40),

                // Question Text
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    currentQuestion.questionText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(height: 32),

                // Render Input based on question type
                if (currentQuestion.questionType == 'scale') ...[
                  Column(
                    children: [
                      Slider(
                        value: (currentAnswer as double? ?? 5.0),
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.surfaceContainerHigh,
                        label: (currentAnswer ?? 5.0).round().toString(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                setState(() {
                                  _answers[currentQuestion.questionId] = val;
                                });
                              },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('10', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                            Text(
                              'المحدد: ${(currentAnswer ?? 5.0).round()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            const Text('1', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  )
                ] else if (currentQuestion.questionType == 'text') ...[
                  TextField(
                    maxLines: 3,
                    enabled: !_isSubmitting,
                    onChanged: (val) {
                      _answers[currentQuestion.questionId] = val;
                    },
                    decoration: InputDecoration(
                      hintText: 'اكتب إجابتك هنا...',
                      hintTextDirection: TextDirection.rtl,
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                    ),
                  ),
                ] else ...[
                  ...currentQuestion.options.map((optText) {
                    final isSelected = currentAnswer == optText;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _answers[currentQuestion.questionId] = optText;
                                });
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Colors.white)
                              else
                                const Icon(Icons.circle_outlined, color: AppColors.outlineVariant),
                              Text(
                                optText,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppColors.onSurface,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 40),

                // Footer Navigation
                Row(
                  children: [
                    if (_currentQuestionIndex > 0)
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _currentQuestionIndex--;
                                });
                              },
                        child: const Text(
                          'السابق',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const MainScaffold()),
                                  (route) => false,
                                );
                              },
                        child: const Text(
                          'تخطى الآن',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    const Spacer(),
                    _isSubmitting
                        ? const CircularProgressIndicator(color: AppColors.primary)
                        : ElevatedButton(
                            onPressed: (currentAnswer == null || (currentAnswer is String && currentAnswer.trim().isEmpty))
                                ? null
                                : () async {
                                    if (_currentQuestionIndex < totalQuestions - 1) {
                                      setState(() {
                                        _currentQuestionIndex++;
                                      });
                                    } else {
                                      setState(() {
                                        _isSubmitting = true;
                                      });

                                      final List<Map<String, dynamic>> responsesList = [];
                                      for (var q in questions) {
                                        final ansVal = _answers[q.questionId];
                                        final isScale = q.questionType == 'scale';
                                        responsesList.add({
                                          'question_id': q.questionId,
                                          'answer_text': ansVal?.toString() ?? '',
                                          'answer_value': isScale ? (ansVal as double? ?? 5.0) : null,
                                        });
                                      }

                                      final success = await ref
                                          .read(onboardingSurveySubmissionProvider.notifier)
                                          .submit(responses: responsesList);

                                      if (!context.mounted) return;
                                      setState(() {
                                        _isSubmitting = false;
                                      });

                                      if (success) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (context) => const MainScaffold()),
                                          (route) => false,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('فشل حفظ التقييم الأولي. يرجى المحاولة لاحقاً', textAlign: TextAlign.right),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _currentQuestionIndex == totalQuestions - 1 ? 'إنهاء وتأسيس' : 'استمرار',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_back),
                              ],
                            ),
                          ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('حدث خطأ أثناء تحميل الاستبيان: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(onboardingQuestionsProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
