import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/word_model.dart';
import '../utils/feature_flags.dart';

/// Spaced Repetition System (SRS) Service
/// Implements the SM-2 algorithm for optimal learning intervals
class SRSService {
  // ===============
  // FSRS-Lite State
  // ===============
  static const String _fsrsBoxName = 'fsrs_meta';
  static Box<String>? _fsrsBox; // stores JSON {difficulty, stability, lastReviewAt}

  static Future<void> _ensureFsrsBox() async {
    if (_fsrsBox?.isOpen == true) return;
    try {
      _fsrsBox = await Hive.openBox<String>(_fsrsBoxName);
    } catch (_) {
      // As a last resort, try recreate
      await Hive.deleteBoxFromDisk(_fsrsBoxName);
      _fsrsBox = await Hive.openBox<String>(_fsrsBoxName);
    }
  }

  static String _keyFor(Word w) => w.word; // use word text as key consistently

  static Map<String, dynamic> _defaultFsrsState() => {
        'difficulty': 5.0, // 1 (easy) .. 10 (hard)
        'stability': 1.0, // in days
        'lastReviewAt': null,
      };

  static Map<String, dynamic> _loadFsrsStateSync(Word w) {
    final key = _keyFor(w);
    final raw = _fsrsBox?.get(key);
    if (raw == null) return _defaultFsrsState();
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return {
        'difficulty': (map['difficulty'] as num?)?.toDouble() ?? 5.0,
        'stability': (map['stability'] as num?)?.toDouble() ?? 1.0,
        'lastReviewAt': map['lastReviewAt'],
      };
    } catch (_) {
      return _defaultFsrsState();
    }
  }

  static Future<void> _saveFsrsState(Word w, Map<String, dynamic> state) async {
    await _ensureFsrsBox();
    final key = _keyFor(w);
    await _fsrsBox!.put(key, json.encode(state));
  }

  // ======================
  // FSRS-Lite Computation
  // ======================
  // quality: 0=again, 1=hard, 2=good, 3=easy
  static Future<void> updateAfterAnswer({
    required Word word,
    required int quality,
    int responseTimeMs = 0,
  }) async {
    if (!FeatureFlags.fsrsEnabled) {
      // Fallback to existing simple SRS
      if (quality <= 0) {
        updateWordIncorrect(word);
      } else {
        updateWordCorrect(word);
      }
      return;
    }

    await _ensureFsrsBox();
    final state = _loadFsrsStateSync(word);
    double d = state['difficulty'] as double;
    double s = state['stability'] as double;

    // Adjustments inspired by FSRS dynamics, simplified
    // responseTimeMs can nudge difficulty slightly
    final rtPenalty = responseTimeMs > 15000 ? 0.3 : responseTimeMs > 8000 ? 0.15 : 0.0;

    switch (quality) {
      case 0: // again
        d = (d + 1.0 + rtPenalty).clamp(1.0, 10.0);
        s = (s * 0.5).clamp(0.5, 3650.0);
        word.srsLevel = 1;
        word.correctStreak = 0;
        break;
      case 1: // hard
        d = (d + 0.3 + rtPenalty).clamp(1.0, 10.0);
        s = (s * 0.9 + 1).clamp(1.0, 3650.0);
        word.srsLevel = (word.srsLevel <= 1 ? 1 : word.srsLevel);
        word.correctStreak = (word.correctStreak > 0) ? word.correctStreak : 0;
        break;
      case 2: // good
        d = (d - 0.2 - rtPenalty).clamp(1.0, 10.0);
        s = (s * 1.6 + 1).clamp(1.0, 3650.0);
        word.srsLevel = (word.srsLevel + 1).clamp(1, 5);
        word.correctStreak += 1;
        break;
      case 3: // easy
      default:
        d = (d - 0.5 - rtPenalty).clamp(1.0, 10.0);
        s = (s * 2.2 + 1).clamp(1.0, 3650.0);
        word.srsLevel = (word.srsLevel + 1).clamp(1, 5);
        word.correctStreak += 1;
        break;
    }

    final nextDays = s.clamp(1.0, 3650.0);
    word.interval = nextDays.round();
    word.nextReviewDate = DateTime.now().add(Duration(days: word.interval));

    // Persist to Hive when possible. If the word isn't yet in the box,
    // try to link by text or add it (optional persistence for DC/Quiz words).
    try {
      if (word.isInBox) {
        await word.save();
      } else {
        final box = await Hive.openBox<Word>('words');
        final existing = box.values.firstWhere(
          (w) => w.word == word.word,
          orElse: () => word,
        );
        if (identical(existing, word)) {
          await box.add(word);
        } else {
          existing.interval = word.interval;
          existing.nextReviewDate = word.nextReviewDate;
          existing.srsLevel = word.srsLevel;
          existing.correctStreak = word.correctStreak;
          await existing.save();
        }
      }
    } catch (_) {
      // best-effort persistence; ignore if Hive not ready
    }

    state['difficulty'] = d;
    state['stability'] = s;
    state['lastReviewAt'] = DateTime.now().toIso8601String();
    await _saveFsrsState(word, state);
  }
  // SRS intervals in days for each level
  static const List<int> _intervals = [1, 3, 7, 14, 30];

  /// Calculate next review date based on SRS level
  static DateTime calculateNextReviewDate(int srsLevel) {
    final now = DateTime.now();
    
    if (srsLevel <= 0) {
      // New word, review tomorrow
      return now.add(const Duration(days: 1));
    }
    
    // Get interval for current level (max level 5)
    final levelIndex = (srsLevel - 1).clamp(0, _intervals.length - 1);
    final daysToAdd = _intervals[levelIndex];
    
    return now.add(Duration(days: daysToAdd));
  }

  /// Update word after correct answer
  static void updateWordCorrect(Word word) {
    if (FeatureFlags.fsrsEnabled) {
      // Bridge to FSRS; fire-and-forget to preserve signature
      // Default quality=2 (good)
      // ignore: unawaited_futures
      updateAfterAnswer(word: word, quality: 2);
      return;
    }
    word.srsLevel++;
    word.correctStreak++;
    word.nextReviewDate = calculateNextReviewDate(word.srsLevel);
    word.save();
  }

  /// Update word after incorrect answer
  static void updateWordIncorrect(Word word) {
    if (FeatureFlags.fsrsEnabled) {
      // Bridge to FSRS; fire-and-forget to preserve signature
      // Default quality=0 (again)
      // ignore: unawaited_futures
      updateAfterAnswer(word: word, quality: 0);
      return;
    }
    word.srsLevel = 1; // Reset to level 1 (not 0, so it's still "seen")
    word.correctStreak = 0;
    word.nextReviewDate = DateTime.now().add(const Duration(days: 1));
    word.save();
  }

  /// Check if word needs review today
  static bool needsReview(Word word) {
    if (word.nextReviewDate == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDate = DateTime(
      word.nextReviewDate!.year,
      word.nextReviewDate!.month,
      word.nextReviewDate!.day,
    );
    
    return reviewDate.isBefore(today) || reviewDate.isAtSameMomentAs(today);
  }

  /// Get SRS level description
  static String getSRSLevelDescription(int level) {
    switch (level) {
      case 0:
        return 'New';
      case 1:
        return 'Learning';
      case 2:
        return 'Familiar';
      case 3:
        return 'Known';
      case 4:
        return 'Well Known';
      case 5:
        return 'Mastered';
      default:
        return level > 5 ? 'Mastered' : 'New';
    }
  }

  /// Get SRS level color
  static String getSRSLevelColor(int level) {
    switch (level) {
      case 0:
        return '#9E9E9E'; // Grey
      case 1:
        return '#F44336'; // Red
      case 2:
        return '#FF9800'; // Orange
      case 3:
        return '#FFEB3B'; // Yellow
      case 4:
        return '#8BC34A'; // Light Green
      case 5:
        return '#4CAF50'; // Green
      default:
        return level > 5 ? '#4CAF50' : '#9E9E9E';
    }
  }

  /// Utility: ensure FSRS meta is available for a word (used by diagnostics/UI)
  static Future<Map<String, dynamic>> getFsrsMeta(Word word) async {
    await _ensureFsrsBox();
    return _loadFsrsStateSync(word);
  }
}
