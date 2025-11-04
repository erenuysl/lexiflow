// lib/repositories/leaderboard_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';
import '../utils/logger.dart';

enum LeaderboardMode { weekly, allTime }

class LeaderboardRepository {
  final FirebaseFirestore _firestore;
  final Duration cacheTtl;

  final Map<LeaderboardMode, List<LeaderboardEntry>> _cache = {};
  final Map<LeaderboardMode, DateTime> _lastFetch = {};

  LeaderboardRepository({
    FirebaseFirestore? firestore,
    this.cacheTtl = const Duration(minutes: 5),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  bool _isCacheValid(LeaderboardMode mode) {
    final ts = _lastFetch[mode];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < cacheTtl && (_cache[mode]?.isNotEmpty ?? false);
  }

  Future<List<LeaderboardEntry>> fetchWeekly({bool forceRefresh = false}) async {
    return _fetch(mode: LeaderboardMode.weekly, forceRefresh: forceRefresh);
  }

  Future<List<LeaderboardEntry>> fetchAllTime({bool forceRefresh = false}) async {
    return _fetch(mode: LeaderboardMode.allTime, forceRefresh: forceRefresh);
  }

  Future<List<LeaderboardEntry>> _fetch({
    required LeaderboardMode mode,
    required bool forceRefresh,
  }) async {
    try {
      if (!forceRefresh && _isCacheValid(mode)) {
        Logger.d('LeaderboardRepository: returning cached ${mode.name}', 'LeaderboardRepository');
        return _cache[mode]!;
      }

      final query = _firestore
          .collection('users')
          .orderBy(mode == LeaderboardMode.weekly ? 'stats.weeklyXp' : 'stats.totalXp', descending: true)
          .limit(10);

      final snap = await query.get();

      var entries = snap.docs.map(LeaderboardEntry.fromUserDoc).toList();

      // Client-side tie-break to avoid composite index requirement
      if (mode == LeaderboardMode.weekly) {
        entries.sort((a, b) {
          final cmp = b.weeklyXp.compareTo(a.weeklyXp);
          if (cmp != 0) return cmp;
          final aName = a.username.toLowerCase();
          final bName = b.username.toLowerCase();
          final ncmp = aName.compareTo(bName);
          if (ncmp != 0) return ncmp;
          return a.uid.compareTo(b.uid);
        });
      } else {
        entries.sort((a, b) {
          final cmp = b.totalXp.compareTo(a.totalXp);
          if (cmp != 0) return cmp;
          final aName = a.username.toLowerCase();
          final bName = b.username.toLowerCase();
          final ncmp = aName.compareTo(bName);
          if (ncmp != 0) return ncmp;
          return a.uid.compareTo(b.uid);
        });
      }

      // Enforce top 10
      if (entries.length > 10) {
        entries = entries.sublist(0, 10);
      }

      _cache[mode] = entries;
      _lastFetch[mode] = DateTime.now();

      return entries;
    } catch (e, st) {
      Logger.e('LeaderboardRepository: fetch error for ${mode.name}', e, st);
      // Return last good cache if available
      final cached = _cache[mode];
      if (cached != null) return cached;
      return <LeaderboardEntry>[];
    }
  }
}