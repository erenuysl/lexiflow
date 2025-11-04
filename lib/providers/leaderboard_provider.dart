// lib/providers/leaderboard_provider.dart
// Leaderboard Provider — cache-first, auto-refresh, flicker-free

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/leader_entry.dart';
import '../services/leaderboard_service.dart';

enum LeaderboardTab { level, streak, quiz }

class LeaderboardState {
  final bool isLoading;
  final List<LeaderEntry> entries;
  final Object? error;
  final DateTime? lastFetch;

  const LeaderboardState({
    this.isLoading = false,
    this.entries = const [],
    this.error,
    this.lastFetch,
  });

  LeaderboardState copyWith({
    bool? isLoading,
    List<LeaderEntry>? entries,
    Object? error,
    DateTime? lastFetch,
  }) {
    return LeaderboardState(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      error: error,
      lastFetch: lastFetch ?? this.lastFetch,
    );
  }

  // 🔒 Artık boş liste bile “cache” kabul ediliyor
  bool get hasCache => entries.isNotEmpty || lastFetch != null;

  // Cache 2 dakikadan eskiyse stale say
  bool get isStale {
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch!).inMinutes >= 2;
  }
}

class LeaderboardProvider extends ChangeNotifier {
  final LeaderboardService _service;
  final Map<LeaderboardTab, LeaderboardState> _states = {
    for (final t in LeaderboardTab.values) t: const LeaderboardState(),
  };

  Timer? _refreshTimer;

  LeaderboardProvider(this._service) {
    _startAutoRefresh();
  }

  LeaderboardState getState(LeaderboardTab tab) => _states[tab]!;

  Future<void> load(LeaderboardTab tab, {bool forceRefresh = false}) async {
    final current = _states[tab]!;

    // 🔽 Cache tazeyse yeniden yükleme
    if (!forceRefresh && current.hasCache && !current.isStale) return;

    _states[tab] = current.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      List<LeaderEntry> entries;
      switch (tab) {
        case LeaderboardTab.level:
          entries = await _service.fetchTopLevels();
          break;
        case LeaderboardTab.streak:
          entries = await _service.fetchTopStreaks();
          break;
        case LeaderboardTab.quiz:
          entries = await _service.fetchTopQuizzes();
          break;
      }

      _states[tab] = current.copyWith(
        isLoading: false,
        entries: entries,
        error: null,
        lastFetch: DateTime.now(),
      );
    } catch (e) {
      // 🔽 Hata bile olsa lastFetch ver, böylece spinner tekrar dönmez
      _states[tab] = current.copyWith(
        isLoading: false,
        error: e,
        lastFetch: DateTime.now(),
      );
    }

    notifyListeners();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      for (final tab in LeaderboardTab.values) {
        load(tab, forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
