import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/primary_button.dart';
import '../../features/journal/journal_provider.dart';
import '../../features/mood_tracking/progress_provider.dart';
import '../../shared/models/app_models.dart';
import 'journal_history_screen.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _contentController = TextEditingController();
  bool _doctorAccess = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load existing journal content if any
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final todayJournal = ref.read(journalProvider).value;
      if (todayJournal != null) {
        _contentController.text = todayJournal.content;
      }
      _fetchSharingPermissions();
    });
  }

  Future<void> _fetchSharingPermissions() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/tracking/journal/sharing/');
      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final list = response.data as List;
        setState(() {
          _doctorAccess = list.any((element) => element['share_full_journal'] == true);
        });
      }
    } catch (_) {}
  }

  Future<void> _updateSharingPermissions(bool share) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/tracking/journal/sharing/');
      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        for (var item in list) {
          final docId = item['doctor_id'];
          if (docId != null) {
            await apiClient.post('/tracking/journal/sharing/', data: {
              'doctor_id': docId,
              'share_full_journal': share,
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء كتابة شيء ما أولاً', textAlign: TextAlign.right),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await ref.read(journalProvider.notifier).recordJournal(content);

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        // Refresh tip of the day
        ref.read(dailyTipProvider.notifier).fetchDailyTip();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ اليومية بنجاح', textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل حفظ اليومية. حاول مرة أخرى.', textAlign: TextAlign.right),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<JournalEntryModel?>>(journalProvider, (previous, next) {
      next.whenData((journal) {
        if (journal != null && _contentController.text.isEmpty) {
          _contentController.text = journal.content;
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'MindMate',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.primary),
            tooltip: 'اليوميات السابقة',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const JournalHistoryScreen()),
              );
            },
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'جلسة المساء',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.outline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceContainerHigh,
              child: const Icon(Icons.person, color: AppColors.outline),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اكتب بحرية',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'دع أفكارك تنساب مثل تيار لطيف. هذا هو مساحتك الآمنة للتأمل.',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Doctor Access Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'وصول الطبيب',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _doctorAccess,
                        onChanged: _isSaving
                            ? null
                            : (val) {
                                setState(() => _doctorAccess = val);
                                _updateSharingPermissions(val);
                              },
                        activeTrackColor: AppColors.primary,
                        inactiveThumbColor: AppColors.surfaceContainerLowest,
                        inactiveTrackColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Text Input Area
            Container(
              height: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                children: [
                  // Editor Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'تم الحفظ والاتصال التلقائي نشط',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.format_italic, color: AppColors.onSurfaceVariant),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.list, color: AppColors.onSurfaceVariant),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      enabled: !_isSaving,
                      style: const TextStyle(fontSize: 20, height: 1.5, color: AppColors.onSurface),
                      decoration: const InputDecoration(
                        hintText: 'ابدأ بكتابة أفكارك هنا...',
                        hintStyle: TextStyle(color: Colors.black38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: AppColors.primary)
                        : PrimaryButton(
                            text: 'إكمال المدخلة',
                            onPressed: _handleSave,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Prompt Card
            ref.watch(dailyTipProvider).when(
              data: (tipMap) {
                final hasTip = tipMap != null && tipMap['content']!.isNotEmpty;
                return Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: hasTip ? AppColors.primary : AppColors.primaryDim,
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.onSurface, AppColors.onSurface.withValues(alpha: 0)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              hasTip ? '🌟 نصيحة اليوم - ${tipMap['category']}' : 'تلميح اليوم',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasTip 
                                  ? tipMap['content']!
                                  : 'أكمل جميع مهام اليوم (تتبع المزاج، كتابة اليوميات، الاستبيان) لتلقي نصيحتك المخصصة.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, s) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
