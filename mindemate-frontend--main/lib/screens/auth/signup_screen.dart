import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/mesh_background.dart';
import '../questionnaire/questionnaire_screen.dart';
import 'login_screen.dart';
import '../../features/auth/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedGender = 'male';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final ageStr = _ageController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || ageStr.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول', textAlign: TextAlign.right),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final age = int.tryParse(ageStr);
    if (age == null || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال عمر صحيح', textAlign: TextAlign.right),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final birthYear = DateTime.now().year - age;
    final dob = '$birthYear-01-01';

    final success = await ref.read(authProvider.notifier).register(
      email: email,
      password: password,
      fullName: name,
      dateOfBirth: dob,
      gender: _selectedGender,
      phoneNumber: phone,
      nationality: 'Saudi', // Default nationality for registration
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QuestionnaireScreen()),
        );
      } else {
        final errorMsg = ref.read(authProvider).errorMessage ?? 'فشل إنشاء الحساب';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, textAlign: TextAlign.right),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeshBackground(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top AppBar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => Navigator.pop(context),
                      color: AppColors.primary,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const Text(
                      'MindMate',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 32),

                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('✨', style: TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'انضم إلينا',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ابدأ رحلتك نحو الهدوء والسكينة اليوم',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 40,
                        offset: Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _nameController,
                        label: 'الاسم الكامل',
                        hint: 'أدخل اسمك بالكامل',
                        icon: Icons.person_outline,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      
                      CustomTextField(
                        controller: _ageController,
                        label: 'العمر',
                        hint: 'كم عمرك؟',
                        icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      
                      CustomTextField(
                        controller: _phoneController,
                        label: 'رقم الهاتف',
                        hint: '05xxxxxxxx',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Gender selection
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'الجنس',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('ذكر'),
                              selected: _selectedGender == 'male',
                              selectedColor: AppColors.primaryContainer,
                              labelStyle: TextStyle(
                                color: _selectedGender == 'male'
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: _isLoading
                                  ? null
                                  : (selected) {
                                      if (selected) setState(() => _selectedGender = 'male');
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('أنثى'),
                              selected: _selectedGender == 'female',
                              selectedColor: AppColors.primaryContainer,
                              labelStyle: TextStyle(
                                color: _selectedGender == 'female'
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: _isLoading
                                  ? null
                                  : (selected) {
                                      if (selected) setState(() => _selectedGender = 'female');
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      CustomTextField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        hint: 'example@domain.com',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      
                      CustomTextField(
                        controller: _passwordController,
                        label: 'كلمة السر',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'بالتسجيل، أنت توافق على شروط الخدمة وسياسة الخصوصية.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),

                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.primary))
                          : PrimaryButton(
                              text: 'إنشاء الحساب',
                              onPressed: _handleSignUp,
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('لديك حساب بالفعل؟'),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
