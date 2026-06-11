import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/mesh_background.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeshBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Branding
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.self_improvement, color: AppColors.primary, size: 32),
                  SizedBox(width: 8),
                  Text(
                    'MindMate',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onPrimaryFixedVariant,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Hero Illustration
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuAQ6YO50Kp9sy4GnG5GberRGngxJ_ISVl45Flz8FTaXebWtxJF5eq9HhuphTM9WDQhPwPwciRNvXa_0J6zSd9R_w9OG7jYbehPVz2dGvQP4b4TFqJBTqFxWC2GOImUMWiS0rKt-nsSA58oO_ODUup9ciQpKPdEfBn9QM6mfVYMeSzj_dauJ838NZRSLRPRHkOKrg4c1d08XHXCPIooGV2V2Ekjz3_E9sd_6KQiAjiaNP1eogosTyjswtEcQ20T9KhrdtwGk_JgLdol7',
                              fit: BoxFit.cover,
                            ),
                            // Glass Overlay Card
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.auto_awesome, color: AppColors.secondary, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'علاج مدعوم بالذكاء الاصطناعي',
                                          style: TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'ملاذك الرقمي للوضوح الذهني.',
                                      style: TextStyle(
                                        color: AppColors.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Headers
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(text: 'راحة البال،\n'),
                    TextSpan(
                      text: 'بتوجيه ذكي.',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'يستخدم مايند ميت الذكاء الاصطناعي التعاطفي لفهم أنماطك، وتوفير تمارين مخصصة ومطالبات يومية مصممة لرحلتك الفريدة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              PrimaryButton(
                text: 'ابدأ الآن',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('لديك حساب بالفعل؟ سجل الدخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
