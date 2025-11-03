import 'dart:async';
import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'models/word_model.dart';
import 'models/user_data.dart';
import 'models/daily_log.dart';
import 'models/user_stats_model.dart';
import 'services/cloud_sync_service.dart';
import 'services/word_service.dart';
import 'services/user_service.dart';
import 'services/session_service.dart';
import 'services/migration_integration_service.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/learned_words_service.dart';
import 'services/achievement_service.dart';
import 'providers/theme_provider.dart';
import 'providers/profile_stats_provider.dart';
import 'providers/cards_provider.dart';
import 'providers/sync_status_provider.dart';
import 'utils/hive_boxes.dart';
import 'themes/lexiflow_theme.dart';
import 'utils/lexiflow_colors.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/mobile_only_guard.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/daily_challenge_screen.dart';
import 'screens/daily_word_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'screens/share_preview_screen.dart';
import 'screens/word_detail_screen.dart';
import 'screens/quiz_center_screen.dart';
import 'screens/category_quiz_play_screen.dart';
import 'screens/general_quiz_screen.dart';
import 'screens/quiz_start_screen.dart';
import 'utils/logger.dart';
import 'widgets/connection_status_widget.dart';
import 'widgets/sync_notification_widget.dart';
import 'di/locator.dart';
import 'debug/connectivity_debug.dart';

/*
  Startup Freeze Fix - Root Cause and Solution
  ------------------------------------------------
  Root Cause:
  After a refactor, runApp(MyApp) was invoked before critical platform
  services were initialized. Some widgets/services (FirebaseAuth, Analytics,
  Hive boxes, DI locator) accessed Firebase/Hive immediately, which led to
  NotInitialized errors and a white/pink screen during startup.

  What we changed:
  1) Perform critical initialization BEFORE runApp:
     - WidgetsFlutterBinding.ensureInitialized()
     - Firebase.initializeApp(...)
     - Hive.initFlutter + register adapters + open required box(es)
     - setupLocator() for DI
     - Initialize critical domain services (WordService, UserService, SessionService)
  2) Defer non‑critical services to background using unawaited()/microtasks
     AFTER runApp so first UI paints immediately.
  3) Strengthened AuthWrapper to always render a minimal scaffold and present
     a visible error UI if something goes wrong, instead of propagating raw
     initialization errors.

  Result:
  The app now boots cleanly without NotInitializedError, and the first frame
  appears quickly. This sequence is safe in both debug and release builds.
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables FIRST
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ [main] .env loaded');
  } catch (e) {
    debugPrint('⚠️ [main] .env load failed (continuing with defaults): $e');
  }

  // Critical initialization BEFORE runApp to avoid NotInitializedError
  try {
    debugPrint('[boot] Phase-A start');
    debugPrint('🔧 [main] Initializing Firebase core...');
    // Detect existing default app created by native provider and reuse it.
    // If none exists, initialize with explicit options.
    try {
      final existingApp = Firebase.app();
      debugPrint('⚠️ [main] Existing Firebase app detected: ${existingApp.name}; using it');
    } on FirebaseException catch (_) {
      try {
        // Prefer explicit options loaded from .env; if missing, fall back
        // to native resources (google-services.json).
        FirebaseOptions? opts;
        try {
          final candidate = DefaultFirebaseOptions.currentPlatform;
          if (candidate.apiKey.isNotEmpty &&
              candidate.appId.isNotEmpty &&
              candidate.projectId.isNotEmpty) {
            opts = candidate;
          } else {
            debugPrint('⚠️ [main] Incomplete FirebaseOptions from .env; using native defaults');
          }
        } catch (_) {
          // Unsupported platform or other issues; use native defaults
        }

        if (opts != null) {
          await Firebase.initializeApp(options: opts);
        } else {
          await Firebase.initializeApp();
        }
        debugPrint('✅ [main] Firebase core initialized');
      } on FirebaseException catch (e) {
        // If native auto-init already created the default app, re-initialization throws.
        final msg = e.message ?? '';
        if (e.code == 'duplicate-app' || msg.contains('already exists')) {
          debugPrint('⚠️ [main] Default app already exists; proceeding without re-init');
        } else {
          rethrow;
        }
      }
    }
    
    // Register background message handler AFTER Firebase is initialized
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('✅ [main] Background message handler registered');

    // System UI configuration (non-blocking)
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    debugPrint('📦 [main] Initializing local services (Hive)...');
    await _initializeLocalServices();
    debugPrint('✅ [main] Hive initialized');

    debugPrint('🧩 [main] Setting up service locator...');
    await setupLocator();
    debugPrint('✅ [main] Service locator ready');

    // Safety check: ensure critical services are registered before building the widget tree
    assert(
      locator.isRegistered<SessionService>(),
      'SessionService not registered before runApp! Ensure setupLocator() runs first.',
    );
    assert(
      locator.isRegistered<ThemeProvider>(),
      'ThemeProvider not registered before runApp! Ensure setupLocator() registers it.',
    );
    assert(
      locator.isRegistered<WordService>() && locator.isRegistered<UserService>(),
      'Core services (WordService/UserService) not registered before runApp!',
    );

    debugPrint('🚀 [main] Initializing critical domain services...');
    await _initializeCriticalServices();
    debugPrint('✅ [main] Critical services initialized');
    debugPrint('[boot] Phase-A end ✅');
    debugPrint('[main] runApp(BootApp)');
    runApp(const BootApp());
  } catch (e, st) {
    debugPrint('❌ [main] Critical initialization failed: $e\n$st');
    runApp(const _MinimalErrorApp());
  }
}

/// Hızlı ilk frame için minimal uygulama kabuğu
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  // BootApp kendi MaterialApp'ı içinde gezinmek için yerel navigator key
  final GlobalKey<NavigatorState> _bootNavigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    // Phase-B: start non-critical initializations in background after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('[boot] Phase-B start');
      // No Firebase re-initialization here; Phase-A already did it.
      unawaited(_initializeFirebaseServices());
      unawaited(_initializeFirebaseMessaging());
      unawaited(_initializeNonCriticalServices());

      // Navigate to the fully initialized app after the first frame
      if (!mounted) return;
      _bootNavigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const InitializedApp()),
      );
      debugPrint('[boot] Phase-B end');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _bootNavigatorKey,
      title: 'LexiFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(),
              ),
              SizedBox(height: 12),
              Text('Yükleniyor...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalErrorApp extends StatelessWidget {
  const _MinimalErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Initialization failed.\nPlease restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

Future<void> _initializeFirebaseServices() async {
  // Phase-B services init: no Firebase core re-initialization here
  debugPrint('🔥 Initializing Firebase services...');
  if (Firebase.apps.isEmpty) {
    debugPrint('⚠️ Skipping Firebase services init: Firebase not initialized');
    return;
  }

  // Firebase Crashlytics'i başlat
  debugPrint('📊 Initializing Firebase Crashlytics...');
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  if (kDebugMode) {
    debugPrint('🧠 Bellek izleme etkinleştirildi');
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      Logger.e(
        'Flutter Error',
        details.exception,
        details.stack,
        'FlutterError',
      );
      Logger.logMemoryUsage('Flutter Error Occurred');
    };
  }

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  debugPrint('✅ Crashlytics initialized');

  // Firebase Analytics'i başlat
  debugPrint('📊 Initializing Firebase Analytics...');
  FirebaseAnalytics.instance;
  debugPrint('✅ Analytics initialized');

  // Firebase Remote Config'i başlat
  debugPrint('⚙️ Initializing Firebase Remote Config...');
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ),
  );

  await remoteConfig.setDefaults(const {'fsrs_prompt_ratio': 4});

  try {
    await remoteConfig.fetchAndActivate();
    debugPrint('✅ Remote Config initialized and fetched');
  } catch (e) {
    debugPrint('⚠️ Remote Config fetch failed (using defaults): $e');
  }
}

// Helper functions for category metadata
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Do not re-initialize Firebase here to avoid duplicate-app errors.
  // In background isolate, if Firebase isn't available, skip handling.
  if (Firebase.apps.isEmpty) {
    debugPrint('⚠️ [bg] Firebase not initialized in background isolate; skipping handler');
    return;
  }
}

Future<void> _initializeFirebaseMessaging() async {
  // Phase-B messaging init: Firebase is already initialized in Phase-A
  if (Firebase.apps.isEmpty) {
    debugPrint('⚠️ Skipping messaging init: Firebase not initialized');
    return;
  }
  await NotificationService().init();
  final messaging = FirebaseMessaging.instance;
  try {
    final settings = await messaging.requestPermission();
    debugPrint(
      '[FirebaseMessaging] Permission status: ${settings.authorizationStatus}',
    );
  } catch (e) {
    debugPrint('[FirebaseMessaging] Error requesting permission: $e');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    final payload = message.data.isNotEmpty ? jsonEncode(message.data) : null;
    if (notification != null) {
      await NotificationService().showInstant(
        title: notification.title ?? 'LexiFlow',
        body: notification.body ?? '',
        payload: payload,
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (message.data.isNotEmpty) {
      NotificationService().handleMessageNavigation(message.data);
    }
  });

  try {
    final token = await messaging.getToken();
    if (token != null) {
      debugPrint('[FirebaseMessaging] Token: $token');
    }
  } catch (e) {
    debugPrint('[FirebaseMessaging] Failed to obtain token: $e');
  }

  try {
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && initialMessage.data.isNotEmpty) {
      NotificationService().handleMessageNavigation(initialMessage.data);
    }
  } catch (e) {
    debugPrint('[FirebaseMessaging] Failed to fetch initial message: $e');
  }
}

String _getCategoryName(String categoryKey) {
  const categoryNames = {
    'biology': 'Biyoloji',
    'business': 'İş Dünyası',
    'chemistry': 'Kimya',
    'computer': 'Bilgisayar',
    'economics': 'Ekonomi',
    'geography': 'Coğrafya',
    'history': 'Tarih',
    'literature': 'Edebiyat',
    'mathematics': 'Matematik',
    'medicine': 'Tıp',
    'philosophy': 'Felsefe',
    'physics': 'Fizik',
    'politics': 'Politika',
    'psychology': 'Psikoloji',
    'sociology': 'Sosyoloji',
    'technology': 'Teknoloji',
  };
  return categoryNames[categoryKey] ?? categoryKey.toUpperCase();
}

String _getCategoryIcon(String categoryKey) {
  const categoryIcons = {
    'biology': '🧬',
    'business': '💼',
    'chemistry': '⚗️',
    'computer': '💻',
    'economics': '📈',
    'geography': '🌍',
    'history': '📜',
    'literature': '📚',
    'mathematics': '🔢',
    'medicine': '⚕️',
    'philosophy': '🤔',
    'physics': '⚛️',
    'politics': '🏛️',
    'psychology': '🧠',
    'sociology': '👥',
    'technology': '🔧',
  };
  return categoryIcons[categoryKey] ?? '📖';
}

Future<void> _initializeLocalServices() async {
  // intl paketi için yerel veri formatlarını başlat
  debugPrint('🌍 Initializing locale data...');
  await initializeDateFormatting('tr_TR', null);
  debugPrint('✅ Locale data initialized');

  // Hive'ı başlat
  debugPrint('📦 Initializing Hive...');
  await Hive.initFlutter();
  debugPrint('📦 Registering Hive adapters...');
  Hive.registerAdapter(WordAdapter());
  Hive.registerAdapter(DailyLogAdapter());
  Hive.registerAdapter(UserDataAdapter());
  Hive.registerAdapter(CachedUserDataAdapter());
  await ensureFlashcardsCacheBox();
  debugPrint('✅ Hive initialized');
}

Future<void> _initializeCriticalServices() async {
  // Kritik servisler artık DI locator tarafından yönetiliyor
  debugPrint('🔧 Initializing critical services via DI...');

  final wordService = locator<WordService>();
  await wordService.init();
  debugPrint('✅ WordService initialized');

  final userService = locator<UserService>();
  await userService.init();
  debugPrint('✅ UserService initialized');

  final sessionService = locator<SessionService>();
  sessionService.setUserService(userService);
  await sessionService.initialize();
  debugPrint('✅ SessionService initialized');

  debugPrint('✅ All critical services initialized');
}

Future<void> _initializeNonCriticalServices() async {
  try {
    if (!locator.isRegistered<UserService>()) {
      debugPrint('⚠️ Skipping NonCritical init: UserService not registered');
      return;
    }
    final userService = locator<UserService>();
    userService.updateStreak();

    // AdMob'u başlat (opsiyonel, kritik değil)
    try {
      debugPrint('📱 Initializing AdMob in background...');
      await AdService.initialize();
      debugPrint('✅ AdMob initialized');
    } catch (e) {
      debugPrint('⚠️ AdMob initialization failed (non-critical): $e');
    }

    // Bildirim planlarını uygula (init dahili olarak çağrılır)
    debugPrint('🔔 Applying notification schedules from preferences...');
    final notificationService = NotificationService();
    final currentUserId = locator<SessionService>().currentUser?.uid;
    await notificationService.applySchedulesFromPrefs(userId: currentUserId);
    debugPrint('✅ Notification schedules applied');

    // LearnedWordsService'i başlat
    debugPrint('📚 Initializing LearnedWordsService in background...');
    final learnedWordsService = LearnedWordsService();
    await learnedWordsService.initialize();
    debugPrint('✅ LearnedWordsService initialized');

    // SessionService handles its own non-critical initialization (LeaderboardService, real-time listeners)
    debugPrint('ℹ️ SessionService non-critical services handled internally');

    debugPrint(
      '🎉 All main.dart non-critical services initialized successfully',
    );
  } catch (e) {
    debugPrint('⚠️ Error initializing non-critical services: $e');
  }
}

class InitializedApp extends StatefulWidget {
  const InitializedApp({super.key});

  @override
  State<InitializedApp> createState() => _InitializedAppState();
}

class _InitializedAppState extends State<InitializedApp> {
  late final ThemeProvider _themeProvider;
  late final SessionService _sessionService;
  late final WordService _wordService;
  late final UserService _userService;
  late final MigrationIntegrationService _migrationIntegrationService;
  late final AdService _adService;

  @override
  void initState() {
    super.initState();
    // Resolve DI dependencies in initState to avoid locator access during build
    if (!locator.isRegistered<ThemeProvider>()) {
      debugPrint('❌ [init] ThemeProvider not registered; showing error UI');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const _MinimalErrorApp()),
        );
      });
      return;
    }
    _themeProvider = locator<ThemeProvider>();
    _sessionService = locator<SessionService>();
    _wordService = locator<WordService>();
    _userService = locator<UserService>();
    _migrationIntegrationService = locator<MigrationIntegrationService>();
    _adService = locator<AdService>();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧩 InitializedApp build()');
    // App is considered initialized because main() performed
    // critical initialization before runApp.
    return _buildInitializedApp();
  }

  Widget _buildErrorApp() {
    return MaterialApp(
      title: 'LexiFlow',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('LexiFlow')),
        body: Center(
          child: Text(
            'Initialization failed. Please restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildInitializedApp() {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightSchemeBase =
            lightDynamic ?? lexiflowFallbackLightScheme;
        final ColorScheme darkSchemeBase =
            darkDynamic ?? lexiflowFallbackDarkScheme;

        final lightScheme = blendWithLexiFlowAccent(lightSchemeBase);
        final darkScheme = blendWithLexiFlowAccent(darkSchemeBase);

        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _themeProvider),
            ChangeNotifierProvider.value(value: _sessionService),
            ChangeNotifierProvider(create: (_) => ProfileStatsProvider()),
            ChangeNotifierProvider(create: (_) => AchievementService()),
            ChangeNotifierProvider(create: (_) => SyncStatusProvider()),
            ChangeNotifierProvider(create: (_) => CardsProvider()..loadSets()),
            Provider.value(value: _wordService),
            Provider.value(value: _userService),
            Provider.value(value: _migrationIntegrationService),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'LexiFlow',
                debugShowCheckedModeBanner: false,
                navigatorKey: NotificationService().navigatorKey,
                theme: buildLexiFlowTheme(lightScheme),
                darkTheme: buildLexiFlowTheme(darkScheme),
                themeMode: themeProvider.themeMode,
                home: MobileOnlyGuard(
                  child: AuthWrapper(
                    wordService: _wordService,
                    userService: _userService,
                    migrationIntegrationService:
                        _migrationIntegrationService,
                    adService: _adService,
                  ),
                ),
                routes: {
                  '/splash':
                      (context) => SplashScreen(
                        wordService: _wordService,
                        userService: _userService,
                        migrationIntegrationService:
                            _migrationIntegrationService,
                        adService: _adService,
                      ),
                  '/dashboard':
                      (context) => DashboardScreen(
                        wordService: _wordService,
                        userService: _userService,
                        adService: _adService,
                      ),
                  '/favorites':
                      (context) => FavoritesScreen(
                        wordService: _wordService,
                        userService: _userService,
                        adService: _adService,
                      ),
                  '/daily-challenge':
                      (context) => DailyChallengeScreen(
                        wordService: _wordService,
                        userService: _userService,
                        adService: _adService,
                      ),
                  '/daily-word': (context) => const DailyWordScreen(),
                  '/word-detail': (context) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    if (args is Word) {
                      return WordDetailScreen(word: args);
                    }
                    return const Scaffold(
                      body: Center(child: Text('Word not found')),
                    );
                  },
                  '/profile': (context) => const ProfileScreen(),
                  '/privacy-policy': (context) => const PrivacyPolicyScreen(),
                  '/terms-of-service':
                      (context) => const TermsOfServiceScreen(),
                  '/share-preview':
                      (context) => SharePreviewScreen(
                        userStats: UserStatsModel(
                          level: 1,
                          xp: 0,
                          longestStreak: 0,
                          learnedWords: 0,
                          quizzesCompleted: 0,
                        ),
                      ),
                  '/quiz-center': (context) => const QuizCenterScreen(),
                  '/quiz/general': (context) => const GeneralQuizScreen(),
                  '/quiz/start': (context) {
                    final args =
                        ModalRoute.of(context)?.settings.arguments
                            as Map<String, dynamic>?;
                    return QuizStartScreen(
                      categoryKey: args?['categoryKey'] as String?,
                      categoryName: args?['categoryName'] as String?,
                      categoryIcon: args?['categoryIcon'] as String?,
                    );
                  },
                  '/quiz/play':
                      (context) => CategoryQuizPlayScreen(
                        wordService: _wordService,
                        userService: _userService,
                      ),
                  if (kDebugMode)
                    '/connectivity-debug':
                        (context) => const ConnectivityDebugWidget(),
                },
                onGenerateRoute: (settings) {
                  // Handle dynamic routes like /quiz/category/:key
                  // Commented out - now using QuizTypeSelectScreen flow
                  // if (settings.name?.startsWith('/quiz/category/') == true) {
                  //   final categoryKey = settings.name!.split('/').last;
                  //   return MaterialPageRoute(
                  //     builder: (context) => CategoryQuizScreen(
                  //       category: categoryKey,
                  //       categoryName: _getCategoryName(categoryKey),
                  //       categoryIcon: _getCategoryIcon(categoryKey),
                  //     ),
                  //     settings: settings,
                  //   );
                  // }
                  return null;
                },
                builder: (context, child) {
                  final content = child ?? const SizedBox.shrink();
                  // Wrap the app content with ConnectionStatusWidget which manages
                  // connection notifications and persistent offline indicator.
                  // Place SyncNotificationWidget inside the base Stack so it can
                  // position its overlays at the top.
                  return ConnectionStatusWidget(
                    child: Stack(
                      children: [
                        content,
                        const SyncNotificationWidget(),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class AppInitializationController extends ChangeNotifier {
  bool _isReady = false;
  bool _isInitializing = false;
  Object? _error;
  StackTrace? _stackTrace;

  bool get isReady => _isReady;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  Future<void> initialize() async {
    if (_isReady || _isInitializing) {
      return;
    }
    _isInitializing = true;
    debugPrint('[AppInit] initialization started');

    try {
      // Yield to the scheduler so the first frame can render before heavy work.
      await Future<void>.delayed(Duration.zero);

      // Phase-A already handled Firebase, locator, and critical services.
      // Here we only verify readiness and surface any issues.
      if (Firebase.apps.isEmpty) {
        throw StateError('Firebase not initialized before AppInit');
      }
      if (!locator.isRegistered<UserService>() ||
          !locator.isRegistered<ThemeProvider>() ||
          !locator.isRegistered<SessionService>()) {
        throw StateError('DI not fully configured before AppInit');
      }

      _error = null;
      _stackTrace = null;
      _isReady = true;
      notifyListeners();
      debugPrint('[AppInit] Core initialization complete');

      // Non-critical tasks are already handled in BootApp Phase-B.
    } catch (e, stack) {
      _error = e;
      _stackTrace = stack;
      debugPrint('[AppInit] Initialization error: $e');
      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }
}
