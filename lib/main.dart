import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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
import 'providers/sync_status_provider.dart';
import 'utils/design_system.dart';
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
import 'screens/quiz_center_screen.dart';
import 'screens/category_quiz_screen.dart';
import 'screens/category_quiz_play_screen.dart';
import 'screens/general_quiz_screen.dart';
import 'screens/quiz_start_screen.dart';
import 'utils/logger.dart';
import 'widgets/connection_status_widget.dart';
import 'widgets/sync_notification_widget.dart';
import 'di/locator.dart';
import 'debug/connectivity_debug.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Firebase güvenli başlatma
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase initialized successfully");
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint("✅ Firebase already initialized");
    } else {
      debugPrint("❌ Firebase initialization error: $e");
      rethrow;
    }
  }

  // Firebase servisleri Firebase core'dan sonra başlat
  await _initializeFirebaseServices();
  
  // Dependency Injection'ı Firebase'den sonra kur
  await setupLocator();
  
  // Hive ve yerel veri servislerini başlat
  await _initializeLocalServices();
  
  // Kritik servisleri başlat
  await _initializeCriticalServices();
  
  // Uygulamayı çalıştır
  runApp(const MyApp());
  
  // Kritik olmayan servisleri arka planda başlat
  debugPrint('I/flutter: [MAIN] Starting non-critical services in background');
  _initializeNonCriticalServices();
}

Future<void> _initializeFirebaseServices() async {
  // Firebase core zaten main()'de initialize edildi
  debugPrint('🔥 Initializing Firebase services...');

  // Firebase Crashlytics'i başlat
  debugPrint('📊 Initializing Firebase Crashlytics...');
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  if (kDebugMode) {
    debugPrint('🧠 Bellek izleme etkinleştirildi');
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      Logger.e('Flutter Error', details.exception, details.stack, 'FlutterError');
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
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: const Duration(hours: 1),
  ));
  
  await remoteConfig.setDefaults(const {
    'fsrs_prompt_ratio': 4,
  });
  
  try {
    await remoteConfig.fetchAndActivate();
    debugPrint('✅ Remote Config initialized and fetched');
  } catch (e) {
    debugPrint('⚠️ Remote Config fetch failed (using defaults): $e');
  }
}

// Helper functions for category metadata
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
    
    // Bildirimleri başlat
    debugPrint('🔔 Initializing NotificationService in background...');
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.applySchedulesFromPrefs();
    debugPrint('✅ NotificationService initialized');

    // LearnedWordsService'i başlat
    debugPrint('📚 Initializing LearnedWordsService in background...');
    final learnedWordsService = LearnedWordsService();
    await learnedWordsService.initialize();
    debugPrint('✅ LearnedWordsService initialized');
    
    // SessionService handles its own non-critical initialization (LeaderboardService, real-time listeners)
    debugPrint('ℹ️ SessionService non-critical services handled internally');
    
    debugPrint('🎉 All main.dart non-critical services initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Error initializing non-critical services: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => locator<ThemeProvider>()),
        ChangeNotifierProvider.value(value: locator<SessionService>()),
        ChangeNotifierProvider(create: (_) => ProfileStatsProvider()),
        ChangeNotifierProvider(create: (_) => AchievementService()),
        ChangeNotifierProvider(create: (_) => SyncStatusProvider()),
        Provider.value(value: locator<WordService>()),
        Provider.value(value: locator<UserService>()),
        Provider.value(value: locator<MigrationIntegrationService>()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'LexiFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: MobileOnlyGuard(child: AuthWrapper(
              wordService: locator<WordService>(),
              userService: locator<UserService>(),
              migrationIntegrationService: locator<MigrationIntegrationService>(),
              adService: locator<AdService>(),
            )),
            routes: {
              '/splash': (context) => SplashScreen(
                wordService: locator<WordService>(),
                userService: locator<UserService>(),
                migrationIntegrationService: locator<MigrationIntegrationService>(),
                adService: locator<AdService>(),
              ),
              '/dashboard': (context) => DashboardScreen(
                wordService: locator<WordService>(),
                userService: locator<UserService>(),
                adService: locator<AdService>(),
              ),
              '/favorites': (context) => FavoritesScreen(
                wordService: locator<WordService>(),
                userService: locator<UserService>(),
                adService: locator<AdService>(),
              ),
              '/daily-challenge': (context) => DailyChallengeScreen(
                wordService: locator<WordService>(),
                userService: locator<UserService>(),
                adService: locator<AdService>(),
              ),
              '/daily-word': (context) => const DailyWordScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/privacy-policy': (context) => const PrivacyPolicyScreen(),
              '/terms-of-service': (context) => const TermsOfServiceScreen(),
              '/share-preview': (context) => SharePreviewScreen(
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
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                return QuizStartScreen(
                  categoryKey: args?['categoryKey'] as String?,
                  categoryName: args?['categoryName'] as String?,
                  categoryIcon: args?['categoryIcon'] as String?,
                );
              },
              '/quiz/play': (context) => CategoryQuizPlayScreen(
                wordService: locator<WordService>(),
                userService: locator<UserService>(),
              ),
              // '/category-quiz': (context) => const CategoryQuizScreen(
              //   category: 'general',
              //   categoryName: 'Genel',
              //   categoryIcon: '📚',
              // ),
              // '/category-quiz-play': (context) => CategoryQuizPlayScreen(
              //   wordService: locator<WordService>(),
              //   userService: locator<UserService>(),
              // ),
              if (kDebugMode) '/connectivity-debug': (context) => const ConnectivityDebugWidget(),
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
              return ConnectionStatusWidget(
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

