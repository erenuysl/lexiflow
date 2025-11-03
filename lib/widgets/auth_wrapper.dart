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
import 'error_handler_widget.dart';

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
    // Geçişlerde siyah/boş ekranı engellemek için arka planda başlat
    Future.microtask(_checkMigrationStatus);
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
    if (_hasCheckedMigration) {
      debugPrint('[AuthWrapper] Migration already cached -> skip');
      return;
    }

    try {
      debugPrint('[AuthWrapper] Checking migration status...');

      final prefs = await SharedPreferences.getInstance();
      final isCached = prefs.getBool(_migrationCacheKey) ?? false;

      if (isCached) {
        debugPrint('[AuthWrapper] Migration cached -> skip');
        if (mounted) {
          setState(() {
            _shouldShowMigration = false;
            _isCheckingMigration = false;
            _hasCheckedMigration = true;
          });
        }
        return;
      }

      final shouldShow = await widget.migrationIntegrationService
          .shouldShowMigrationScreen()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              debugPrint('[AuthWrapper] Migration check timeout -> continue');
              return false;
            },
          );

      await prefs.setBool(_migrationCacheKey, true);

      if (!mounted) {
        return;
      }

      setState(() {
        _shouldShowMigration = shouldShow;
        _isCheckingMigration = false;
        _hasCheckedMigration = true;
      });

      if (shouldShow) {
        debugPrint('[AuthWrapper] Migration required -> showing migration screen');
      } else {
        debugPrint('[AuthWrapper] Migration not needed -> continue');
      }
    } catch (e) {
      debugPrint('[AuthWrapper] Migration check error: $e');
      if (!mounted) {
        return;
      }

      setState(() {
        _shouldShowMigration = false;
        _isCheckingMigration = false;
        _hasCheckedMigration = true;
      });
      debugPrint('[AuthWrapper] Error fallback -> continue to app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        try {
          final logDetails =
              'isInitialized=${sessionService.isInitialized}, '
              'isAuthenticated=${sessionService.isAuthenticated}, '
              'isCheckingMigration=$_isCheckingMigration';
          debugPrint('[AuthWrapper] build -> ' + logDetails);

          // Always render a minimal scaffold immediately in loading state
          if (!sessionService.isInitialized || _isCheckingMigration) {
            return Scaffold(
              appBar: AppBar(title: const Text('LexiFlow')),
              body: const Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          if (sessionService.isAuthenticated) {
            debugPrint(
              '[AuthWrapper] Authenticated user -> shouldShowMigration=$_shouldShowMigration',
            );

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
              debugPrint('[AuthWrapper] Presenting migration screen');
              return const MigrationScreen();
            }

            debugPrint('[AuthWrapper] Launching main navigation');
            return MainNavigation(
              wordService: widget.wordService,
              userService: widget.userService,
              adService: widget.adService,
            );
          }

          debugPrint('[AuthWrapper] Presenting sign-in screen');
          return const SignInScreen();
        } catch (e, st) {
          // Visible error UI instead of propagating raw NotInitialized errors
          debugPrint('[AuthWrapper] UI error: $e\n$st');
          return Scaffold(
            appBar: AppBar(title: const Text('LexiFlow')),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ErrorHandlerWidget(
                error: ErrorData(
                  type: ErrorType.unknown,
                  severity: ErrorSeverity.high,
                  message: 'Uygulama başlatılırken bir hata oluştu',
                  details: e.toString(),
                  actionLabel: 'Tekrar Dene',
                  onAction: () {
                    // Best-effort: trigger session re-initialize
                    try {
                      context.read<SessionService>().initialize();
                    } catch (_) {}
                  },
                ),
                showDetails: true,
              ),
            ),
          );
        }
      },
    );
  }

  }

