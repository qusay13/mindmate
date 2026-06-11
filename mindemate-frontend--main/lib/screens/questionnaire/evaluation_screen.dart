import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../features/questionnaires/questionnaire_provider.dart';
import '../../shared/models/app_models.dart';
import '../../core/network/api_client.dart';

class EvaluationScreen extends ConsumerStatefulWidget {
  const EvaluationScreen({super.key});

  @override
  ConsumerState<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends ConsumerState<EvaluationScreen> {
  QuestionnaireModel? _selectedType;
  int _currentQuestionIndex = 0;
  final Map<int, QuestionOption> _answers = {}; // questionId -> selectedOption
  bool _isSubmitted = false;
  QuestionnaireResultModel? _result;
  bool _isLinkingDoctor = false;

  @override
  Widget build(BuildContext context) {
    final typesState = ref.watch(questionnaireTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'التقييم الذاتي',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: typesState.when(
        data: (types) {
          if (types.isEmpty) {
            return const Center(child: Text('لا توجد استبيانات متاحة حالياً.'));
          }

          if (_selectedType == null) {
            return _buildTypeSelectionScreen(types);
          }

          if (_isSubmitted && _result != null) {
            return _buildResultScreen();
          }

          return _buildQuestionsFlowScreen();
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('حدث خطأ أثناء تحميل الاستبيانات: $err')),
      ),
    );
  }

  Widget _buildTypeSelectionScreen(List<QuestionnaireModel> types) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اختر التقييم المناسب',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          const Text(
            'اختر أحد الاختبارات النفسية المعتمدة علمياً لمتابعة حالتك ومستوى تقدمك.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                        _currentQuestionIndex = 0;
                        _answers.clear();
                        _isSubmitted = false;
                        _result = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            type.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  type.code,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Text(
                                'الدرجة القصوى: ${type.maxScore}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsFlowScreen() {
    final questionsState = ref.watch(questionnaireQuestionsProvider(_selectedType!.code));

    return questionsState.when(
      data: (questions) {
        if (questions.isEmpty) {
          return const Center(child: Text('لا توجد أسئلة متوفرة لهذا الاستبيان.'));
        }

        final currentQuestion = questions[_currentQuestionIndex];
        final totalQuestions = questions.length;
        final selectedOption = _answers[currentQuestion.questionId];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Tracker Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'السؤال ${_currentQuestionIndex + 1} من $totalQuestions',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          _selectedType!.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / totalQuestions,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      color: AppColors.primary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Question Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: const Border(right: BorderSide(color: AppColors.primary, width: 4)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 5))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      currentQuestion.questionText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 24),
                    ...currentQuestion.options.map((opt) {
                      final isSelected = selectedOption?.score == opt.score;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _answers[currentQuestion.questionId] = opt;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.white)
                                else
                                  const Icon(Icons.circle_outlined, color: AppColors.outlineVariant),
                                Text(
                                  opt.text,
                                  style: TextStyle(
                                    fontSize: 15,
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
                ),
              ),
              const SizedBox(height: 32),

              // Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentQuestionIndex > 0)
                    TextButton(
                      onPressed: () {
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
                    const SizedBox.shrink(),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: selectedOption == null
                        ? null
                        : () async {
                            if (_currentQuestionIndex < totalQuestions - 1) {
                              setState(() {
                                _currentQuestionIndex++;
                              });
                            } else {
                              // Submit answers
                              final formattedAnswers = _answers.entries.map((e) {
                                final questionId = e.key;
                                final selectedOption = e.value;
                                final question = questions.firstWhere((q) => q.questionId == questionId);
                                final optionIndex = question.options.indexWhere(
                                  (opt) => opt.score == selectedOption.score && opt.text == selectedOption.text,
                                );
                                return {
                                  'question_id': questionId,
                                  'selected_option': optionIndex >= 0 ? optionIndex : 0,
                                  'score': selectedOption.score,
                                };
                              }).toList();

                              final submissionNotifier = ref.read(questionnaireSubmissionProvider.notifier);
                              final res = await submissionNotifier.submit(
                                code: _selectedType!.code,
                                answers: formattedAnswers,
                              );

                              if (!mounted) return;

                              if (res != null) {
                                setState(() {
                                  _result = res;
                                  _isSubmitted = true;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('حدث خطأ أثناء إرسال التقييم. ربما قمت بحله مسبقاً اليوم.', textAlign: TextAlign.right),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _currentQuestionIndex == totalQuestions - 1 ? 'إرسال التقييم' : 'استمرار',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_back, size: 16),
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
      error: (err, stack) => Center(child: Text('حدث خطأ أثناء تحميل الأسئلة: $err')),
    );
  }

  Widget _buildResultScreen() {
    final suggestedDoctor = _result!.suggestedDoctor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Outcome
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics_outlined, size: 60, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'نتيجة تقييمك الذاتي',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Total Score and Severity Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'الدرجة الكلية الكلية للتقييم',
                  style: TextStyle(fontSize: 14, color: AppColors.outline),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_result!.totalScore}',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'مستوى شدة الحالة المقدر',
                  style: TextStyle(fontSize: 14, color: AppColors.outline),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _result!.severityLevel == 'mild'
                        ? 'خفيف / Mild'
                        : _result!.severityLevel == 'moderate'
                            ? 'متوسط / Moderate'
                            : _result!.severityLevel == 'severe'
                                ? 'شديد / Severe'
                                : _result!.severityLevel == 'minimal'
                                    ? 'أدنى حد / Minimal'
                                    : _result!.severityLevel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onError,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Suggested Doctor Recommendation
          if (suggestedDoctor != null) ...[
            const Text(
              'طبيب مقترح لحالتك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'د. ${suggestedDoctor.fullName}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            suggestedDoctor.specialization,
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        child: const Icon(Icons.person, size: 32, color: AppColors.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    suggestedDoctor.bio ?? 'متخصص متميز في مساعدة المرضى بالتعافي التدريجي النفسي.',
                    style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 20),
                  _isLinkingDoctor
                      ? const CircularProgressIndicator(color: AppColors.secondary)
                      : PrimaryButton(
                          text: 'طلب ارتباط مع الطبيب المقترح',
                          icon: Icons.link,
                          onPressed: () async {
                            setState(() {
                              _isLinkingDoctor = true;
                            });
                            try {
                              final apiClient = ref.read(apiClientProvider);
                              final response = await apiClient.post(
                                '/clinic/link/',
                                data: {
                                  'doctor_id': suggestedDoctor.doctorId,
                                  'request_type': 'system_suggested',
                                },
                              );
                              if (!mounted) return;
                              if (response.statusCode == 200 || response.statusCode == 201) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم إرسال طلب الارتباط للطبيب بنجاح', textAlign: TextAlign.right),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('فشل إرسال الطلب. ربما أرسلته مسبقاً.', textAlign: TextAlign.right),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLinkingDoctor = false;
                                });
                              }
                            }
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          PrimaryButton(
            text: 'العودة للرئيسية',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
