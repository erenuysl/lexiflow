import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../utils/logger.dart';

/// Service for Firebase Remote Config integration
class RemoteConfigService {
  static const String _tag = 'RemoteConfigService';
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// Get FSRS prompt ratio (how often to show quality prompt)
  /// Default: 4 (show every 4th correct answer)
  static int getFsrsPromptRatio() {
    try {
      final value = _remoteConfig.getInt('fsrs_prompt_ratio');
      Logger.d('Remote Config: fsrs_prompt_ratio = $value', _tag);
      return value;
    } catch (e) {
      Logger.w('Failed to get fsrs_prompt_ratio, using default: $e', _tag);
      return 4; // Default fallback
    }
  }

  /// Get any string value from Remote Config
  static String getString(String key, {String defaultValue = ''}) {
    try {
      return _remoteConfig.getString(key);
    } catch (e) {
      Logger.w('Failed to get Remote Config string $key: $e', _tag);
      return defaultValue;
    }
  }

  /// Get any int value from Remote Config
  static int getInt(String key, {int defaultValue = 0}) {
    try {
      return _remoteConfig.getInt(key);
    } catch (e) {
      Logger.w('Failed to get Remote Config int $key: $e', _tag);
      return defaultValue;
    }
  }

  /// Get any bool value from Remote Config
  static bool getBool(String key, {bool defaultValue = false}) {
    try {
      return _remoteConfig.getBool(key);
    } catch (e) {
      Logger.w('Failed to get Remote Config bool $key: $e', _tag);
      return defaultValue;
    }
  }

  /// Get any double value from Remote Config
  static double getDouble(String key, {double defaultValue = 0.0}) {
    try {
      return _remoteConfig.getDouble(key);
    } catch (e) {
      Logger.w('Failed to get Remote Config double $key: $e', _tag);
      return defaultValue;
    }
  }

  /// Fetch and activate new values
  static Future<bool> fetchAndActivate() async {
    try {
      final activated = await _remoteConfig.fetchAndActivate();
      Logger.i('Remote Config fetched and activated: $activated', _tag);
      return activated;
    } catch (e, stackTrace) {
      Logger.e('Failed to fetch Remote Config', e, stackTrace, _tag);
      return false;
    }
  }
}

