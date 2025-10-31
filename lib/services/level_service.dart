import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

/// Level calculation result containing all level-related data
class LevelData {
  final int level;
  final int levelStartXp;
  final int levelEndXp;
  final int xpIntoLevel;
  final int xpNeeded;
  final double progressPct;

  const LevelData({
    required this.level,
    required this.levelStartXp,
    required this.levelEndXp,
    required this.xpIntoLevel,
    required this.xpNeeded,
    required this.progressPct,
  });

  @override
  String toString() {
    return 'LevelData(level: $level, xpIntoLevel: $xpIntoLevel/$xpNeeded, progress: ${(progressPct * 100).toStringAsFixed(1)}%)';
  }
}

/// Service for level calculation and management
class LevelService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Level curve configuration - can be easily swapped with array
  static const List<int> _levelCurve = [
    200, // Level 1→2 needs 200 XP
    300, // Level 2→3 needs 300 XP  
    400, // Level 3→4 needs 400 XP
    500, // Level 4→5 needs 500 XP
    600, // Level 5→6 needs 600 XP
    700, // Level 6→7 needs 700 XP
    800, // Level 7→8 needs 800 XP
    900, // Level 8→9 needs 900 XP
    1000, // Level 9→10 needs 1000 XP
  ];

  /// Get XP required for a specific level (1-based)
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    if (level - 2 < _levelCurve.length) {
      return _levelCurve[level - 2];
    }
    // For levels beyond the curve, use formula: 200 + (level-1)*100
    return 200 + (level - 1) * 100;
  }

  /// Calculate cumulative XP needed to reach a specific level
  static int cumulativeXpForLevel(int level) {
    if (level <= 1) return 0;
    
    int totalXp = 0;
    for (int i = 2; i <= level; i++) {
      totalXp += xpForLevel(i);
    }
    return totalXp;
  }

  /// Compute level data from total XP
  static LevelData computeLevelData(int totalXp) {
    if (totalXp < 0) totalXp = 0;

    // Find the highest level where cumulative XP is <= totalXp
    int level = 1;
    int levelStartXp = 0;
    
    while (true) {
      final nextLevelCumulativeXp = cumulativeXpForLevel(level + 1);
      if (totalXp < nextLevelCumulativeXp) {
        break;
      }
      level++;
      levelStartXp = nextLevelCumulativeXp;
    }

    // Calculate level boundaries and progress
    final levelEndXp = cumulativeXpForLevel(level + 1);
    final xpIntoLevel = totalXp - levelStartXp;
    final xpNeeded = levelEndXp - levelStartXp;
    final progressPct = xpNeeded > 0 ? (xpIntoLevel / xpNeeded).clamp(0.0, 1.0) : 0.0;

    final result = LevelData(
      level: level,
      levelStartXp: levelStartXp,
      levelEndXp: levelEndXp,
      xpIntoLevel: xpIntoLevel,
      xpNeeded: xpNeeded,
      progressPct: progressPct,
    );

    Logger.i('[LEVEL] compute totalXp=$totalXp -> $result', 'LevelService');
    return result;
  }

  /// Mirror level to users/{uid}.level if it has changed (idempotent)
  static Future<void> mirrorLevelToUser(String userId, int computedLevel) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentLevel = userDoc.data()?['level'] as int?;

      if (currentLevel != computedLevel) {
        await _firestore.collection('users').doc(userId).update({
          'level': computedLevel,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        Logger.i('[LEVEL] mirror write: users/$userId.level=$computedLevel', 'LevelService');
      }
    } catch (e) {
      Logger.e('[LEVEL] Failed to mirror level to user', e, null, 'LevelService');
    }
  }

  /// Get level curve for display purposes
  static List<int> get levelCurve => List.unmodifiable(_levelCurve);

  /// Get max level defined in curve
  static int get maxDefinedLevel => _levelCurve.length + 1;
}