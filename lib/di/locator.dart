// lib/di/locator.dart

import 'package:get_it/get_it.dart';
import 'package:lexiflow/services/category_progress_service.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/session_service.dart';
import '../services/ad_service.dart';
import '../services/network_monitor_service.dart';
import '../services/migration_integration_service.dart';
import '../services/notification_service.dart';
import '../services/learned_words_service.dart';
import '../services/analytics_service.dart';
import '../services/leaderboard_service.dart';
import '../services/sync_manager.dart';
import '../services/connectivity_service.dart';
import '../services/enhanced_session_service.dart';
import '../services/offline_storage_manager.dart';
import '../services/offline_auth_service.dart';
import '../services/remote_config_service.dart';
import '../services/statistics_service.dart';
import '../services/daily_word_service.dart';
import '../services/progress_service.dart';
import '../services/activity_service.dart';
import '../services/srs_service.dart';

import '../providers/theme_provider.dart';

final GetIt locator = GetIt.instance;

/// Initialize all services in the dependency injection container
Future<void> setupLocator() async {
  // Core services - initialized first
  locator.registerLazySingleton<WordService>(() => WordService());
  locator.registerLazySingleton<UserService>(() => UserService());

  // Session service depends on UserService
  locator.registerLazySingleton<SessionService>(() {
    final sessionService = SessionService();
    sessionService.setUserService(locator<UserService>());
    return sessionService;
  });

  // Network and connectivity services
  locator.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(),
  );
  locator.registerLazySingleton<SyncManager>(() => SyncManager());
  locator.registerLazySingleton<NetworkMonitorService>(
    () => NetworkMonitorService(),
  );

  // Storage services
  locator.registerLazySingleton<OfflineStorageManager>(
    () => OfflineStorageManager(),
  );
  locator.registerLazySingleton<OfflineAuthService>(() => OfflineAuthService());

  // Enhanced services
  locator.registerLazySingleton<EnhancedSessionService>(
    () => EnhancedSessionService(),
  );

  // Business logic services
  locator.registerLazySingleton<LearnedWordsService>(
    () => LearnedWordsService(),
  );
  locator.registerLazySingleton<CategoryProgressService>(
    () => CategoryProgressService(),
  );
  locator.registerLazySingleton<LeaderboardService>(() => LeaderboardService());
  locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  locator.registerLazySingleton<StatisticsService>(() => StatisticsService());
  locator.registerLazySingleton<DailyWordService>(() => DailyWordService());
  locator.registerLazySingleton<ProgressService>(() => ProgressService());
  locator.registerLazySingleton<ActivityService>(() => ActivityService());
  locator.registerLazySingleton<SRSService>(() => SRSService());

  // UI services
  locator.registerLazySingleton<AdService>(() => AdService());
  locator.registerLazySingleton<NotificationService>(
    () => NotificationService(),
  );

  // Configuration services
  locator.registerLazySingleton<RemoteConfigService>(
    () => RemoteConfigService(),
  );

  // Migration service
  locator.registerLazySingleton<MigrationIntegrationService>(
    () => MigrationIntegrationService(),
  );

  // Providers
  locator.registerLazySingleton<ThemeProvider>(() => ThemeProvider());

  // Firebase bağımlı servislerin initialization'ı kaldırıldı
  // Bu servisler ilk kullanımda otomatik olarak initialize edilecek
}

/// Reset all services (useful for testing)
void resetLocator() {
  locator.reset();
}
