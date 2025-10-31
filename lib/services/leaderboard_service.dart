// lib/services/leaderboard_service.dart
// Leaderboard Service with Firestore Integration

// ✅ FIRESTORE INDEX - HIÇ GEREKMESİN!
// ================================
// 🎉 MÜJDE: Tüm leaderboard metodları SADECE TEK FIELD kullanıyor!
// 🚀 Composite index'lere gerek YOK - Firestore otomatik indexler yeterli!
//
// Collection: leaderboard_stats
//
// ✅ KULLANILAN FIELD'LAR (Otomatik indexlenir):
//   - weeklyXp (Descending only)
//   - currentLevel (Descending only)
//   - highestLevel (Descending only)
//   - currentStreak (Descending only)
//   - totalQuizzesCompleted (Descending only)
//
// 📌 NOT: lastUpdated ile çoklu sıralama KALDIRILDI!
//       Tek field sıralama = Otomatik index = HIÇ HATA YOK!
// ================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/leaderboard_user.dart';
import '../utils/logger.dart';
import 'level_service.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore;

  // Cache for offline support with improved management
  final Map<String, List<LeaderboardUser>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5); // ✅ Increased from 30 seconds to 5 minutes for better performance
  
  // Note: _localCache removed (unused).

  // Dependency-injected Firestore constructor
  LeaderboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get leaderboard for a specific type
  Future<List<LeaderboardUser>> getLeaderboard(
    String leaderboardType,
    String currentUserId, {
    int limit = 100,
  }) async {
    try {
      // cache kontrolü
      if (_isCacheValid(leaderboardType)) {
        debugPrint('📦 Returning cached leaderboard for $leaderboardType');
        return _cache[leaderboardType]!;
      }

      final type = LeaderboardType.fromId(leaderboardType);
      final metric = type.metric;

      final snapshot = await _firestore
          .collection('leaderboard_stats')
          .orderBy(metric, descending: true)
          .limit(limit)
          .get();

      final users = <LeaderboardUser>[];
      for (var i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        try {
          final user = LeaderboardUser.fromFirestore(doc, currentUserId);
          users.add(user.copyWith(rank: i + 1));
        } catch (e, st) {
          Logger.e('getLeaderboard failed to parse document ${doc.id}', e, st);
        }
      }

      // cache güncelle
      _cache[leaderboardType] = users;
      _cacheTimestamps[leaderboardType] = DateTime.now();

      return users;
    } catch (e) {
      debugPrint('❌ Error loading leaderboard: $e');
      // hata durumunda eski cache döndür
      if (_cache.containsKey(leaderboardType)) {
        debugPrint('📦 Returning stale cache due to error');
        return _cache[leaderboardType]!;
      }
      return [];
    }
  }

  /// Get leaderboard stream for realtime updates
  Stream<List<LeaderboardUser>> getLeaderboardStream(
    String leaderboardType,
    String currentUserId, {
    int limit = 100,
  }) {
    final type = LeaderboardType.fromId(leaderboardType);
    final metric = type.metric;

    final stream = _firestore
        .collection('leaderboard_stats')
        .orderBy(metric, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final users = <LeaderboardUser>[];
          for (var i = 0; i < snapshot.docs.length; i++) {
            final doc = snapshot.docs[i];
            try {
              final user = LeaderboardUser.fromFirestore(doc, currentUserId);
              users.add(user.copyWith(rank: i + 1));
            } catch (e, st) {
              Logger.e('getLeaderboardStream failed to parse document ${doc.id}', e, st);
            }
          }

          // Update cache
          _cache[leaderboardType] = users;
          _cacheTimestamps[leaderboardType] = DateTime.now();

          return users;
        })
        .handleError((e, st) {
          Logger.e('getLeaderboardStream encountered error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            // timeout durumunda cache veya boş liste döndür
            final fallback = _cache[leaderboardType] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );

    return stream;
  }

  // ==========================================
  // 8 SEPARATE LEADERBOARD STREAMS
  // ==========================================

  /// WEEKLY LEADERBOARDS
  Stream<List<LeaderboardUser>> getWeeklyXpLeaders(
    String currentUserId, {
    int limit = 20,
  }) {
    debugPrint('WEEKLY XP: ordering by weeklyXp');
    print('📍 TRACE: Reading from collection path: leaderboard_stats');
    return _firestore
        .collection('leaderboard_stats')
        .orderBy('weeklyXp', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) {
          print("📡 Firestore snapshot received (fromCache=${snapshot.metadata.isFromCache}, pendingWrites=${snapshot.metadata.hasPendingWrites})");
          print("🔥 Stream triggered rebuild at ${DateTime.now()} with ${snapshot.docs.length} docs");
          
          // Log each document's data
          for (var i = 0; i < snapshot.docs.length; i++) {
            final doc = snapshot.docs[i];
            print("📊 Firestore doc data [${doc.id}]: ${doc.data()}");
          }
          
          return _mergeWithUserStats(
            snapshot,
            currentUserId,
            metricField: 'weeklyXp',
          );
        })
        .handleError((e, st) {
          Logger.e('getWeeklyXpLeaders stream error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            final fallback = _cache['weekly_xp'] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );
  }

  Stream<List<LeaderboardUser>> getWeeklyStreakLeaders(
    String currentUserId, {
    int limit = 20,
  }) {
    debugPrint('🔥 WEEKLY STREAK: Using ONLY currentStreak (NO INDEX NEEDED)');
    print('📍 TRACE: Reading from collection path: leaderboard_stats');
    return _firestore
        .collection('leaderboard_stats')
        .orderBy('currentStreak', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) {
          print("📡 Firestore snapshot received (fromCache=${snapshot.metadata.isFromCache}, pendingWrites=${snapshot.metadata.hasPendingWrites})");
          print("🔥 Stream triggered rebuild at ${DateTime.now()} with ${snapshot.docs.length} docs");
          
          // Log each document's data
          for (var i = 0; i < snapshot.docs.length; i++) {
            final doc = snapshot.docs[i];
            print("📊 Firestore doc data [${doc.id}]: ${doc.data()}");
          }
          
          return _mergeWithUserStats(
            snapshot,
            currentUserId,
            metricField: 'currentStreak',
          );
        })
        .handleError((e, st) {
          Logger.e('getWeeklyStreakLeaders stream error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            final fallback = _cache['current_streak'] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );
  }

  Stream<List<LeaderboardUser>> getWeeklyQuizLeaders(
    String currentUserId, {
    int limit = 20,
  }) {
    debugPrint('🧠 WEEKLY QUIZ: Using ONLY quizzesCompleted (NO INDEX NEEDED)');
    print('📍 TRACE: Reading from collection path: leaderboard_stats');
    return _firestore
        .collection('leaderboard_stats')
        .orderBy('quizzesCompleted', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) {
          print("📡 Firestore snapshot received (fromCache=${snapshot.metadata.isFromCache}, pendingWrites=${snapshot.metadata.hasPendingWrites})");
          print("🔥 Stream triggered rebuild at ${DateTime.now()} with ${snapshot.docs.length} docs");
          
          // Log each document's data
          for (var i = 0; i < snapshot.docs.length; i++) {
            final doc = snapshot.docs[i];
            print("📊 Firestore doc data [${doc.id}]: ${doc.data()}");
          }
          
          return _mergeWithUserStats(
            snapshot,
            currentUserId,
            metricField: 'quizzesCompleted',
          );
        })
        .handleError((e, st) {
          Logger.e('getWeeklyQuizLeaders stream error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            final fallback = _cache['weekly_quiz'] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );
  }

  Stream<List<LeaderboardUser>> getWeeklyLevelLeaders(
    String currentUserId, {
    int limit = 20,
  }) {
    debugPrint('🏆 WEEKLY LEVEL: Using level field for leaderboard');
    return _firestore
        .collection('leaderboard_stats')
        .orderBy('level', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) => _mergeWithUserStats(
              snapshot,
              currentUserId,
              metricField: 'level',
            ))
        .handleError((e, st) {
          Logger.e('getWeeklyLevelLeaders stream error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            final fallback = _cache['current_level'] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );
  }

  /// ALL-TIME LEADERBOARDS

  Stream<List<LeaderboardUser>> getAllTimeStreakLeaders(
    String currentUserId, {
    int limit = 20,
  }) {
    debugPrint(
      '🔥 ALL-TIME STREAK: Using ONLY longestStreak (NO INDEX NEEDED)',
    );
    return _firestore
        .collection('leaderboard_stats')
        .orderBy('longestStreak', descending: true) // longestStreak kullan
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) => _mergeWithUserStats(
              snapshot,
              currentUserId,
              metricField: 'longestStreak',
            ))
        .handleError((e, st) {
          Logger.e('getAllTimeStreakLeaders stream error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            final fallback = _cache['all_time_streak'] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );
  }

  Stream<List<LeaderboardUser>> getAllTimeQuizLeaders(
    String currentUserId, {
    int limit = 20,
  }) {
    debugPrint(
      '🧠 ALL-TIME QUIZ: Using ONLY totalQuizzesCompleted (NO INDEX NEEDED)',
    );
    return _firestore
        .collection('leaderboard_stats')
        .orderBy('totalQuizzesCompleted', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) => _mergeWithUserStats(
              snapshot,
              currentUserId,
              // model tutarlılığı için client-side sıralama
              metricField: 'quizzesCompleted',
            ))
        .handleError((e, st) {
          Logger.e('getAllTimeQuizLeaders stream error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            final fallback = _cache['all_time_quiz'] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );
  }

  Stream<List<LeaderboardUser>> getAllTimeLevelLeaders(
    String currentUserId, {
    int limit = 20,
  }) {
    debugPrint('🏆 ALL-TIME LEVEL: Using ONLY highestLevel (NO INDEX NEEDED)');
    return _firestore
        .collection('leaderboard_stats')
        .orderBy('highestLevel', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) => _mergeWithUserStats(
              snapshot,
              currentUserId,
              metricField: 'highestLevel',
            ))
        .handleError((e, st) {
          Logger.e('getAllTimeLevelLeaders stream error', e, st);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            final fallback = _cache['all_time_level'] ?? <LeaderboardUser>[];
            sink.add(fallback);
          },
        );
  }

  /// Helper method to map snapshot to leaderboard users
  Future<List<LeaderboardUser>> _mergeWithUserStats(
    QuerySnapshot snapshot,
    String currentUserId, {
    required String metricField,
  }) async {
    final futures = snapshot.docs.asMap().entries.map<Future<LeaderboardUser>>((entry) async {
      final index = entry.key;
      final doc = entry.value;
      final rawData = doc.data();
      if (rawData is! Map<String, dynamic>) {
        Logger.w(
          'mergeWithUserStats: unexpected doc.data type for ${doc.id}',
        );
      }
      final data = (rawData is Map<String, dynamic>)
          ? rawData
          : <String, dynamic>{};
      // users/{id} canlı dokümanını getir
      Map<String, dynamic>? live;
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(doc.id)
            .get();
        live = userDoc.data();
      } catch (e, st) {
        Logger.e('mergeWithUserStats: failed to read live stats for ${doc.id}', e, st);
      }

      // birleştir - LevelService kullanarak level hesapla
      final totalXp = (data['totalXp'] is int) ? data['totalXp'] : 0;
      final levelData = LevelService.computeLevelData(totalXp);
      final calculatedLevel = levelData.level;
      
      // migration için eski level değerlerini kontrol et
      final rawLevel = data['level'];
      final rawCurrentLevel = live?['currentLevel'] ?? data['currentLevel'];
      
      // level field null ise debug print ve otomatik güncelleme
      if (rawLevel == null) {
        debugPrint('Level field: null for user ${doc.id}, using calculated level: $calculatedLevel');
        
        // level field'ını otomatik güncelle
        updateUserStats(
          doc.id,
          level: calculatedLevel,
        );
      }
      
      final storedLevel = rawLevel is int ? rawLevel : (rawCurrentLevel is int ? rawCurrentLevel : 1);
      
      // hesaplanan level ile saklanan level arasında fark varsa log'la
      if (calculatedLevel != storedLevel) {
        Logger.w('Level mismatch for user ${doc.id}: calculated=$calculatedLevel, stored=$storedLevel, totalXp=$totalXp');
      }
      
      final level = calculatedLevel; // LevelService hesaplamasını kullan
      
      final highLvl = (data['highestLevel'] ?? 0);
      final safeHighLvl = (highLvl is int) ? highLvl : 0;
      final mergedHighest = safeHighLvl > level ? safeHighLvl : level;

      final curStreak = (live?['currentStreak'] ?? data['currentStreak'] ?? 0);
      final longStreak = (data['longestStreak'] ?? 0);
      final liveLongest = (live?['longestStreak'] ?? 0);
      final computedLongest = live != null
          ? _calcLongestFromActivity(live)
          : 0;
      final safeCurStreak = (curStreak is int) ? curStreak : 0;
      final safeLongStreak = (longStreak is int) ? longStreak : 0;
      final safeLiveLongest = (liveLongest is int) ? liveLongest : 0;
      final mergedLongest = [
        safeLongStreak,
        safeCurStreak,
        safeLiveLongest,
        computedLongest,
      ].reduce((a, b) => a > b ? a : b);

      var qc = data['quizzesCompleted'];
      if (qc == null && live?['totalQuizzesCompleted'] != null) {
        qc = live!['totalQuizzesCompleted'];
      }
      final safeQc = (qc is int) ? qc : 0;

      final user = LeaderboardUser(
        userId: doc.id,
        displayName: (data['displayName'] is String)
            ? data['displayName']
            : 'Anonymous',
        photoURL: data['photoURL'],
        level: level,
        highestLevel: mergedHighest,
        totalXp: totalXp, // önceden hesaplanan totalXp değerini kullan
        weeklyXp: (data['weeklyXp'] is int) ? data['weeklyXp'] : 0,
        currentStreak: safeCurStreak,
        longestStreak: mergedLongest,
        quizzesCompleted: safeQc,
        learnedWordsCount: (data['learnedWordsCount'] is int) ? data['learnedWordsCount'] : 
                          (data['wordsLearned'] is int) ? data['wordsLearned'] : 0, // fallback for migration
        rank: (index + 1),
        previousRank:
            (data['previousRank'] is int) ? data['previousRank'] : null,
        lastUpdated: DateTime.now(),
        isCurrentUser: doc.id == currentUserId,
      );

      return user;
    });

    final users = await Future.wait(futures);
    // istenen metricField'a göre sırala (desc) - canlı değerleri UI'da hemen yansıt
    int metricOf(LeaderboardUser u) => _metricOf(u, metricField);
    users.sort((a, b) => metricOf(b).compareTo(metricOf(a)));
    // sıralama sonrası rank'leri yeniden ata
    for (var i = 0; i < users.length; i++) {
      users[i] = users[i].copyWith(rank: i + 1);
    }
    return users;
  }

  static int _calcLongestFromActivity(Map<String, dynamic> live) {
    final activity = live['dailyActivity'];
    if (activity is! Map) return 0;
    // tamamlanmış günleri temsil eden tarih anahtarlarını topla
    final dates = <DateTime>[];
    for (final entry in activity.entries) {
      final key = entry.key;
      final val = entry.value;
      if (key is String) {
        // YYYY-MM-DD gibi formatları kabul et
        try {
          final parts = key.split('-');
          if (parts.length == 3) {
            final dt = DateTime.utc(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            // değer map ise truthy flag kontrol et, bool ise direkt kullan
            bool done = true;
            if (val is Map) {
              final d = val['done'] ?? val['completed'] ?? true;
              if (d is bool) {
                done = d;
              } else {
                done = true;
              }
            } else if (val is bool) {
              done = val;
            }
            if (done) dates.add(dt);
          }
        } catch (_) {
          // parse hatalarını yoksay
        }
      }
    }
    if (dates.isEmpty) return 0;
    dates.sort();
    int best = 1;
    int cur = 1;
    for (int i = 1; i < dates.length; i++) {
      final prev = dates[i - 1];
      final curr = dates[i];
      if (curr.difference(prev).inDays == 1) {
        cur += 1;
      } else if (curr.isAtSameMomentAs(prev)) {
        // aynı gün duplikatı, yoksay
      } else {
        if (cur > best) best = cur;
        cur = 1;
      }
    }
    if (cur > best) best = cur;
    return best;
  }

  // Visible for testing helpers
  @visibleForTesting
  static int computeLongestStreakFromActivity(Map<String, dynamic> live) {
    return _calcLongestFromActivity(live);
  }

  @visibleForTesting
  static List<LeaderboardUser> sortUsersByMetric(
    List<LeaderboardUser> users,
    String metricField,
  ) {
    final sorted = List<LeaderboardUser>.from(users);
    sorted.sort((a, b) => _metricOf(b, metricField).compareTo(
          _metricOf(a, metricField),
        ));
    return sorted;
  }

  static int _metricOf(LeaderboardUser u, String metricField) {
    switch (metricField) {
      case 'weeklyXp':
        return u.weeklyXp;
      case 'currentStreak':
        return u.currentStreak;
      case 'quizzesCompleted':
      case 'totalQuizzesCompleted': // legacy external name
        return u.quizzesCompleted;
      case 'level':
      case 'currentLevel': // legacy support
        return u.level;
      case 'longestStreak':
        return u.longestStreak;
      case 'highestLevel':
        return u.highestLevel;
      case 'learnedWordsCount':
        return u.learnedWordsCount;
      default:
        return 0;
    }
  }

  /// Get user's rank in a specific leaderboard
  Future<int?> getUserRank(String userId, String leaderboardType) async {
    try {
      final type = LeaderboardType.fromId(leaderboardType);
      final metric = type.metric;

      // Get user's stats
      DocumentSnapshot<Map<String, dynamic>> userDoc;
      try {
        userDoc = await _firestore
            .collection('leaderboard_stats')
            .doc(userId)
            .get();
      } catch (e, st) {
        Logger.e('getUserRank failed to read user doc', e, st);
        return null;
      }

      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final userMetricValueRaw = userData[metric] ?? 0;
      final userMetricValue =
          (userMetricValueRaw is int) ? userMetricValueRaw : 0;

      // Count how many users have better stats
      AggregateQuerySnapshot betterUsersCount;
      try {
        betterUsersCount = await _firestore
            .collection('leaderboard_stats')
            .where(metric, isGreaterThan: userMetricValue)
            .count()
            .get();
      } catch (e, st) {
        Logger.e('getUserRank count query failed', e, st);
        return null;
      }

      return betterUsersCount.count! + 1;
    } catch (e) {
      debugPrint('❌ Error getting user rank: $e');
      return null;
    }
  }

  /// Update user stats (called after XP gain, quiz completion, etc.)
  Future<void> updateUserStats(
    String userId, {
    int? xpEarned,
    int? quizzesCompleted,
    int? currentStreak,
    int? level, // standardized level field
    int? learnedWordsCount,
    String? displayName,
    String? photoURL,
    bool forceSync = false,
  }) async {
    try {
      final docRef = _firestore.collection('leaderboard_stats').doc(userId);
      
      // transaction ile atomik güncelleme
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          // Create new stats document
          transaction.set(docRef, {
            'userId': userId,
            'displayName': displayName ?? 'Anonymous',
            'photoURL': photoURL,
            'level': level ?? 1, // standardized level field
            'highestLevel': level ?? 1,
            'totalXp': xpEarned ?? 0,
            'weeklyXp': xpEarned ?? 0,
            'currentStreak': currentStreak ?? 1,
            'longestStreak': currentStreak ?? 1,
            'quizzesCompleted': quizzesCompleted ?? 0,
            'weeklyQuizzes': quizzesCompleted ?? 0,
            'learnedWordsCount': learnedWordsCount ?? 0,
            'lastUpdated': FieldValue.serverTimestamp(),
            'lastActiveDate': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
            'weekResetDate': _getNextMondayMidnight(),
          }, SetOptions(merge: true));
          
          debugPrint('✅ Created leaderboard stats for $userId');
          return;
        }
        
        // Update existing stats
        final updates = <String, dynamic>{
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (xpEarned != null) {
          updates['totalXp'] = FieldValue.increment(xpEarned);
          updates['weeklyXp'] = FieldValue.increment(xpEarned);
        }

        if (quizzesCompleted != null) {
          updates['quizzesCompleted'] = FieldValue.increment(quizzesCompleted);
          updates['weeklyQuizzes'] = FieldValue.increment(quizzesCompleted);
        }

        // streak hesaplama mantığı
        final data = doc.data()!;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        final lastActiveDateTimestamp = data['lastActiveDate'] as Timestamp?;
        final lastActiveDate = lastActiveDateTimestamp?.toDate();
        
        int calculatedCurrentStreak = data['currentStreak'] ?? 0;
        final existingLongestRaw = data['longestStreak'] ?? 0;
        final existingLongestStreak = (existingLongestRaw is int) ? existingLongestRaw : 0;
        
        if (lastActiveDate != null) {
          final lastActiveDateNormalized = DateTime(lastActiveDate.year, lastActiveDate.month, lastActiveDate.day);
          final daysDiff = today.difference(lastActiveDateNormalized).inDays;
          
          if (daysDiff == 1) {
            calculatedCurrentStreak += 1;
          } else if (daysDiff > 1) {
            calculatedCurrentStreak = 1;
          }
        } else {
          calculatedCurrentStreak = 1;
        }
        
        final finalCurrentStreak = currentStreak ?? calculatedCurrentStreak;
        updates['currentStreak'] = finalCurrentStreak;
        updates['lastActiveDate'] = today;
        
        if (finalCurrentStreak > existingLongestStreak) {
          updates['longestStreak'] = finalCurrentStreak;
        }

        if (level != null) {
          updates['level'] = level;
          final existingHighestRaw = data['highestLevel'] ?? level;
          final existingHighestLevel = (existingHighestRaw is int) ? existingHighestRaw : (level);
          if (level > existingHighestLevel) {
            updates['highestLevel'] = level;
          }
        }

        if (learnedWordsCount != null) {
          updates['learnedWordsCount'] = FieldValue.increment(learnedWordsCount);
        }

        if (displayName != null) {
          updates['displayName'] = displayName;
        }

        if (photoURL != null) {
          updates['photoURL'] = photoURL;
        }

        transaction.update(docRef, updates);
        debugPrint('✅ Updated leaderboard stats for $userId');
      });

      // Clear local cache to force refresh
      _cache.clear();
      _cacheTimestamps.clear();
      
      // 🔥 BROADCAST UPDATE: Notify other services about leaderboard changes
      debugPrint('📡 Leaderboard stats updated - cache cleared for user $userId');
      
    } catch (e) {
      debugPrint('❌ Error updating user stats: $e');
    }
  }

  /// Reset weekly leaderboards (should be called every Monday at 00:00 UTC)
  Future<void> resetWeeklyLeaderboards() async {
    try {
      debugPrint('🔄 Resetting weekly leaderboards...');

      final batch = _firestore.batch();
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore.collection('leaderboard_stats').get();
      } catch (e, st) {
        Logger.e('resetWeeklyLeaderboards failed to fetch stats', e, st);
        return;
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final currentStreak = data['currentStreak'] ?? 0;
        final longestStreak = data['longestStreak'] ?? 0;
        
        // streak doğrulama için debug logları
        debugPrint('📊 User ${doc.id} - Before reset: currentStreak=$currentStreak, longestStreak=$longestStreak');
        
        batch.update(doc.reference, {
          // sadece haftalık alanları sıfırla (XP, quiz, kelime) - currentStreak'i koru
          'weeklyXp': 0,
          'quizzesCompleted': 0, // haftalık quiz sayısını sıfırla
          'weeklyQuizzes': 0, // haftalık quiz sayısını sıfırla (yeni alan)
          'learnedWordsCount': 0, // haftalık kelime sayısını sıfırla
          // önemli: currentStreak'i sıfırlama - gün bazlı, hafta bazlı değil
          // 'currentStreak': korundu (devam eden streak haftalar boyunca devam eder)
          // 'longestStreak': korundu (tüm zamanların rekoru asla sıfırlanmaz)
          // tüm zamanların rekorlarını koru (longestStreak, highestLevel, totalXp)
          'weekResetDate': _getNextMondayMidnight(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        // 🔥 DEBUG LOGS after reset
        debugPrint('✅ Weekly fields reset - currentStreak: $currentStreak (preserved)');
        debugPrint('🏆 All-time Streak: $longestStreak (preserved)');
      }

      try {
        await batch.commit();
      } catch (e, st) {
        Logger.e('resetWeeklyLeaderboards batch commit failed', e, st);
        return;
      }
      debugPrint('✅ Weekly leaderboards reset successfully');

      // Clear cache
      _cache.clear();
      _cacheTimestamps.clear();
    } catch (e) {
      debugPrint('❌ Error resetting weekly leaderboards: $e');
    }
  }

  /// Check if weekly reset is needed
  Future<bool> checkAndResetWeeklyIfNeeded() async {
    try {
      final now = DateTime.now().toUtc();

      // Check if it's Monday and past midnight
      if (now.weekday != DateTime.monday) return false;

      // Get a sample user to check last reset date
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('leaderboard_stats')
            .limit(1)
            .get();
      } catch (e, st) {
        Logger.e('checkAndResetWeeklyIfNeeded failed to fetch sample', e, st);
        return false;
      }

      if (snapshot.docs.isEmpty) return false;

      final data = snapshot.docs.first.data();
      final ts = data['weekResetDate'];
      final weekResetDate =
          (ts is Timestamp) ? ts.toDate() : null;

      if (weekResetDate == null) {
        await resetWeeklyLeaderboards();
        return true;
      }

      // If reset date has passed, reset
      if (now.isAfter(weekResetDate)) {
        await resetWeeklyLeaderboards();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking weekly reset: $e');
      return false;
    }
  }

  /// Get top 3 users for a leaderboard type
  Future<List<LeaderboardUser>> getTop3(
    String leaderboardType,
    String currentUserId,
  ) async {
    final users = await getLeaderboard(
      leaderboardType,
      currentUserId,
      limit: 3,
    );
    return users.take(3).toList();
  }

  /// Get user's position and nearby users
  Future<Map<String, dynamic>> getUserPositionWithContext(
    String userId,
    String leaderboardType,
  ) async {
    try {
      final rank = await getUserRank(userId, leaderboardType);
      if (rank == null) {
        return {'rank': null, 'nearbyUsers': <LeaderboardUser>[]};
      }

      // Get users around the current user (2 above, 2 below)
      final allUsers = await getLeaderboard(
        leaderboardType,
        userId,
        limit: 100,
      );

      final userIndex = allUsers.indexWhere((u) => u.userId == userId);
      if (userIndex == -1) {
        return {'rank': rank, 'nearbyUsers': <LeaderboardUser>[]};
      }

      final start = (userIndex - 2).clamp(0, allUsers.length);
      final end = (userIndex + 3).clamp(0, allUsers.length);
      final nearbyUsers = allUsers.sublist(start, end);

      return {
        'rank': rank,
        'nearbyUsers': nearbyUsers,
        'totalUsers': allUsers.length,
      };
    } catch (e) {
      debugPrint('❌ Error getting user position: $e');
      return {'rank': null, 'nearbyUsers': <LeaderboardUser>[]};
    }
  }

  /// Check cache validity
  bool _isCacheValid(String leaderboardType) {
    if (!_cache.containsKey(leaderboardType)) return false;
    if (!_cacheTimestamps.containsKey(leaderboardType)) return false;

    final cacheAge = DateTime.now().difference(
      _cacheTimestamps[leaderboardType]!,
    );
    return cacheAge < _cacheExpiry;
  }

  /// Get next Monday at midnight Istanbul time (UTC+3)
  DateTime _getNextMondayMidnight() {
    // Istanbul timezone: UTC+3
    final istanbulOffset = const Duration(hours: 3);
    final nowIstanbul = DateTime.now().toUtc().add(istanbulOffset);

    var daysUntilMonday = DateTime.monday - nowIstanbul.weekday;
    if (daysUntilMonday <= 0) daysUntilMonday += 7;

    final nextMondayIstanbul = DateTime(
      nowIstanbul.year,
      nowIstanbul.month,
      nowIstanbul.day + daysUntilMonday,
      0,
      0,
      0,
    );

    // Convert back to UTC for Firestore
    return nextMondayIstanbul.subtract(istanbulOffset).toUtc();
  }

  /// Clear cache (useful for manual refresh)
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Leaderboard cache cleared');
  }

  /// Dispose resources
  void dispose() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
}



