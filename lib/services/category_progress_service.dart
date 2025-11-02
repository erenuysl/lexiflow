import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../di/locator.dart';
import 'learned_words_service.dart';
import 'word_service.dart';
import 'word_loader.dart';

/// Service to compute learned counts and progress percent per category
/// by combining data from LearnedWordsService and WordService.
class CategoryProgressService {
  // Singleton pattern
  static final CategoryProgressService _instance =
      CategoryProgressService._internal();
  factory CategoryProgressService() => _instance;
  CategoryProgressService._internal();

  // Dependencies
  final LearnedWordsService _learnedWordsService =
      locator<LearnedWordsService>();
  final WordService _wordService = locator<WordService>();

  // Simple in-memory cache for total counts per normalized category
  final Map<String, int> _totalCountCache = {};
  final Map<String, DateTime> _totalCountCacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  // In-memory cache for learned counts per normalized category
  final Map<String, int> _learnedCache = {};
  final Map<String, DateTime> _learnedCacheTimestamps = {};
  static const Duration _learnedCacheTTL = Duration(seconds: 30);

  // Cache for last logged percentages to reduce debug spam
  final Map<String, double> _lastLoggedPercent = {};

  /// Normalize incoming category keys to a canonical form.
  /// Treat ('1k', '1k kelime', 'common_1k', 'common-1k', 'common1k') as the same.
  String _normalizeCategoryKey(String categoryKey) {
    final n = categoryKey.trim().toLowerCase();

    // Alias mapping to expand supported inputs (TR/EN variants and common 1k synonyms)
    final aliases = <String, String>{
      'tarih': 'history',
      'teknoloji': 'technology',
      'coğrafya': 'geography',
      'cografya': 'geography',
      'psikoloji': 'psychology',
      'iş': 'business',
      'is': 'business',
      'işletme': 'business',
      'isletme': 'business',
      'iletişim': 'communication',
      'iletisim': 'communication',
      'günlük ingilizce': 'everyday_english',
      'gunluk ingilizce': 'everyday_english',
      'günlük': 'everyday_english',
      'gunluk': 'everyday_english',
      '1k': 'common_1k',
      '1k kelime': 'common_1k',
      'common-1k': 'common_1k',
      'common1k': 'common_1k',
    };

    // Return alias if matched, otherwise keep normalized key as-is
    if (aliases.containsKey(n)) return aliases[n]!;
    return n;
  }

  bool _shouldSkipCategory(String normalized) {
    return normalized == 'daily' || normalized == 'random';
  }

  Future<int> _calculateLearnedCount(
    List<LearnedWordRecord> records,
    String normalized,
  ) async {
    if (records.isEmpty) return 0;

    if (normalized == 'common_1k') {
      final learnedWords = records.map((r) => r.normalizedWord).toSet();
      if (learnedWords.isEmpty) return 0;
      final oneKWords = await _wordService.getAllWordsFromLocal();
      final oneKSet = oneKWords.map((w) => w.word.trim().toLowerCase()).toSet();
      return learnedWords.where(oneKSet.contains).length;
    }

    int count = 0;
    final missingWords = <String>{};

    for (final record in records) {
      final recordCategory = record.category.trim();
      if (recordCategory.isNotEmpty) {
        if (_normalizeCategoryKey(recordCategory) == normalized) {
          count++;
        }
      } else {
        missingWords.add(record.word);
      }
    }

    if (missingWords.isNotEmpty) {
      final mapped = _wordService.mapLearnedKeysToWords(missingWords);
      final resolved = <String>{};
      for (final word in mapped) {
        final normalizedWord = word.word.trim().toLowerCase();
        resolved.add(normalizedWord);
        final resolvedCategory = _normalizeCategoryKey(word.category ?? '');
        if (resolvedCategory.isNotEmpty && resolvedCategory == normalized) {
          count++;
        }
      }

      var unresolved =
          missingWords
              .map((w) => w.trim().toLowerCase())
              .where((w) => !resolved.contains(w))
              .toSet();

      if (unresolved.isNotEmpty) {
        for (final categoryKey in WordLoader.categories.keys) {
          final categoryWords = await WordLoader.loadCategoryWords(categoryKey);
          for (final word in categoryWords) {
            final normalizedWord = word.word.trim().toLowerCase();
            if (!unresolved.contains(normalizedWord)) {
              continue;
            }

            final resolvedCategory = _normalizeCategoryKey(
              word.category ?? categoryKey,
            );
            if (resolvedCategory.isNotEmpty && resolvedCategory == normalized) {
              count++;
            }

            unresolved.remove(normalizedWord);
            if (unresolved.isEmpty) {
              break;
            }
          }

          if (unresolved.isEmpty) {
            break;
          }
        }
      }
    }

    return count;
  }

  /// Get learned count for a specific category.
  /// Steps:
  /// 1) Fetch learned word IDs
  /// 2) Map IDs to Word objects via WordService
  /// 3) Filter by category (normalized)
  /// 4) Return count
  Future<int> getLearnedCountForCategory(
    String userId,
    String categoryKey,
  ) async {
    final normalized = _normalizeCategoryKey(categoryKey);
    if (_shouldSkipCategory(normalized)) return 0;

    // Cache check for learned counts
    final learnedTs = _learnedCacheTimestamps[normalized];
    final learnedCached = _learnedCache[normalized];
    if (learnedTs != null && learnedCached != null) {
      final age = DateTime.now().difference(learnedTs);
      if (age < _learnedCacheTTL) {
        if (kDebugMode) {
          print('[CategoryProgressCache] hit for learned:$normalized');
        }
        return learnedCached;
      }
    }

    final records = await _learnedWordsService.getLearnedWordRecords(userId);
    final count = await _calculateLearnedCount(records, normalized);
    _learnedCache[normalized] = count;
    _learnedCacheTimestamps[normalized] = DateTime.now();
    return count;
  }

  /// Get total word count for a specific category.
  /// Uses WordLoader and caches results for a short duration.
  Future<int> getTotalCountForCategory(String categoryKey) async {
    final normalized = _normalizeCategoryKey(categoryKey);
    if (_shouldSkipCategory(normalized)) return 0;

    final now = DateTime.now();
    final ts = _totalCountCacheTimestamps[normalized];
    if (ts != null) {
      final age = now.difference(ts);
      if (age < _cacheDuration) {
        final cached = _totalCountCache[normalized];
        if (cached != null) {
          if (kDebugMode) {
            print('[CategoryProgressCache] hit for total:$normalized');
          }
          return cached;
        }
      } else {
        // Cache expired, clear before reloading
        _totalCountCache.remove(normalized);
        _totalCountCacheTimestamps.remove(normalized);
      }
    }

    // Use WordLoader with canonical key to avoid duplicate caches
    final words = await WordLoader.loadCategoryWords(normalized);
    final count = words.length;

    _totalCountCache[normalized] = count;
    _totalCountCacheTimestamps[normalized] = now;
    return count;
  }

  /// Get progress percent (learned / total * 100.0) rounded to one decimal place.
  Future<double> getProgressPercent(String userId, String categoryKey) async {
    final normalized = _normalizeCategoryKey(categoryKey);
    final total = await getTotalCountForCategory(normalized);
    if (total <= 0) return 0.0;

    final learned = await getLearnedCountForCategory(userId, normalized);
    final pct = (learned / total) * 100.0;
    return double.parse(pct.toStringAsFixed(1));
  }

  /// Reactive stream for progress percent by category.
  /// Emits a new percentage whenever learned words change for the user.
  Stream<double> watchProgressPercent(String userId, String categoryKey) {
    final normalized = _normalizeCategoryKey(categoryKey);
    return _learnedWordsService
        .watchLearnedWordRecords(userId)
        .asyncMap((records) async {
          if (_shouldSkipCategory(normalized)) return 0.0;

          final total = await getTotalCountForCategory(normalized);
          if (total <= 0) return 0.0;

          final learnedCount = await _calculateLearnedCount(
            records,
            normalized,
          );

          // Update learned cache for consistency
          _learnedCache[normalized] = learnedCount;
          _learnedCacheTimestamps[normalized] = DateTime.now();

          final pct = (learnedCount / total) * 100.0;
          final rounded = double.parse(pct.toStringAsFixed(1));

          // yalnızca değer değiştiğinde log bas
          if (rounded != _lastLoggedPercent[normalized]) {
            if (kDebugMode) {
              print(
                '[CategoryProgressStream] $normalized: learned=$learnedCount / total=$total -> ${rounded.toStringAsFixed(1)}%',
              );
            }
            _lastLoggedPercent[normalized] = rounded;
          }

          return rounded;
        })
        // Suppress duplicate percentages and add debounce for stability
        .distinct()
        .debounceTime(const Duration(milliseconds: 250));
  }

  /// Clear caches. If [categoryKey] is provided, clear that category only.
  /// Otherwise, clear all cached entries.
  void clearCache([String? categoryKey]) {
    if (categoryKey == null) {
      _totalCountCache.clear();
      _totalCountCacheTimestamps.clear();
      _learnedCache.clear();
      _learnedCacheTimestamps.clear();
      _lastLoggedPercent.clear();
      return;
    }
    final normalized = _normalizeCategoryKey(categoryKey);
    _totalCountCache.remove(normalized);
    _totalCountCacheTimestamps.remove(normalized);
    _learnedCache.remove(normalized);
    _learnedCacheTimestamps.remove(normalized);
    _lastLoggedPercent.remove(normalized);
  }

  // 🔧 Manual cache invalidation for instant progress refresh
  Future<void> invalidateCacheForCategory(String category) async {
    final key = _normalizeCategoryKey(category);
    _learnedCache.remove(key);
    _learnedCacheTimestamps.remove(key);
    _totalCountCache.remove(key);
    _totalCountCacheTimestamps.remove(key);
    _lastLoggedPercent.remove(key);
    if (kDebugMode) {
      print('[CategoryProgressCache] invalidated for $key');
    }
  }
}
