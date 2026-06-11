import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../features/mood_tracking/mood_provider.dart';

class MoodTrackerScreen extends ConsumerStatefulWidget {
  const MoodTrackerScreen({super.key});

  @override
  ConsumerState<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends ConsumerState<MoodTrackerScreen> {
  int _selectedMoodIndex = 2; // Default to neutral (index 2)
  final _noteController = TextEditingController();
  bool _isSaving = false;

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '✨', 'label': 'متألق', 'level': 5},
    {'emoji': '😊', 'label': 'جيد', 'level': 4},
    {'emoji': '🌿', 'label': 'هادئ', 'level': 3},
    {'emoji': '🤔', 'label': 'متأمل', 'level': 3},
    {'emoji': '☁️', 'label': 'محبط', 'level': 2},
    {'emoji': '🥱', 'label': 'متعب', 'level': 1},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final todayMood = ref.read(moodProvider).value;
      if (todayMood != null) {
        final level = todayMood.moodLevel;
        final index = _moods.indexWhere((m) => m['level'] == level);
        if (index != -1) {
          setState(() {
            _selectedMoodIndex = index;
          });
        }
        _noteController.text = todayMood.reasonNote ?? '';
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    final level = _moods[_selectedMoodIndex]['level'] as int;
    final note = _noteController.text.trim();

    final success = await ref.read(moodProvider.notifier).recordMood(level, note);

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل مزاجك بنجاح', textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تسجيل المزاج. يرجى المحاولة مرة أخرى.', textAlign: TextAlign.right),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تتبع المزاج',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تسجيل الدخول اليومي',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      children: [
                        TextSpan(text: 'كيف '),
                        TextSpan(
                          text: 'تشعر',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.normal,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: ' اليوم؟'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 4,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Horizontal Mood Selector
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _moods.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedMoodIndex;
                  return GestureDetector(
                    onTap: _isSaving ? null : () => setState(() => _selectedMoodIndex = index),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.surfaceContainerLowest
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _moods[index]['emoji'],
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _moods[index]['label'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Text Area Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'أخبرنا المزيد... (اختياري)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _noteController,
                          maxLines: 4,
                          enabled: !_isSaving,
                          decoration: InputDecoration(
                            hintText: 'ما الذي يدور في ذهنك؟...',
                            hintStyle: const TextStyle(color: AppColors.outlineVariant),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.lock, size: 14, color: AppColors.outline),
                            const SizedBox(width: 4),
                            Text(
                              'مدخلاتك خاصة ومشفرة',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _isSaving
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : PrimaryButton(
                          text: 'حفظ الحالة المزاجية',
                          icon: Icons.auto_awesome,
                          onPressed: _handleSave,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
