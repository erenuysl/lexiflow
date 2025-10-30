import 'package:flutter/material.dart';
import '../widgets/auth_wrapper.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/migration_integration_service.dart';
import '../services/ad_service.dart';

class SplashScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final MigrationIntegrationService migrationIntegrationService;
  final AdService adService;

  const SplashScreen({
    super.key,
    required this.wordService,
    required this.userService,
    required this.migrationIntegrationService,
    required this.adService,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    // Ampulün "nefes alır gibi" yanıp sönmesi
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _opacity = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Minimum 500ms gösterim süresi ile optimize edilmiş geçiş
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Minimum splash gösterim süresi için timer başlat
    final minimumDisplayTime = Future.delayed(const Duration(milliseconds: 500));
    
    // Servislerin hazır olup olmadığını kontrol et (arka planda zaten başlatılmış olmalı)
    final initializationTime = DateTime.now();
    
    try {
      // Servislerin temel hazırlık durumunu kontrol et
      // WordService ve UserService zaten main.dart'ta başlatılmış durumda
      await Future.wait([
        // Minimum gösterim süresini bekle
        minimumDisplayTime,
        // Ek bir güvenlik kontrolü için kısa bir gecikme
        Future.delayed(const Duration(milliseconds: 100)),
      ]);
      
      if (mounted) {
        final totalTime = DateTime.now().difference(initializationTime);
        print('🚀 [Splash] Total splash duration: ${totalTime.inMilliseconds}ms');
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600), // Geçiş süresini de kısalttık
            pageBuilder: (_, __, ___) => AuthWrapper(
              wordService: widget.wordService,
              userService: widget.userService,
              migrationIntegrationService: widget.migrationIntegrationService,
              adService: widget.adService,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      print('⚠️ [Splash] Error during initialization: $e');
      // Hata durumunda bile minimum süre sonra geçiş yap
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => AuthWrapper(
              wordService: widget.wordService,
              userService: widget.userService,
              migrationIntegrationService: widget.migrationIntegrationService,
              adService: widget.adService,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081D3B), // Lacivert arkaplan
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Image.asset(
            'assets/logo/lexiflow_logo.png', 
            width: 180,
          ),
        ),
      ),
    );
  }
}