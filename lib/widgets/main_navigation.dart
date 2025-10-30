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
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          // Ana Sayfa - Dashboard
          DashboardScreen(
            wordService: widget.wordService,
            userService: widget.userService,
            adService: widget.adService,
          ),
          // Favoriler
          FavoritesScreen(
            wordService: widget.wordService,
            userService: widget.userService,
            adService: widget.adService,
          ),
          // Quiz Center
          const QuizCenterScreen(),
          // Profil
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}