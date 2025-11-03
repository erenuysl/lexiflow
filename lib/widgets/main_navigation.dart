import 'package:flutter/material.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/ad_service.dart';
import '../services/achievement_listener_service.dart';
import '../screens/dashboard_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/quiz_center_screen.dart';
import '../screens/profile_screen.dart';
import 'bottom_nav_bar.dart';
import '../screens/cards/cards_home_screen.dart';

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
  late final List<Widget> _pages;
  final AchievementListenerService _achievementListener = AchievementListenerService();
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(
        wordService: widget.wordService,
        userService: widget.userService,
        adService: widget.adService,
      ),
      const QuizCenterScreen(),
      const CardsHomeScreen(),
      FavoritesScreen(
        wordService: widget.wordService,
        userService: widget.userService,
        adService: widget.adService,
      ),
      const ProfileScreen(),
    ];
    // Initialize achievement listener to show popups when achievements are unlocked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _achievementListener.initialize(context);
    });
  }

  @override
  void dispose() {
    _achievementListener.dispose();
    super.dispose();
  }

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
      body: PageStorage(
        bucket: _pageStorageBucket,
        child: Stack(
          children: [
            for (var i = 0; i < _pages.length; i++) _buildPage(i),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildPage(int index) {
    final isActive = index == _currentIndex;
    return Offstage(
      offstage: !isActive,
      child: TickerMode(
        enabled: isActive,
        child: _pages[index],
      ),
    );
  }
}
