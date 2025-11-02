import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/migration_integration_service.dart';
import '../services/ad_service.dart';
import '../providers/sync_status_provider.dart';
import '../screens/sign_in_screen.dart';
import '../screens/migration_screen.dart';
import 'main_navigation.dart';

class AuthWrapper extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final MigrationIntegrationService migrationIntegrationService;
  final AdService adService;

  const AuthWrapper({
    super.key,
    required this.wordService,
    required this.userService,
    required this.migrationIntegrationService,
    required this.adService,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingMigration = true;
  bool _shouldShowMigration = false;
  bool _hasCheckedMigration = false;
  
  static const String _migrationCacheKey = 'migration_check_completed';

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  @override
  void didUpdateWidget(AuthWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only recheck if we haven't checked yet
    if (!_hasCheckedMigration) {
      _checkMigrationStatus();
    }
  }

  Future<void> _checkMigrationStatus() async {
    // Prevent multiple checks
    if (_hasCheckedMigration) {
      debugPrint('I/flutter: [AUTH] Migration cached -> skip');
      return;
    }

    try {
      debugPrint('I/flutter: [AUTH] Checking migration...');
      
      // önce cache kontrol et
      final prefs = await SharedPreferences.getInstance();
      final isCached = prefs.getBool(_migrationCacheKey) ?? false;
      
      if (isCached) {
        debugPrint('I/flutter: [AUTH] Migration cached -> skip');
        if (mounted) {
          setState(() {
            _shouldShowMigration = false;
            _isCheckingMigration = false;
            _hasCheckedMigration = true;
          });
        }
        return;
      }
      
      // timeout 2 saniyeye düşürüldü
      final shouldShow = await widget.migrationIntegrationService
          .shouldShowMigrationScreen()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              debugPrint('I/flutter: [AUTH] Migration check timeout -> continue');
              return false;
            },
          );

      // sonucu cache'le
      await prefs.setBool(_migrationCacheKey, true);

      if (mounted) {
        setState(() {
          _shouldShowMigration = shouldShow;
          _isCheckingMigration = false;
          _hasCheckedMigration = true;
        });
        
        if (shouldShow) {
          debugPrint('🔄 Migration screen gösterilecek');
        } else {
          debugPrint('✅ Ana ekrana geçiliyor');
        }
      }
    } catch (e) {
      debugPrint('❌ Migration kontrolü hatası: $e');
      if (mounted) {
        setState(() {
          _shouldShowMigration = false; // hata durumunda ana ekrana geç
          _isCheckingMigration = false;
          _hasCheckedMigration = true;
        });
        debugPrint('🏠 Hata nedeniyle ana ekrana yönlendiriliyor');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        // Debug için SessionService durumunu logla
        debugPrint('🔍 AuthWrapper build - isInitialized: ${sessionService.isInitialized}, isAuthenticated: ${sessionService.isAuthenticated}, _isCheckingMigration: $_isCheckingMigration');
        
        if (!sessionService.isInitialized || _isCheckingMigration) {
          debugPrint('⏳ Loading ekranı gösteriliyor - isInitialized: ${sessionService.isInitialized}, _isCheckingMigration: $_isCheckingMigration');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (sessionService.isAuthenticated) {
          debugPrint('✅ Kullanıcı authenticate - _shouldShowMigration: $_shouldShowMigration');
          
          // Initialize SyncStatusProvider when user is authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final syncProvider = context.read<SyncStatusProvider>();
            final user = sessionService.currentUser;
            if (user != null && !syncProvider.isInitialized) {
              syncProvider.initialize().then((_) {
                syncProvider.setUser(user.uid);
              });
            }
          });
          
          if (_shouldShowMigration) {
            debugPrint('🔄 Migration screen gösteriliyor');
            return const MigrationScreen();
          }

          debugPrint('🏠 Ana ekrana yönlendiriliyor');
          return MainNavigation(
            wordService: widget.wordService,
            userService: widget.userService,
            adService: widget.adService,
          );
        }

        debugPrint('🔐 SignIn screen gösteriliyor');
        return const SignInScreen();
      },
    );
  }
}
