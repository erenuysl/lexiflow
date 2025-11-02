import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/word_model.dart';
import 'local_word_cache_service.dart';

class WordLoader {
  static const String _assetsPath = 'assets/words/';
  
  // Cache for loaded word lists per category
  static final Map<String, List<Word>> _categoryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache duration - words from assets don't change often
  static const Duration _cacheDuration = Duration(hours: 1);
  
  // Available categories with their display names and icons
  static const Map<String, Map<String, String>> categories = {
    'biology': {'name': 'Biyoloji', 'icon': '🧬'},
    'technology': {'name': 'Teknoloji', 'icon': '⚙️'},
    'history': {'name': 'Tarih', 'icon': '📜'},
    'geography': {'name': 'Coğrafya', 'icon': '🌍'},
    'psychology': {'name': 'Psikoloji', 'icon': '🧠'},
    'business': {'name': 'İş Dünyası', 'icon': '💼'},
    'communication': {'name': 'İletişim', 'icon': '💬'},
    'everyday': {'name': 'Günlük İngilizce', 'icon': '🗣️'},
  };
  
  /// Load words from a specific category JSON file with caching
  /// Merges asset words with custom user words
  static Future<List<Word>> loadCategoryWords(String category, {bool forceRefresh = false}) async {
    try {
      List<Word> assetWords = [];
      
      // Load words from assets
      // Check cache first (unless force refresh is requested)
      if (!forceRefresh && _isCacheValid(category)) {
        print('📋 Using cached words for category: $category (${_categoryCache[category]!.length} words)');
        assetWords = List.from(_categoryCache[category]!); // Return a copy to prevent modification
      } else {
        print('📥 Loading words from assets for category: $category');
        final String jsonString = await rootBundle.loadString('$_assetsPath$category.json');
        final List<dynamic> jsonList = json.decode(jsonString);
        
        assetWords = jsonList.map((json) => Word.fromJson(json)).toList();
        
        // Cache the loaded words
        _categoryCache[category] = assetWords;
        _cacheTimestamps[category] = DateTime.now();
        
        print('✅ Loaded and cached ${assetWords.length} words for category: $category');
      }
      
      // Skip merging custom words for daily, general, or random categories
      if (category == 'daily' || category == 'general' || category == 'random') {
        print('📋 Skipping custom merge for category: $category');
        return [...assetWords]; // ensures 10 words still load from default source
      }
      
      // Load custom words from local storage
      final customWords = LocalWordCacheService().getCustomWordsByCategory(category);
      
      // Merge asset words with custom words, avoiding duplicates
      final allWords = <Word>[];
      final wordSet = <String>{};
      
      // Add asset words first
      for (final word in assetWords) {
        final wordKey = word.word.toLowerCase();
        if (!wordSet.contains(wordKey)) {
          allWords.add(word);
          wordSet.add(wordKey);
        }
      }
      
      // Add custom words (they won't duplicate because of different keys)
      for (final customWord in customWords) {
        final wordKey = customWord.word.toLowerCase();
        if (!wordSet.contains(wordKey)) {
          allWords.add(customWord);
          wordSet.add(wordKey);
        } else {
          print('⚠️ Skipping duplicate custom word: ${customWord.word}');
        }
      }
      
      print('✅ Total words for category $category: ${allWords.length} (${assetWords.length} from assets + ${customWords.length} custom)');
      return allWords;
    } catch (e) {
      print('❌ Error loading words for category $category: $e');
      
      // Fallback: try to return only custom words if asset loading fails
      try {
        final customWords = LocalWordCacheService().getCustomWordsByCategory(category);
        print('📋 Fallback: returning ${customWords.length} custom words for category: $category');
        return customWords;
      } catch (customError) {
        print('❌ Error loading custom words as fallback: $customError');
        return [];
      }
    }
  }
  
  /// Check if cache is valid for a category
  static bool _isCacheValid(String category) {
    if (!_categoryCache.containsKey(category) || !_cacheTimestamps.containsKey(category)) {
      return false;
    }
    
    final cacheAge = DateTime.now().difference(_cacheTimestamps[category]!);
    return cacheAge < _cacheDuration;
  }
  
  /// Load all words from all category files with caching
  static Future<List<Word>> loadAllCategoryWords({bool forceRefresh = false}) async {
    List<Word> allWords = [];
    
    for (String category in categories.keys) {
      final categoryWords = await loadCategoryWords(category, forceRefresh: forceRefresh);
      allWords.addAll(categoryWords);
    }
    
    return allWords;
  }
  
  /// Get word count for a specific category (uses cache if available)
  static Future<int> getCategoryWordCount(String category) async {
    final words = await loadCategoryWords(category);
    return words.length;
  }
  
  /// Check if a category file exists
  static Future<bool> categoryExists(String category) async {
    try {
      await rootBundle.loadString('$_assetsPath$category.json');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Clear cache for a specific category
  static void clearCategoryCache(String category) {
    _categoryCache.remove(category);
    _cacheTimestamps.remove(category);
    print('🗑️ Cleared cache for category: $category');
  }
  
  /// Clear all cached word lists
  static void clearAllCache() {
    _categoryCache.clear();
    _cacheTimestamps.clear();
    print('🗑️ Cleared all word cache');
  }
  
  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedCategories': _categoryCache.keys.toList(),
      'totalCachedWords': _categoryCache.values.fold(0, (sum, words) => sum + words.length),
      'cacheTimestamps': _cacheTimestamps.map((key, value) => MapEntry(key, value.toIso8601String())),
    };
  }
}