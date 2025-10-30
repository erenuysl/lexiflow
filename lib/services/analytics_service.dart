import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../utils/logger.dart';

/// Service for Firebase Analytics integration
class AnalyticsService {
  static const String _tag = 'AnalyticsService';
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Set user ID for analytics and crashlytics (call after sign-in)
  static Future<void> setUserId(String? userId) async {
    try {
      if (userId != null) {
        await _analytics.setUserId(id: userId);
        await _crashlytics.setUserIdentifier(userId);
        Logger.i('User ID set for Analytics and Crashlytics: $userId', _tag);
      }
    } catch (e, stackTrace) {
      Logger.e('Failed to set user ID', e, stackTrace, _tag);
    }
  }

  /// Log quiz started event
  static Future<void> logQuizStarted({
    required String quizType,
    required int wordCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'quiz_started',
        parameters: {
          'quiz_type': quizType,
          'word_count': wordCount,
        },
      );
      Logger.d('Analytics: quiz_started (type: $quizType, words: $wordCount)', _tag);
    } catch (e) {
      Logger.w('Failed to log quiz_started: $e', _tag);
    }
  }

  /// Log favorites quiz started event
  static Future<void> logFavoritesQuizStarted({
    required int favoriteCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'favorites_quiz_started',
        parameters: {
          'favorite_count': favoriteCount,
        },
      );
      Logger.d('Analytics: favorites_quiz_started (count: $favoriteCount)', _tag);
    } catch (e) {
      Logger.w('Failed to log favorites_quiz_started: $e', _tag);
    }
  }

  /// Log quiz completed event
  static Future<void> logQuizCompleted({
    required int accuracy,
    required int earnedXp,
    required int totalQuestions,
    required int correctAnswers,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'quiz_completed',
        parameters: {
          'accuracy': accuracy,
          'earned_xp': earnedXp,
          'total_questions': totalQuestions,
          'correct_answers': correctAnswers,
        },
      );
      Logger.d('Analytics: quiz_completed (accuracy: $accuracy%, xp: $earnedXp)', _tag);
    } catch (e) {
      Logger.w('Failed to log quiz_completed: $e', _tag);
    }
  }

  /// Log custom event
  static Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      Logger.d('Analytics: $name', _tag);
    } catch (e) {
      Logger.w('Failed to log event $name: $e', _tag);
    }
  }

  /// Set user property
  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      Logger.d('User property set: $name = $value', _tag);
    } catch (e) {
      Logger.w('Failed to set user property $name: $e', _tag);
    }
  }
}

