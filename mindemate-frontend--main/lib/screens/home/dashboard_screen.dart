import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/environment.dart';
import '../../core/theme/app_colors.dart';
import 'mood_tracker_screen.dart';
import '../questionnaire/evaluation_screen.dart';
import '../journal/journal_screen.dart';
import '../journal/journal_history_screen.dart';
import '../profile/user_profile_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/mood_tracking/progress_provider.dart';
import '../../features/analysis/analysis_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  Future<void> _refreshAllData() async {
    await ref.read(dailyProgressProvider.notifier).fetchProgress();
    await ref.read(dailyTipProvider.notifier).fetchDailyTip();
    await ref.read(analysisProvider.notifier).fetchAnalysis();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final progressState = ref.watch(dailyProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'MindMate',
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
                ).then((_) => _refreshAllData());
              },
              child: CircleAvatar(
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
              ),
            ),
          )
        ],
      ),
      body: progressState.when(
        data: (progress) {
          final completedCount = progress != null
              ? (progress.moodCompleted ? 1 : 0) +
                  (progress.journalCompleted ? 1 : 0) +
                  (progress.questionnaireCompleted ? 1 : 0)
              : 0;

          final moodComplete = progress?.moodCompleted ?? false;
          final journalComplete = progress?.journalCompleted ?? false;
          final questionnaireComplete = progress?.questionnaireCompleted ?? false;

          return RefreshIndicator(
            onRefresh: _refreshAllData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Greeting
                  Text(
                    'مرحباً، ${auth.user?.fullName ?? 'صديقي'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.right,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      children: [
                        TextSpan(text: 'جد '),
                        TextSpan(
                          text: 'هدوءك الداخلي',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.normal,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: ' اليوم.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Daily Tip Card
                  _buildDailyTipCard(ref),

                  const SizedBox(height: 20),

                  // Wellbeing Score Card
                  _buildWellbeingScoreCard(ref),

                  // Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completedCount/3 مكتمل',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        'إنجازك اليومي',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: completedCount >= 1 ? AppColors.primary : AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: completedCount >= 2 ? AppColors.primary : AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: completedCount >= 3 ? AppColors.primary : AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (progress != null && progress.streak > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'سلسلة النشاط المتواصل: ${progress.streak} أيام 🔥',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),

                  // Action Cards
                  _buildActionCard(
                    context: context,
                    title: 'تتبع المزاج',
                    subtitle: moodComplete
                        ? 'تم تسجيل مزاجك اليوم! ✨'
                        : 'كيف تشعر الآن؟ سجل حالتك النفسية بسهولة.',
                    icon: '✨',
                    gradientColors: moodComplete
                        ? [AppColors.secondary, const Color(0xFF8DE8C7)]
                        : [AppColors.primary, const Color(0xFF6E78D1)],
                    textColor: AppColors.onPrimary,
                    iconBgColor: AppColors.onPrimary.withValues(alpha: 0.2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MoodTrackerScreen()),
                      ).then((_) => _refreshAllData());
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildActionCard(
                    context: context,
                    title: 'الاستبيانات اليومية',
                    subtitle: questionnaireComplete
                        ? 'شكرًا لمشاركتك! 📝'
                        : 'تقييمات سريعة لمتابعة صحتك النفسية بدقة.',
                    icon: '📝',
                    bgColor: questionnaireComplete ? null : AppColors.surfaceContainerLowest,
                    gradientColors: questionnaireComplete
                        ? [AppColors.secondary, const Color(0xFF8DE8C7)]
                        : null,
                    borderColor: questionnaireComplete ? null : AppColors.primary.withValues(alpha: 0.1),
                    textColor: questionnaireComplete ? AppColors.onPrimary : AppColors.onSurface,
                    subtitleColor: questionnaireComplete
                        ? AppColors.onPrimary.withValues(alpha: 0.8)
                        : AppColors.onSurfaceVariant,
                    iconBgColor: questionnaireComplete
                        ? AppColors.onPrimary.withValues(alpha: 0.2)
                        : AppColors.primaryContainer.withValues(alpha: 0.3),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EvaluationScreen()),
                      ).then((_) => _refreshAllData());
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildActionCard(
                    context: context,
                    title: 'المفكرة اليومية',
                    subtitle: journalComplete
                        ? 'تم حفظ أفكارك اليومية ✍️'
                        : 'مساحة خاصة للتعبير عن أفكارك وتأملاتك.',
                    icon: '✍️',
                    bgColor: journalComplete ? null : AppColors.surfaceContainerLow,
                    gradientColors: journalComplete
                        ? [AppColors.secondary, const Color(0xFF8DE8C7)]
                        : null,
                    borderColor: journalComplete ? null : AppColors.outlineVariant.withValues(alpha: 0.1),
                    textColor: journalComplete ? AppColors.onPrimary : AppColors.onSurface,
                    subtitleColor: journalComplete
                        ? AppColors.onPrimary.withValues(alpha: 0.8)
                        : AppColors.onSurfaceVariant,
                    iconBgColor: journalComplete
                        ? AppColors.onPrimary.withValues(alpha: 0.2)
                        : AppColors.tertiaryContainer.withValues(alpha: 0.4),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const JournalScreen()),
                      ).then((_) => _refreshAllData());
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const JournalHistoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined, color: AppColors.primary, size: 18),
                      label: const Text(
                        'سجل اليوميات السابقة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('فشل تحميل البيانات اليومية', style: TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _refreshAllData,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String icon,
    Color? bgColor,
    List<Color>? gradientColors,
    Color? borderColor,
    required Color textColor,
    Color? subtitleColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          gradient: gradientColors != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                )
              : null,
          borderRadius: BorderRadius.circular(32),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: [
            BoxShadow(
              color: gradientColors != null
                  ? gradientColors.first.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor ?? textColor.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTipCard(WidgetRef ref) {
    final tipState = ref.watch(dailyTipProvider);
    return tipState.when(
      data: (tipMap) {
        if (tipMap == null || tipMap['content']!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'نصيحة اليوم - ${tipMap['category']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, color: AppColors.primary, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tipMap['content']!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildWellbeingScoreCard(WidgetRef ref) {
    final analysisState = ref.watch(analysisProvider);

    return analysisState.when(
      data: (report) {
        if (report == null || report.dailyAnalyses.isEmpty) {
          return const SizedBox.shrink();
        }

        final latestDaily = report.dailyAnalyses.last;
        if (latestDaily.wellbeingScore == null) {
          return const SizedBox.shrink();
        }

        final score = latestDaily.wellbeingScore!;
        final riskLabel = latestDaily.riskLabelAr ?? 'صحي';
        final riskLevel = latestDaily.riskLevel ?? 'healthy';

        Color riskColor = const Color(0xFF34D399); // healthy
        if (riskLevel == 'severe' || riskLevel == 'at_risk') {
          riskColor = const Color(0xFFF85149);
        } else if (riskLevel == 'moderate') {
          riskColor = const Color(0xFFD29922);
        } else if (riskLevel == 'mild') {
          riskColor = const Color(0xFFF97316);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, 10),
              )
            ],
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
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      riskLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Text(
                        'مؤشر الصحة النفسية اليومي',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildDomainBar('القلق', latestDaily.anxietyScore, const Color(0xFF00F2FF)),
                        _buildDomainBar('الاكتئاب', latestDaily.depressionScore, const Color(0xFFF472B6)),
                        _buildDomainBar('التوتر', latestDaily.stressScore, const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildWellbeingCircle(score),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildWellbeingCircle(double score) {
    final color = score >= 75
        ? const Color(0xFF34D399)
        : score >= 50
            ? const Color(0xFFD29922)
            : score >= 25
                ? const Color(0xFFF97316)
                : const Color(0xFFF85149);

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 8,
            backgroundColor: AppColors.surfaceContainerHigh,
            color: color,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              score.round().toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const Text(
              'الرفاهية',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildDomainBar(String label, double? score, Color color) {
    if (score == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${score.round()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100.0,
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.surfaceContainerHigh,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
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
