import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

enum LeaderboardTab { weekly, allTime }

enum Segment { xp, streak, quiz }

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardTab _tab = LeaderboardTab.weekly;
  Segment _segment = Segment.xp; // xp represents the Level segment now
  final LeaderboardService _leaderboardService = LeaderboardService();
  
  // Removed debounce timer as it was causing excessive auto-refresh

  // ✅ FIX: Use single collection 'leaderboard_stats'
  String get _currentCollection => 'leaderboard_stats';

  String get _currentField {
    // ✅ FIXED: Correct field mapping for weekly vs all-time isolation
    switch (_segment) {
      case Segment.xp:
        // Weekly: weeklyXp (resets weekly), All-time: totalXp (never resets)
        return _tab == LeaderboardTab.weekly ? 'weeklyXp' : 'totalXp';
      case Segment.streak:
        // Weekly: currentStreak (day-based, can reset), All-time: longestStreak (never resets)
        return _tab == LeaderboardTab.weekly
            ? 'currentStreak'
            : 'longestStreak';
      case Segment.quiz:
        // Weekly: weeklyQuizzes (resets weekly), All-time: quizzesCompleted (never resets)
        return _tab == LeaderboardTab.weekly
            ? 'weeklyQuizzes'
            : 'quizzesCompleted';
    }
  }

  /// Get display value for leaderboard item based on current tab and segment
  String _getDisplayValue(Map<String, dynamic> data) {
    final value = data[_currentField] ?? 0;
    
    switch (_segment) {
      case Segment.xp:
        // For XP segment, show level with "Seviye" prefix
        return 'Seviye $value';
      case Segment.streak:
        // For streak segment, show days with "gün" suffix
        return '$value gün';
      case Segment.quiz:
        // For quiz segment, show count with "quiz" suffix
        return '$value quiz';
    }
  }

  /// Get subtitle for leaderboard item with additional context
  String _getSubtitle(Map<String, dynamic> data) {
    switch (_segment) {
      case Segment.xp:
        if (_tab == LeaderboardTab.weekly) {
          final weeklyXp = data['weeklyXp'] ?? 0;
          return '$weeklyXp XP bu hafta';
        } else {
          final totalXp = data['totalXp'] ?? 0;
          return '$totalXp toplam XP';
        }
      case Segment.streak:
        if (_tab == LeaderboardTab.weekly) {
          final currentStreak = data['currentStreak'] ?? 0;
          return '$currentStreak günlük seri';
        } else {
          final longestStreak = data['longestStreak'] ?? 0;
          return '$longestStreak en uzun seri';
        }
      case Segment.quiz:
        if (_tab == LeaderboardTab.weekly) {
          final weeklyQuizzes = data['weeklyQuizzes'] ?? 0;
          return '$weeklyQuizzes haftalık quiz';
        } else {
          final totalQuizzes = data['quizzesCompleted'] ?? 0;
          return '$totalQuizzes toplam quiz';
        }
    }
  }

  /// Manual refresh for pull-to-refresh only
  Future<void> _refreshLeaderboard() async {
    try {
      print('🔄 TRACE: _refreshLeaderboard() called at ${DateTime.now()}');
      
      // Clear leaderboard cache to force fresh data
      print('🗑️ TRACE: Clearing leaderboard cache');
      _leaderboardService.clearCache();
      
      // Add debounce delay to ensure Firestore updates propagate
      print('⏳ TRACE: Waiting 300ms for Firestore updates to propagate');
      await Future.delayed(const Duration(milliseconds: 300));
      
      print('✅ TRACE: Leaderboard refresh completed successfully');
      
      // Show success message only for manual refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏆 Liderlik tablosu güncellendi!'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF5AB2FF),
          ),
        );
      }
    } catch (e) {
      print('❌ TRACE: Refresh failed with error: $e');
      debugPrint('❌ Refresh failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Güncelleme başarısız oldu'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Removed debounce timer cleanup as it's no longer used
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Unified accent based on profile screen's blue/teal theme
    const accent = Color(0xFF5AB2FF);
    const accentSecondary = Color(0xFF43E8D8);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Liderlik Tablosu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'Haftalık',
                      active: _tab == LeaderboardTab.weekly,
                      primaryColor: accent,
                      secondaryColor: accentSecondary,
                      onTap: () {
                        setState(() => _tab = LeaderboardTab.weekly);
                        // Removed auto-refresh on tab change to prevent excessive refreshing
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TabButton(
                      label: 'Tüm Zamanlar',
                      active: _tab == LeaderboardTab.allTime,
                      primaryColor: accent,
                      secondaryColor: accentSecondary,
                      onTap: () {
                        setState(() => _tab = LeaderboardTab.allTime);
                        // Removed auto-refresh on tab change to prevent excessive refreshing
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: 'Seviye',
                      active: _segment == Segment.xp,
                      primaryColor: accent,
                      secondaryColor: accentSecondary,
                      onTap: () {
                        setState(() => _segment = Segment.xp);
                        // Removed auto-refresh on segment change to prevent excessive refreshing
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Seri',
                      active: _segment == Segment.streak,
                      primaryColor: accent,
                      secondaryColor: accentSecondary,
                      onTap: () {
                        setState(() => _segment = Segment.streak);
                        // Removed auto-refresh on segment change to prevent excessive refreshing
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Quiz',
                      active: _segment == Segment.quiz,
                      primaryColor: accent,
                      secondaryColor: accentSecondary,
                      onTap: () {
                        setState(() => _segment = Segment.quiz);
                        // Removed auto-refresh on segment change to prevent excessive refreshing
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshLeaderboard,
                color: accent,
                backgroundColor: const Color(0xFF1E1E1E),
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection(_currentCollection)
                          .orderBy(_currentField, descending: true)
                          .limit(10)
                          .snapshots(includeMetadataChanges: true),
                  builder: (context, snapshot) {
                  // 🔥 DEBUG: Log stream snapshot reception with metadata
                  print("🔥 Stream snapshot received at ${DateTime.now()}: ${snapshot.data?.docs.length} docs");
                  print("🔥 Current field: $_currentField, Collection: $_currentCollection");
                  print("🔥 Tab: $_tab, Segment: $_segment");
                  
                  if (snapshot.hasData) {
                    final metadata = snapshot.data!.metadata;
                    print("🔥 Snapshot metadata - fromCache: ${metadata.isFromCache}, hasPendingWrites: ${metadata.hasPendingWrites}");
                  }
                  
                  if (snapshot.hasError) {
                    print("❌ Stream error: ${snapshot.error}");
                    return Center(
                      child: Text(
                        'Hata: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: accent),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  print("📊 Processing ${docs.length} leaderboard documents");

                  if (!snapshot.hasData || docs.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: accent),
                    );
                  }
                  
                  // Sıralama değişikliklerini dinamik olarak yansıtmak için her build'de yeniden hesapla

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: ListView.builder(
                      key: ValueKey('${_tab.name}-${_segment.name}'),
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;

                        final String displayName =
                            (data['displayName'] as String?) ?? 'Unknown';
                        final String? photoURL = data['photoURL'] as String?;

                        // 📊 DEBUG: Log parsed leaderboard entry
                        final weeklyXp = data['weeklyXp'] ?? 0;
                        final weeklyQuizzes = data['weeklyQuizzes'] ?? 0;
                        final totalXp = data['totalXp'] ?? 0;
                        
                        print("📊 Entry ${index + 1}: $displayName - weeklyXp: $weeklyXp, weeklyQuizzes: $weeklyQuizzes, totalXp: $totalXp");
                        print("📊 Current field value ($_currentField): ${data[_currentField] ?? 0}");

                        // ✅ ENHANCED: Use new display methods for proper field isolation
                        final String displayValue = _getDisplayValue(data);
                        final String subtitle = _getSubtitle(data);

                        return _LeaderboardTile(
                          rank: index + 1,
                          displayName: displayName,
                          photoURL: photoURL,
                          displayValue: displayValue,
                          subtitle: subtitle,
                          segment: _segment,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.primaryColor,
    this.secondaryColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color primaryColor;
  final Color? secondaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient:
              active && secondaryColor != null
                  ? LinearGradient(colors: [secondaryColor!, primaryColor])
                  : null,
          color:
              active && secondaryColor != null
                  ? null
                  : (active ? primaryColor : const Color(0xFF1E1E1E)),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.primaryColor,
    this.secondaryColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color primaryColor;
  final Color? secondaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient:
              active && secondaryColor != null
                  ? LinearGradient(colors: [secondaryColor!, primaryColor])
                  : null,
          color:
              active && secondaryColor != null
                  ? null
                  : (active ? primaryColor : const Color(0xFF1E1E1E)),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatefulWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.displayName,
    this.photoURL,
    required this.displayValue,
    required this.subtitle,
    required this.segment,
  });

  final int rank;
  final String displayName;
  final String? photoURL;
  final String displayValue;
  final String subtitle;
  final Segment segment;

  @override
  State<_LeaderboardTile> createState() => _LeaderboardTileState();
}

class _LeaderboardTileState extends State<_LeaderboardTile> {
  double _scale = 1.0;

  void _handleTap(bool down) {
    setState(() => _scale = down ? 1.03 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handleTap(true),
      onTapUp: (_) => _handleTap(false),
      onTapCancel: () => _handleTap(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _ProfileAvatar(url: widget.photoURL, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.displayValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              _TrophyIcon(rank: widget.rank),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url, this.radius = 24});
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String? u = url;
    final double size = radius * 2;

    if (u == null || u.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[800],
        child: const Icon(Icons.person, color: Colors.white54),
      );
    }

    final bool isAsset = u.startsWith('assets/');
    final bool isSvg = u.toLowerCase().endsWith('.svg');

    if (isSvg) {
      // Use SvgPicture for SVGs (asset or network), clipped to circle
      final Widget svg =
          isAsset
              ? SvgPicture.asset(
                u,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
              : SvgPicture.network(
                u,
                width: size,
                height: size,
                fit: BoxFit.cover,
              );
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[800],
        child: ClipOval(child: svg),
      );
    }

    // Raster images
    final ImageProvider provider =
        isAsset ? AssetImage(u) : NetworkImage(u) as ImageProvider;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      backgroundImage: provider,
    );
  }
}

class _TrophyIcon extends StatelessWidget {
  const _TrophyIcon({required this.rank});
  final int rank;

  Color get _color {
    if (rank == 1) return const Color(0xFFFFD700); // gold
    if (rank == 2) return const Color(0xFFC0C0C0); // silver
    if (rank == 3) return const Color(0xFFCD7F32); // bronze
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    // İlk 3 için kupa, diğerleri için madalya simgesi
    final IconData iconData;
    if (rank <= 3) {
      iconData = rank == 1 ? Icons.emoji_events : Icons.emoji_events_outlined;
    } else {
      iconData = Icons.military_tech; // Madalya simgesi
    }
    
    final icon = Icon(
      iconData,
      color: _color,
      size: 28,
    );

    if (rank == 1) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.6),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: icon,
      );
    }

    return icon;
  }
}
