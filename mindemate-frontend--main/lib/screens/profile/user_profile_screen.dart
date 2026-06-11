import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/environment.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/notifications/notification_provider.dart';
import '../../features/doctors/doctors_provider.dart';
import '../../features/messaging/chat_provider.dart';
import '../chat/doctor_chat_screen.dart';
import '../directory/doctor_directory_screen.dart';
import '../../shared/models/app_models.dart';
import '../../core/network/api_client.dart';
import '../auth/login_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _nationalityController = TextEditingController();
  String _gender = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationPreferencesProvider.notifier).fetchPreferences();
      ref.read(doctorsProvider.notifier).fetchDoctors();
      ref.read(conversationsProvider.notifier).fetchConversations();
    });

    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phoneNumber ?? '';
      _dobController.text = user.dateOfBirth ?? '';
      _gender = user.gender ?? '';
      _nationalityController.text = user.nationality ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال الاسم الكامل', textAlign: TextAlign.right),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await ref.read(authProvider.notifier).updateProfile(
          fullName: _nameController.text.trim(),
          dateOfBirth: _dobController.text.trim(),
          gender: _gender,
          phoneNumber: _phoneController.text.trim(),
          nationality: _nationalityController.text.trim(),
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'تم تحديث الملف الشخصي بنجاح' : 'فشل تحديث الملف الشخصي',
            textAlign: TextAlign.right,
          ),
          backgroundColor: success ? Colors.green : AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() {
      _isSaving = true;
    });

    final success = await ref.read(authProvider.notifier).updateProfile(
          fullName: _nameController.text.trim(),
          dateOfBirth: _dobController.text.trim(),
          gender: _gender,
          phoneNumber: _phoneController.text.trim(),
          nationality: _nationalityController.text.trim(),
          profileImage: image,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'تم تحديث صورة الملف الشخصي بنجاح' : 'فشل تحديث صورة الملف الشخصي',
            textAlign: TextAlign.right,
          ),
          backgroundColor: success ? Colors.green : AppColors.error,
        ),
      );
    }
  }

  void _showRatingDialog(DoctorModel doctor) {
    int rating = 5;
    final commentController = TextEditingController();
    bool isSubmittingRating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerLowest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'تقييم د. ${doctor.fullName}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'شارك تجربتك لمساعدة الآخرين في اختيار الأخصائي الأنسب.',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFD29922),
                          size: 36,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            rating = starValue;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'أضف تعليقك هنا (اختياري)...',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmittingRating ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: AppColors.outline)),
                ),
                ElevatedButton(
                  onPressed: isSubmittingRating
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmittingRating = true;
                          });
                          try {
                            final apiClient = ref.read(apiClientProvider);
                            final response = await apiClient.post(
                              '/clinic/doctors/${doctor.doctorId}/ratings/',
                              data: {
                                'score': rating,
                                'comment': commentController.text.trim(),
                              },
                            );
                            if (response.statusCode == 200 || response.statusCode == 201) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('شكراً لتقييمك! تم حفظ التقييم بنجاح.', textAlign: TextAlign.right),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('فشل إرسال التقييم. يرجى المحاولة لاحقاً.', textAlign: TextAlign.right),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: isSubmittingRating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('إرسال التقييم'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLinkedDoctorDetails(DoctorModel doctor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'د. ${doctor.fullName}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctor.specialization,
                          style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFEDE9FE), Color(0xFFE0F2FE)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 40, color: Colors.purple),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'نبذة تعريفية',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              Text(
                doctor.bio ?? 'لا تتوفر نبذة تعريفية حالياً.',
                style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRatingDialog(doctor);
                      },
                      icon: const Icon(Icons.star, color: Color(0xFFD29922)),
                      label: const Text('تقييم الأخصائي', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD29922),
                        side: const BorderSide(color: Color(0xFFD29922)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      return Expanded(
                        child: PrimaryButton(
                          text: 'بدء محادثة',
                          icon: Icons.chat_bubble_outline,
                          onPressed: () {
                            Navigator.pop(context);
                            final conversations = ref.read(conversationsProvider).value ?? [];
                            final matchingConv = conversations.firstWhere(
                              (c) => c.otherParty['doctor_id'] == doctor.doctorId,
                              orElse: () => ConversationModel(id: '', createdAt: '', otherParty: {}, unreadCount: 0),
                            );
                            if (matchingConv.id.isNotEmpty) {
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
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('لا توجد محادثة نشطة مع هذا الطبيب حالياً.', textAlign: TextAlign.right),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    }
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final prefsState = ref.watch(notificationPreferencesProvider);
    final linkedDoctor = ref.watch(linkedDoctorProvider);
    final user = authState.user;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user != null && previous?.user != next.user) {
        _nameController.text = next.user!.fullName;
        _phoneController.text = next.user!.phoneNumber ?? '';
        _dobController.text = next.user!.dateOfBirth ?? '';
        setState(() {
          _gender = next.user!.gender ?? '';
        });
        _nationalityController.text = next.user!.nationality ?? '';
      }
    });

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final avatarLetter = user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'تعديل الملف الشخصي',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // Profile Hero Avatar
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: user.profileImage == null || user.profileImage!.isEmpty
                            ? const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        shape: BoxShape.circle,
                        image: user.profileImage != null && user.profileImage!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(Environment.getFullImageUrl(user.profileImage)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: user.profileImage == null || user.profileImage!.isEmpty
                          ? Text(
                              avatarLetter,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadProfileImage,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  user.email,
                  style: const TextStyle(fontSize: 14, color: AppColors.outline),
                ),
              ),
              const SizedBox(height: 32),

              // Connected Doctor Section
              const Text(
                'الرعاية الطبية والارتباط',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              if (linkedDoctor != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'د. ${linkedDoctor.fullName}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              linkedDoctor.specialization,
                              style: const TextStyle(fontSize: 12, color: AppColors.outline),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _showLinkedDoctorDetails(linkedDoctor),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.arrow_back, size: 14, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'عرض ملف الطبيب والتواصل',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology, size: 32, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'لا يوجد طبيب مرتبط بحسابك حالياً.',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DoctorDirectoryScreen()),
                          );
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('تصفح الأخصائيين المتاحين'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Form Fields
              const Text(
                'البيانات الشخصية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _nameController,
                label: 'الاسم الكامل',
                hint: 'أدخل الاسم الكامل',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: CustomTextField(
                    controller: _dobController,
                    label: 'تاريخ الميلاد',
                    hint: 'اختر تاريخ الميلاد',
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gender.isEmpty ? null : _gender,
                alignment: Alignment.centerRight,
                decoration: InputDecoration(
                  labelText: 'الجنس',
                  labelStyle: const TextStyle(color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  prefixIcon: const Icon(Icons.wc_outlined, color: AppColors.outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('ذكر', textAlign: TextAlign.right)),
                  DropdownMenuItem(value: 'female', child: Text('أنثى', textAlign: TextAlign.right)),
                  DropdownMenuItem(value: 'other', child: Text('أخرى', textAlign: TextAlign.right)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _gender = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                label: 'رقم الهاتف',
                hint: 'أدخل رقم الهاتف',
                icon: Icons.phone_iphone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _nationalityController,
                label: 'الجنسية',
                hint: 'أدخل الجنسية',
                icon: Icons.public_outlined,
              ),
              const SizedBox(height: 24),
              _isSaving
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : PrimaryButton(
                      text: 'حفظ التغييرات',
                      icon: Icons.save,
                      onPressed: _saveProfile,
                    ),
              const SizedBox(height: 32),

              // Notification Toggles
              const Text(
                'تفضيلات التنبيهات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              prefsState.when(
                data: (prefs) {
                  final emailNotifs = prefs['email_notifications'] ?? false;
                  final pushNotifs = prefs['push_notifications'] ?? false;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('تنبيهات البريد الإلكتروني', textAlign: TextAlign.right),
                          subtitle: const Text('تلقي ملخصات وتقارير العلاج بالبريد.', textAlign: TextAlign.right, style: TextStyle(fontSize: 11)),
                          value: emailNotifs,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) {
                            ref.read(notificationPreferencesProvider.notifier).updatePreference('email_notifications', val);
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('تنبيهات الهاتف المحمول', textAlign: TextAlign.right),
                          subtitle: const Text('تلقي إشعارات فورية بالرسائل والحالات.', textAlign: TextAlign.right, style: TextStyle(fontSize: 11)),
                          value: pushNotifs,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) {
                            ref.read(notificationPreferencesProvider.notifier).updatePreference('push_notifications', val);
                          },
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, stack) => const Text('فشل تحميل التفضيلات', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 32),

              // Logout Button
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
      ),
    );
  }
}
