import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'home/dashboard_screen.dart';
import 'analysis/analysis_screen.dart';
import 'chat/chat_screen.dart';
import 'chat/conversations_list_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AnalysisScreen(),
    const ChatScreen(),
    const ConversationsListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: AppColors.primaryContainer.withValues(alpha: 0.5),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  );
                }
                return const TextStyle(color: AppColors.outline, fontSize: 10);
              }),
            ),
            child: NavigationBar(
              backgroundColor: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
              elevation: 0,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined, color: AppColors.outline),
                  selectedIcon: Icon(Icons.home, color: AppColors.primary),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined, color: AppColors.outline),
                  selectedIcon: Icon(Icons.analytics, color: AppColors.primary),
                  label: 'التحليل',
                ),
                NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined, color: AppColors.outline),
                  selectedIcon: Icon(Icons.smart_toy, color: AppColors.primary),
                  label: 'المساعد الذكي',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_outlined, color: AppColors.outline),
                  selectedIcon: Icon(Icons.chat, color: AppColors.primary),
                  label: 'محادثاتي',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
