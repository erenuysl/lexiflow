// lib/screens/leaderboard_screen.dart
// Provider-driven Leaderboard screen with three tabs (Level / Streak / Quiz)
// - Material 3 friendly UI with TabBar/TabBarView
// - Uses LeaderboardProvider for cache-first loading and auto-refresh
// - Displays loading, error, and data states cleanly per tab

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/leader_entry.dart';
import '../providers/leaderboard_provider.dart';
import '../services/leaderboard_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeaderboardProvider>(
      create: (_) => LeaderboardProvider(LeaderboardService()),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Liderlik Tablosu'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Level'), Tab(text: 'Streak'), Tab(text: 'Quiz')],
            ),
          ),
          body: const TabBarView(
            children: [
              _LeaderboardTabView(tab: LeaderboardTab.level),
              _LeaderboardTabView(tab: LeaderboardTab.streak),
              _LeaderboardTabView(tab: LeaderboardTab.quiz),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTabView extends StatelessWidget {
  final LeaderboardTab tab;
  const _LeaderboardTabView({required this.tab});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaderboardProvider>();
    final state = provider.getState(tab);

    // İlk açılışta cache yoksa veriyi yükle (build sonrası çağır)
    if (!state.hasCache && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.load(tab);
      });
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(child: Text('Hata: ${state.error}'));
    }

    final entries = state.entries;
    if (entries.isEmpty) {
      return const Center(child: Text('Henüz veri yok'));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder:
          (context, _) => Divider(color: colorScheme.outlineVariant),
      itemBuilder: (context, i) {
        final e = entries[i];
        final ImageProvider<Object>? avatarImage =
            (e.avatarUrl != null && e.avatarUrl!.isNotEmpty)
                ? NetworkImage(e.avatarUrl!)
                : null;

        String subtitleText;
        switch (tab) {
          case LeaderboardTab.level:
            subtitleText = 'Level ${e.rankValue}';
            break;
          case LeaderboardTab.streak:
            subtitleText =
                'Longest ${e.rankValue} 🔥 Current ${e.secondary ?? 0}';
            break;
          case LeaderboardTab.quiz:
            subtitleText = '${e.rankValue} Quiz Tamamlandı';
            break;
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarImage,
            child:
                avatarImage == null
                    ? Text(
                      e.index.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                    : null,
          ),
          title: Text(
            e.username,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitleText),
          trailing: Text(
            '#${e.index}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

/*
Nasıl test edilir?
- Uygulama ağacında LeaderboardProvider'ı Provider olarak ekleyin.
- Ekranı açın: LeaderboardScreen(); her sekmede state otomatik izlenir.
- İlk açılışta cache yoksa provider.load(tab) tetiklenir ve progress görünür.
- 2 dakika içinde tekrar sekmeye dönün: cache varsa hızlı görüntülenir.
- 5 dakikada bir auto-refresh Provider içinde çalışır; veri yenilenir.
*/
