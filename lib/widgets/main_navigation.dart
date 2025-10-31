import 'package:flutter/material.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/ad_service.dart';
import '../screens/dashboard_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/quiz_center_screen.dart';
import '../screens/profile_screen.dart';
import 'bottom_nav_bar.dart';

class MainNavigation extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;

  const MainNavigation({
    super.key,
    required this.wordService,
    required this.userService,
    required this.adService,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // telemetri log
    debugPrint('I/flutter: [NAV] Switched tab -> index=$_currentIndex');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Ana Sayfa - Dashboard
          DashboardScreen(
            wordService: widget.wordService,
            userService: widget.userService,
            adService: widget.adService,
          ),
          // Quiz Center
          const QuizCenterScreen(),
          // Favoriler
          FavoritesScreen(
            wordService: widget.wordService,
            userService: widget.userService,
            adService: widget.adService,
          ),
          // Profil
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}