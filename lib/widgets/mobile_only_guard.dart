import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';

/// Uygulamanın sadece mobil cihazlarda çalışmasını sağlayan widget
/// Web ve masaüstü platformları için hata ekranı gösterir
class MobileOnlyGuard extends StatelessWidget {
  final Widget child;

  const MobileOnlyGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || 
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return MaterialApp(
        title: 'LexiFlow - Mobil Uygulama',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Inter',
        ),
        home: const MobileOnlyErrorScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    // Mobil cihazlar için gerçek uygulamayı döndür
    return child;
  }
}

/// Mobil olmayan platformlardan erişildiğinde gösterilen hata ekranı
class MobileOnlyErrorScreen extends StatelessWidget {
  const MobileOnlyErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.smartphone,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // App Name
              Text(
                'LexiFlow',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Main Message
              Text(
                'Bu uygulama yalnızca mobil cihazlar için tasarlanmıştır.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Description
              Text(
                'LexiFlow\'u kullanmak için lütfen bir akıllı telefon veya tablet kullanınız. '
                'Tarayıcı üzerinden erişim denemeleri desteklenmemektedir.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Uygulamayı indirmek için:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Android cihazlar için Google Play Store\n'
                      '• iOS cihazlar için App Store\n'
                      '• Veya APK dosyasını doğrudan indirin',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Footer
              Text(
                'Anlayışınız için teşekkür ederiz.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}