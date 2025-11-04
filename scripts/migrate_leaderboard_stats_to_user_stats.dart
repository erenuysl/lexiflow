import 'dart:io';
// Flutter binding ensures plugins are correctly initialized when running via `flutter pub run`
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// Use package import to avoid fragile relative paths from the scripts/ directory
import 'package:lexiflow/firebase_options.dart';

/// Script: Migrate leaderboard_stats -> users/{uid} with nested stats map
/// - Reads all docs in `leaderboard_stats`
/// - For each doc, if matching `users/{uid}` exists, merges fields:
///   { displayName, avatar, stats: { level, highestLevel, weeklyXp, totalXp,
///     currentStreak, longestStreak, weeklyQuizzes, totalQuizzesCompleted,
///     learnedWordsCount, lastUpdated } }
/// - Uses SetOptions(merge: true)
/// - Validates numeric fields (defaults to 0)
/// - Preserves lastUpdated if available; otherwise serverTimestamp
/// - Skips safely if user doc does not exist
///
/// Run: `dart run scripts/migrate_leaderboard_stats_to_user_stats.dart`
Future<void> main(List<String> args) async {
  // Parse CLI flags: default DRY-RUN unless --apply explicitly provided
  bool dryRun = true;
  if (args.isEmpty) {
    dryRun = true;
  } else if (args.length == 1) {
    final flag = args[0].trim();
    if (flag == '--apply') {
      dryRun = false;
    } else if (flag == '--dry-run') {
      dryRun = true;
    } else {
      _printUsage();
      exit(64);
    }
  } else {
    // Multiple flags or both provided — invalid usage
    _printUsage();
    exit(64);
  }

  if (dryRun) {
    print('🔍 DRY-RUN MODE — no data will be written.');
  } else {
    print('📝 APPLY MODE — Firestore writes enabled.');
  }
  print('🚀 Starting migration: leaderboard_stats -> users/{uid}/stats');

  try {
    // Ensure Flutter bindings are initialized for plugin usage in flutter context
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with explicit options (from firebase_options.dart)
    final opts = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: opts);

    final app = Firebase.app();
    print('✅ Firebase initialized: projectId=${app.options.projectId}, appId=${app.options.appId}');
    print('✅ firebase_options.dart detected and applied');

    final firestore = FirebaseFirestore.instance;

    final leaderboardSnap = await firestore.collection('leaderboard_stats').get();
    print('📋 Found ${leaderboardSnap.docs.length} documents in leaderboard_stats');

    int updatedCount = 0;
    int skippedCount = 0;

    for (final doc in leaderboardSnap.docs) {
      final data = doc.data();
      final uid = doc.id;

      try {
        final userRef = firestore.collection('users').doc(uid);
        final userDoc = await userRef.get();

        if (!userDoc.exists) {
          print('⏭️  Skipping ${uid}: users/${uid} not found');
          skippedCount++;
          continue;
        }

        // Extract and validate fields with safe defaults
        String displayName = (data['displayName'] as String?)?.trim().isNotEmpty == true
            ? data['displayName'] as String
            : 'Anonymous';
        final String? avatar = data['photoURL'] as String?; // can be null

        int _asInt(dynamic v, {int def = 0}) {
          if (v is int) return v;
          if (v is num) return v.toInt();
          return def;
        }

        // Prefer explicit fields; fall back where necessary
        final int level = _asInt(data['level'], def: 1);
        final int highestLevel = data.containsKey('highestLevel')
            ? _asInt(data['highestLevel'], def: level)
            : level;
        final int weeklyXp = _asInt(data['weeklyXp']);
        final int totalXp = _asInt(data['totalXp']);
        final int currentStreak = _asInt(data['currentStreak']);
        final int longestStreak = _asInt(data['longestStreak']);
        final int weeklyQuizzes = _asInt(data['weeklyQuizzes']);
        // totalQuizzesCompleted may be stored as quizzesCompleted in old docs
        final int totalQuizzesCompleted = data.containsKey('totalQuizzesCompleted')
            ? _asInt(data['totalQuizzesCompleted'])
            : _asInt(data['quizzesCompleted']);
        final int learnedWordsCount = data.containsKey('learnedWordsCount')
            ? _asInt(data['learnedWordsCount'])
            : _asInt(data['wordsLearned']);

        final Object lastUpdated = (data['lastUpdated'] is Timestamp)
            ? data['lastUpdated'] as Timestamp
            : FieldValue.serverTimestamp();

        final payload = {
          'displayName': displayName,
          'avatar': avatar,
          'stats': {
            'level': level > 0 ? level : 1,
            'highestLevel': highestLevel > 0 ? highestLevel : (level > 0 ? level : 1),
            'weeklyXp': weeklyXp,
            'totalXp': totalXp,
            'currentStreak': currentStreak,
            'longestStreak': longestStreak,
            'weeklyQuizzes': weeklyQuizzes,
            'totalQuizzesCompleted': totalQuizzesCompleted,
            'learnedWordsCount': learnedWordsCount,
            'lastUpdated': lastUpdated,
          },
        };

        if (dryRun) {
          // DRY-RUN: Print what would be written without performing any writes
          print('🔎 DRY-RUN users/$uid -> would merge:');
          print('  displayName: ${payload['displayName']}');
          print('  avatar: ${payload['avatar']}');
          print('  stats: ${payload['stats']}');
          updatedCount++;
        } else {
          await userRef.set(payload, SetOptions(merge: true));
          updatedCount++;
          print('✅ Updated users/$uid with stats and profile fields');
        }
      } catch (e, st) {
        print('❌ Error migrating $uid: $e');
        print(st);
      }
    }

    if (dryRun) {
      print('✅ DRY-RUN complete: $updatedCount users would be updated successfully.');
    } else {
      print('✅ Migration complete: $updatedCount users updated successfully.');
    }
    print('⏭️  Skipped: $skippedCount users without existing user doc.');
  } catch (e, st) {
    print('❌ Migration failed: $e');
    print(st);
    exit(1);
  }
}

void _printUsage() {
  print('Usage: flutter pub run scripts/migrate_leaderboard_stats_to_user_stats.dart [--dry-run | --apply]');
  print('Default is --dry-run (no writes). Use --apply to enable Firestore writes.');
}