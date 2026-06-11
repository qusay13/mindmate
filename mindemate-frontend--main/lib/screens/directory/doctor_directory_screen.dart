import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../chat/doctor_chat_screen.dart';
import '../../features/doctors/doctors_provider.dart';
import '../../features/messaging/chat_provider.dart';
import '../../shared/models/app_models.dart';

class DoctorDirectoryScreen extends ConsumerStatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  ConsumerState<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends ConsumerState<DoctorDirectoryScreen> {
  final _searchController = TextEditingController();
  String _selectedSpecialty = 'الكل';
  bool _showSearchField = false;

  final List<String> _specialties = [
    'الكل',
    'الطب النفسي العام',
    'طب نفس الأطفال والمراهقين',
    'طب نفس المسنين',
    'طب النفس الإدماني',
    'الطب النفسي القضائي',
    'الطب النفسي الجسدي',
    'العلاج النفسي',
    'الاضطرابات المزاجية والقلق',
    'الصدمات النفسية',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(doctorsProvider.notifier).fetchDoctors();
      ref.read(suggestedDoctorProvider.notifier).fetchSuggestion();
      ref.read(conversationsProvider.notifier).fetchConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchOrFilterChanged() {
    ref.read(doctorsProvider.notifier).searchAndFilter(
          _searchController.text,
          _selectedSpecialty == 'الكل' ? null : _selectedSpecialty,
        );
  }

  @override
  Widget build(BuildContext context) {
    final doctorsState = ref.watch(doctorsProvider);
    final suggestedDoctorState = ref.watch(suggestedDoctorProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'دليل الأخصائيين',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearchField ? Icons.close : Icons.search,
              color: AppColors.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() {
                _showSearchField = !_showSearchField;
                if (!_showSearchField) {
                  _searchController.clear();
                  _onSearchOrFilterChanged();
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(doctorsProvider.notifier).fetchDoctors();
          ref.read(suggestedDoctorProvider.notifier).fetchSuggestion();
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Field
              if (_showSearchField) ...[
                TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو التخصص الدقيق...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => _onSearchOrFilterChanged(),
                ),
                const SizedBox(height: 24),
              ],

              // Specialties horizontal list
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  reverse: true, // RTL flow
                  itemCount: _specialties.length,
                  itemBuilder: (context, index) {
                    final specialty = _specialties[index];
                    final isSelected = specialty == _selectedSpecialty;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(specialty),
                        selected: isSelected,
                        selectedColor: AppColors.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedSpecialty = specialty;
                            });
                            _onSearchOrFilterChanged();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // AI Matched Hero Section (Suggested Doctor)
              suggestedDoctorState.when(
                data: (suggestedDoctor) {
                  if (suggestedDoctor == null) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'بناءً على تقييمك الأخير',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.primaryDim.withValues(alpha: 0.7),
                            ),
                          ),
                          const Text(
                            'توصيتنا المختارة لك',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSuggestedDoctorCard(context, suggestedDoctor),
                      const SizedBox(height: 32),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              // Emergency Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: const Border(
                    right: BorderSide(color: AppColors.error, width: 4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emergency, color: AppColors.onError),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'هل تحتاج إلى دعم فوري؟',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'إذا كنت تواجه أزمة حادة أو أفكار مؤذية، يمكنك الاتصال فوراً بخط الدعم.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.error.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('خط الطوارئ الوطني متوفر على مدار الساعة: 937', textAlign: TextAlign.right),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.onError,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('اتصل الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Directory Title
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'استكشف الأخصائيين المتاحين',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grid of Doctors
              doctorsState.when(
                data: (doctors) {
                  if (doctors.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('لا يوجد أطباء مطابقين للبحث حالياً.'),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: doctors.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = doctors[index];
                      return _buildDoctorCard(context, doc);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, stack) => Center(
                  child: Text('فشل تحميل دليل الأطباء: $err'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedDoctorCard(BuildContext context, DoctorModel doctor) {
    final isLinked = doctor.linkStatus == 'linked';
    final isPending = doctor.linkStatus == 'pending';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'د. ${doctor.fullName}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        doctor.specialization,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryContainer,
                child: const Icon(Icons.person, size: 40, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            doctor.bio ?? 'أخصائي متميز في تحسين الصحة النفسية والرفاهية الوجدانية.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (isLinked) ...[
                Expanded(
                  child: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text('مرتبط بك حالياً', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (isPending) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('قيد الانتظار'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: PrimaryButton(
                    text: 'طلب ارتباط',
                    onPressed: () async {
                      final success = await ref
                          .read(doctorsProvider.notifier)
                          .linkWithDoctor(doctor.doctorId, requestType: 'system_suggested');
                      if (success && context.mounted) {
                        ref.read(suggestedDoctorProvider.notifier).fetchSuggestion();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال طلب الارتباط بنجاح', textAlign: TextAlign.right),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final conversations = ref.watch(conversationsProvider).value ?? [];
                  final matchingConv = conversations.firstWhere(
                    (c) => c.otherParty['doctor_id'] == doctor.doctorId,
                    orElse: () => ConversationModel(id: '', createdAt: '', otherParty: {}, unreadCount: 0),
                  );

                  return Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('محادثة', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: isLinked && matchingConv.id.isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DoctorChatScreen(
                                    conversationId: matchingConv.id,
                                    doctorName: 'د. ${doctor.fullName}',
                                    doctorTitle: doctor.specialization,
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                            color: isLinked && matchingConv.id.isNotEmpty ? AppColors.primary : Colors.grey, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  );
                }
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, DoctorModel doctor) {
    final isLinked = doctor.linkStatus == 'linked';
    final isPending = doctor.linkStatus == 'pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isLinked)
                          const Icon(Icons.check_circle, color: Colors.green, size: 16)
                        else if (isPending)
                          const Icon(Icons.pending_actions, color: Colors.orange, size: 16),
                        if (isLinked || isPending) const SizedBox(width: 6),
                        Text(
                          'د. ${doctor.fullName}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.specialization,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                child: const Icon(Icons.person, size: 32, color: AppColors.primary),
              ),
            ],
          ),
          if (doctor.bio != null && doctor.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              doctor.bio!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (isLinked) ...[
                Expanded(
                  child: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text('مرتبط بك حالياً', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (isPending) ...[
                const Expanded(
                  child: Center(
                    child: Text(
                      'طلب الارتباط قيد الانتظار',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: PrimaryButton(
                    text: 'طلب ارتباط',
                    onPressed: () async {
                      final success = await ref
                          .read(doctorsProvider.notifier)
                          .linkWithDoctor(doctor.doctorId);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال طلب الارتباط بنجاح', textAlign: TextAlign.right),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final conversations = ref.watch(conversationsProvider).value ?? [];
                  final matchingConv = conversations.firstWhere(
                    (c) => c.otherParty['doctor_id'] == doctor.doctorId,
                    orElse: () => ConversationModel(id: '', createdAt: '', otherParty: {}, unreadCount: 0),
                  );

                  return Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('محادثة', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: isLinked && matchingConv.id.isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DoctorChatScreen(
                                    conversationId: matchingConv.id,
                                    doctorName: 'د. ${doctor.fullName}',
                                    doctorTitle: doctor.specialization,
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                            color: isLinked && matchingConv.id.isNotEmpty ? AppColors.primary : Colors.grey, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  );
                }
              ),
            ],
          ),
        ],
      ),
    );
  }
}
