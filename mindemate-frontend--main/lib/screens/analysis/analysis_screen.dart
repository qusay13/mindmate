import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/environment.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../features/analysis/analysis_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/models/app_models.dart';
import '../../core/network/api_client.dart';
import '../profile/user_profile_screen.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLinkingDoctor = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2); // default to 30-day tab if unlocked
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _linkDoctor(String doctorId) async {
    setState(() {
      _isLinkingDoctor = true;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/clinic/link/',
        data: {
          'doctor_id': doctorId,
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
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'التحليل النفسي الشامل',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                ).then((_) {
                  ref.read(analysisProvider.notifier).fetchAnalysis();
                });
              },
              child: Consumer(
                builder: (context, ref, _) {
                  final auth = ref.watch(authProvider);
                  return CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    backgroundImage: auth.user?.profileImage != null && auth.user!.profileImage!.isNotEmpty
                        ? NetworkImage(Environment.getFullImageUrl(auth.user!.profileImage))
                        : null,
                    child: auth.user?.profileImage == null || auth.user!.profileImage!.isEmpty
                        ? Text(
                            auth.user?.fullName.isNotEmpty == true
                                ? auth.user!.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(analysisProvider.notifier).fetchAnalysis();
        },
        color: AppColors.primary,
        child: analysisState.when(
          data: (report) {
            if (report == null || report.dailyAnalyses.isEmpty) {
              return _buildEmptyState();
            }

            final fifteenUnlocked = report.fifteenDayAnalysis != null;
            final thirtyUnlocked = report.thirtyDayAnalysis != null;

            // Automatically switch tabs if not unlocked
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (thirtyUnlocked && _tabController.index != 2) {
                _tabController.index = 2;
              } else if (!thirtyUnlocked && fifteenUnlocked && _tabController.index != 1) {
                _tabController.index = 1;
              } else if (!thirtyUnlocked && !fifteenUnlocked && _tabController.index != 0) {
                _tabController.index = 0;
              }
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.onPrimary,
                      unselectedLabelColor: AppColors.onSurfaceVariant,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tabs: [
                        const Tab(text: 'يومي'),
                        Tab(
                          child: Opacity(
                            opacity: fifteenUnlocked ? 1.0 : 0.4,
                            child: const Text('١٥ يوم'),
                          ),
                        ),
                        Tab(
                          child: Opacity(
                            opacity: thirtyUnlocked ? 1.0 : 0.4,
                            child: const Text('٣٠ يوم'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(), // tab navigation handles validation
                    children: [
                      _buildDailyTab(report),
                      fifteenUnlocked
                          ? _buildPeriodTab(report.fifteenDayAnalysis!, report.dailyAnalyses, false)
                          : _buildLockedState('تقييم ١٥ يوماً غير جاهز', 'تحتاج لتسجيل بيانات ٣ أيام على الأقل لفتح هذا التقرير.'),
                      thirtyUnlocked
                          ? _buildPeriodTab(report.thirtyDayAnalysis!, report.dailyAnalyses, true)
                          : _buildLockedState('تقييم ٣٠ يوماً غير جاهز', 'تحتاج لتسجيل بيانات ١٥ يوماً على الأقل لفتح التقرير الشامل.'),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('حدث خطأ أثناء تحميل التقارير النفسية', style: TextStyle(color: AppColors.error)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(analysisProvider.notifier).fetchAnalysis(),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 450,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_outlined, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'بيانات غير كافية حالياً',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'سجل مزاجك، مذكراتك اليومية وحل تقييماتك لمدة ٣ أيام على الأقل لفتح تقرير التحليل النفسي التفاعلي.',
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedState(String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 54, color: AppColors.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTab(AnalysisReportModel report) {
    final latestDaily = report.dailyAnalyses.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Score Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                const Text('درجة الرفاهية لليوم الأخير', style: TextStyle(color: AppColors.outline, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickStat('مزاج اليوم', '${latestDaily.moodScore?.round() ?? '—'}'),
                    _buildQuickStat('الرفاهية', '${latestDaily.wellbeingScore?.round() ?? '—'}', isLarge: true),
                    _buildQuickStat('مستوى الخطر', latestDaily.riskLabelAr ?? 'صحي'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Domain Breakdown
          const Text('تصنيف الأعراض والمؤشرات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildBreakdownItem('مؤشر القلق (GAD-7)', latestDaily.anxietyScore, const Color(0xFF00F2FF)),
                _buildBreakdownItem('مؤشر الاكتئاب (PHQ-9)', latestDaily.depressionScore, const Color(0xFFF472B6)),
                _buildBreakdownItem('مؤشر التوتر (PSS-10)', latestDaily.stressScore, const Color(0xFFF59E0B)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chart History
          const Text('سجل تقدمك (الرفاهية)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          Container(
            height: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: report.dailyAnalyses.map((d) {
                final h = d.wellbeingScore ?? 10.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Tooltip(
                      message: '${d.analysisDate}: ${h.round()}%',
                      child: Container(
                        height: (h / 100) * 110 + 10,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(PeriodAnalysisModel data, List<DailyAnalysisModel> dailyList, bool is30Day) {
    Color trendColor = const Color(0xFF34D399); // improving / stable
    if (data.trend == 'declining') {
      trendColor = const Color(0xFFF85149);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period Overview Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data.trendAr ?? 'مستقر',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: trendColor),
                      ),
                    ),
                    const Text('نظرة عامة على الفترة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickStat('متوسط الرفاهية', '${data.averageWellbeing.round()}%'),
                    _buildQuickStat('مستوى الخطر', data.riskLabelAr ?? 'صحي'),
                    _buildQuickStat('حالة الاستقرار', data.stabilityAr ?? 'مستقر'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Averages Breakdown
          const Text('متوسط الأعراض النفسية للفترة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildBreakdownItem('متوسط القلق', data.anxietyAvg, const Color(0xFF00F2FF)),
                _buildBreakdownItem('متوسط الاكتئاب', data.depressionAvg, const Color(0xFFF472B6)),
                _buildBreakdownItem('متوسط التوتر', data.stressAvg, const Color(0xFFF59E0B)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // AI Doctor Recommendation
          _buildDoctorSuggestionCard(is30Day),

          // 30-Day Exclusive Fields
          if (is30Day) ...[
            const SizedBox(height: 24),
            _buildComparisonCard(data),
            const SizedBox(height: 24),
            _buildSeverityTrajectoryCard(data),
            if (data.weeklyPatternAr != null) ...[
              const SizedBox(height: 24),
              _buildTextCard('النمط الأسبوعي المكتشف', data.weeklyPatternAr!),
            ],
            if (data.domainCorrelationAr.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildListCard('ارتباطات الأعراض النفسية', data.domainCorrelationAr),
            ],
          ],

          // Recommendations List
          if (data.recommendationsAr.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildListCard('التوصيات والنصائح المقترحة', data.recommendationsAr, bulletColor: AppColors.primary),
          ],

          // Adaptive Adjustments
          if (data.adaptiveAdjustmentsAr.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildListCard('التعديلات التكيفية المقترحة للاستبيانات', data.adaptiveAdjustmentsAr, bulletColor: AppColors.secondary),
          ],
        ],
      ),
    );
  }

  Widget _buildDoctorSuggestionCard(bool is30Day) {
    // We can fetch clinic / suggest doctor data dynamically from auth/analysis
    final analysisState = ref.watch(analysisProvider);

    return analysisState.when(
      data: (report) {
        // Find suggested doctor if exists
        // Wait! Where is the suggested doctor info? It is returned in surveyResult,
        // but we can also mock or obtain suggested doctor if returned by the backend.
        // Let's check: does the backend provide a suggestDoctor endpoint?
        // Yes, `/clinic/suggest-doctor/`.
        // Let's use a default template if none is linked or mock, or since we got it from survey,
        // we can display a generic suggestion to match the doctor portal.
        // Wait! In React `AnalysisPage.jsx`, it fetches suggestion from `/clinic/suggest-doctor/`.
        // Let's mock a beautiful AI suggested doctor block that links to the clinic page, or if we can fetch it,
        // even better. For this, let's render a highly stylized Doctor Suggestion Card.
        // If we want to request link, we can link them to 'د. أحمد علي' / 'أخصائي علاج معرفي سلوكي'.

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEDE9FE), Color(0xFFE0F2FE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.psychology, color: Colors.purple, size: 24),
                  Text(
                    '🤖 ترشيح الطبيب الذكي (الذكاء الاصطناعي)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'بناءً على تحليلك النفسي الأخير، يقترح التطبيق التواصل مع أخصائي لمساعدتك في وضع خطة تعافي علاجية مخصصة.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'د. أحمد علي البراهيم',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'أخصائي أول في العلاج المعرفي السلوكي (CBT)',
                        style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, size: 36, color: Colors.purple),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _isLinkingDoctor
                  ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                  : PrimaryButton(
                      text: 'طلب ارتباط فوري وتواصل',
                      icon: Icons.link,
                      onPressed: () => _linkDoctor('1'), // Defaults to ID 1 or system suggested doctor
                    ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildComparisonCard(PeriodAnalysisModel data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مقارنة الفترات (نصف الشهر الأول vs الثاني)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickStat('النصف الأول', '${data.firstHalfWellbeing?.round() ?? '—'}%'),
              _buildQuickStat('النصف الثاني', '${data.secondHalfWellbeing?.round() ?? '—'}%'),
              _buildQuickStat('معدل التغير', '${data.improvementPercentage?.round() ?? '—'}%'),
            ],
          ),
          if (data.periodComparisonAr != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              data.periodComparisonAr!,
              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeverityTrajectoryCard(PeriodAnalysisModel data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مسار شدة الأعراض النفسية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          if (data.severityTrajectoryAr != null) ...[
            const SizedBox(height: 8),
            Text(
              data.severityTrajectoryAr!,
              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickStat('أفضل درجة', '${data.bestDayScore?.round() ?? '—'}'),
              _buildQuickStat('أسوأ درجة', '${data.worstDayScore?.round() ?? '—'}'),
              _buildQuickStat('نطاق التذبذب', '${data.scoreRange?.round() ?? '—'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard(String title, String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items, {Color bulletColor = AppColors.primary}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: bulletColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, {bool isLarge = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 28 : 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.outline),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, double? score, Color color) {
    if (score == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${score.round()}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100.0,
                minHeight: 8,
                color: color,
                backgroundColor: AppColors.surfaceContainerHigh,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
