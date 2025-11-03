// lib/di/locator.dart

import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
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
  debugPrint('[locator] setup start');
  
  // Core services - initialized first (idempotent registration)
  if (!locator.isRegistered<ThemeProvider>()) {
    locator.registerLazySingleton<ThemeProvider>(() => ThemeProvider());
    debugPrint('[locator] ThemeProvider registered');
  }

  if (!locator.isRegistered<UserService>()) {
    locator.registerLazySingleton<UserService>(() => UserService());
    debugPrint('[locator] UserService registered');
  }

  if (!locator.isRegistered<SessionService>()) {
    locator.registerLazySingleton<SessionService>(() => SessionService());
    debugPrint('[locator] SessionService registered');
  }

  if (!locator.isRegistered<WordService>()) {
    locator.registerLazySingleton<WordService>(() => WordService());
    debugPrint('[locator] WordService registered');
  }

  // Network and connectivity services
  if (!locator.isRegistered<ConnectivityService>()) {
    locator.registerLazySingleton<ConnectivityService>(
      () => ConnectivityService(),
    );
    debugPrint('🧩 [locator] ConnectivityService registered');
  }
  if (!locator.isRegistered<SyncManager>()) {
    locator.registerLazySingleton<SyncManager>(() => SyncManager());
    debugPrint('🧩 [locator] SyncManager registered');
  }
  if (!locator.isRegistered<NetworkMonitorService>()) {
    locator.registerLazySingleton<NetworkMonitorService>(
      () => NetworkMonitorService(),
    );
    debugPrint('🧩 [locator] NetworkMonitorService registered');
  }

  // Storage services
  if (!locator.isRegistered<OfflineStorageManager>()) {
    locator.registerLazySingleton<OfflineStorageManager>(
      () => OfflineStorageManager(),
    );
    debugPrint('🧩 [locator] OfflineStorageManager registered');
  }
  if (!locator.isRegistered<OfflineAuthService>()) {
    locator.registerLazySingleton<OfflineAuthService>(() => OfflineAuthService());
    debugPrint('🧩 [locator] OfflineAuthService registered');
  }

  // Enhanced services
  if (!locator.isRegistered<EnhancedSessionService>()) {
    locator.registerLazySingleton<EnhancedSessionService>(
      () => EnhancedSessionService(),
    );
    debugPrint('🧩 [locator] EnhancedSessionService registered');
  }

  // Business logic services
  if (!locator.isRegistered<LearnedWordsService>()) {
    locator.registerLazySingleton<LearnedWordsService>(
      () => LearnedWordsService(),
    );
    debugPrint('🧩 [locator] LearnedWordsService registered');
  }
  if (!locator.isRegistered<CategoryProgressService>()) {
    locator.registerLazySingleton<CategoryProgressService>(
      () => CategoryProgressService(),
    );
    debugPrint('🧩 [locator] CategoryProgressService registered');
  }
  if (!locator.isRegistered<LeaderboardService>()) {
    locator.registerLazySingleton<LeaderboardService>(() => LeaderboardService());
    debugPrint('🧩 [locator] LeaderboardService registered');
  }
  if (!locator.isRegistered<AnalyticsService>()) {
    locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
    debugPrint('🧩 [locator] AnalyticsService registered');
  }
  if (!locator.isRegistered<StatisticsService>()) {
    locator.registerLazySingleton<StatisticsService>(() => StatisticsService());
    debugPrint('🧩 [locator] StatisticsService registered');
  }
  if (!locator.isRegistered<DailyWordService>()) {
    locator.registerLazySingleton<DailyWordService>(() => DailyWordService());
    debugPrint('🧩 [locator] DailyWordService registered');
  }
  if (!locator.isRegistered<ProgressService>()) {
    locator.registerLazySingleton<ProgressService>(() => ProgressService());
    debugPrint('🧩 [locator] ProgressService registered');
  }
  if (!locator.isRegistered<ActivityService>()) {
    locator.registerLazySingleton<ActivityService>(() => ActivityService());
    debugPrint('🧩 [locator] ActivityService registered');
  }
  if (!locator.isRegistered<SRSService>()) {
    locator.registerLazySingleton<SRSService>(() => SRSService());
    debugPrint('🧩 [locator] SRSService registered');
  }

  // UI services
  if (!locator.isRegistered<AdService>()) {
    locator.registerLazySingleton<AdService>(() => AdService());
    debugPrint('🧩 [locator] AdService registered');
  }
  if (!locator.isRegistered<NotificationService>()) {
    locator.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );
    debugPrint('🧩 [locator] NotificationService registered');
  }

  // Configuration services
  if (!locator.isRegistered<RemoteConfigService>()) {
    locator.registerLazySingleton<RemoteConfigService>(
      () => RemoteConfigService(),
    );
    debugPrint('🧩 [locator] RemoteConfigService registered');
  }

  // Migration service
  if (!locator.isRegistered<MigrationIntegrationService>()) {
    locator.registerLazySingleton<MigrationIntegrationService>(
      () => MigrationIntegrationService(),
    );
    debugPrint('🧩 [locator] MigrationIntegrationService registered');
  }



  // Firebase bağımlı servislerin initialization'ı kaldırıldı
  // Bu servisler ilk kullanımda otomatik olarak initialize edilecek
  debugPrint('[locator] setup complete');
}

/// Reset all services (useful for testing)
void resetLocator() {
  locator.reset();
}
