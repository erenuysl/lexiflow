import 'package:hive/hive.dart';
import '../models/word_model.dart';
import '../utils/logger.dart';

/// Local Word Cache Service
/// Manages custom words that are stored locally only and never synced to Firestore
class LocalWordCacheService {
  static final LocalWordCacheService _instance = LocalWordCacheService._internal();
  factory LocalWordCacheService() => _instance;
  LocalWordCacheService._internal();

  static const String _customWordsBoxName = 'user_custom_words';
  Box<Word>? _customWordsBox;

  /// Initialize the service and open Hive box
  Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_customWordsBoxName)) {
        _customWordsBox = await Hive.openBox<Word>(_customWordsBoxName);
      } else {
        _customWordsBox = Hive.box<Word>(_customWordsBoxName);
      }
      Logger.i('LocalWordCacheService initialized', 'LocalWordCacheService');
    } catch (e) {
      Logger.e('Failed to initialize LocalWordCacheService', e, null, 'LocalWordCacheService');
    }
  }

  /// Add a custom word to a specific category
  Future<void> addCustomWord(String category, Word word) async {
    try {
      await initialize();
      
      if (_customWordsBox == null) {
        throw Exception('Custom words box not initialized');
      }

      // Create unique key: category:word
      final key = '$category:${word.word.toLowerCase()}';
      
      // Create word with custom flag and category
      final customWord = Word(
        word: word.word,
        meaning: word.meaning,
        example: word.example,
        tr: word.tr,
        exampleSentence: word.exampleSentence,
        category: category,
        isCustom: true,
        createdAt: DateTime.now(),
        tags: word.tags,
      );

      await _customWordsBox!.put(key, customWord);
      
      Logger.i('Custom word added: ${word.word} to category: $category', 'LocalWordCacheService');
    } catch (e) {
      Logger.e('Error adding custom word', e, null, 'LocalWordCacheService');
      rethrow;
    }
  }

  /// Get all custom words for a specific category
  List<Word> getCustomWordsByCategory(String category) {
    try {
      if (_customWordsBox == null) {
        Logger.w('Custom words box not initialized', 'LocalWordCacheService');
        return [];
      }

      final customWords = <Word>[];
      
      // Iterate through all keys and find words for this category
      for (final key in _customWordsBox!.keys) {
        if (key.toString().startsWith('$category:')) {
          final word = _customWordsBox!.get(key);
          if (word != null && word.category == category) {
            customWords.add(word);
          }
        }
      }

      // Sort by creation date (newest first)
      customWords.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return customWords;
    } catch (e) {
      Logger.e('Error getting custom words for category: $category', e, null, 'LocalWordCacheService');
      return [];
    }
  }

  /// Delete a custom word
  Future<bool> deleteCustomWord(String category, String word) async {
    try {
      await initialize();
      
      if (_customWordsBox == null) {
        throw Exception('Custom words box not initialized');
      }

      final key = '$category:${word.toLowerCase()}';
      
      if (_customWordsBox!.containsKey(key)) {
        await _customWordsBox!.delete(key);
        Logger.i('Custom word deleted: $word from category: $category', 'LocalWordCacheService');
        return true;
      }
      
      return false;
    } catch (e) {
      Logger.e('Error deleting custom word', e, null, 'LocalWordCacheService');
      return false;
    }
  }

  /// Get all custom words (across all categories)
  List<Word> getAllCustomWords() {
    try {
      if (_customWordsBox == null) {
        Logger.w('Custom words box not initialized', 'LocalWordCacheService');
        return [];
      }

      return _customWordsBox!.values.toList();
    } catch (e) {
      Logger.e('Error getting all custom words', e, null, 'LocalWordCacheService');
      return [];
    }
  }

  /// Check if a word already exists in a category
  bool wordExistsInCategory(String category, String word) {
    try {
      if (_customWordsBox == null) {
        return false;
      }

      final key = '$category:${word.toLowerCase()}';
      return _customWordsBox!.containsKey(key);
    } catch (e) {
      Logger.e('Error checking word existence', e, null, 'LocalWordCacheService');
      return false;
    }
  }

  /// Get count of custom words in a category
  int getCustomWordCount(String category) {
    return getCustomWordsByCategory(category).length;
  }

  /// Clear all custom words (for testing or reset purposes)
  Future<void> clearAllCustomWords() async {
    try {
      await initialize();
      
      if (_customWordsBox == null) {
        throw Exception('Custom words box not initialized');
      }

      await _customWordsBox!.clear();
      Logger.i('All custom words cleared', 'LocalWordCacheService');
    } catch (e) {
      Logger.e('Error clearing custom words', e, null, 'LocalWordCacheService');
    }
  }

  /// Dispose method to clean up resources
  void dispose() {
    // Hive boxes are managed globally, so we don't close them here
    Logger.i('LocalWordCacheService disposed', 'LocalWordCacheService');
  }
}