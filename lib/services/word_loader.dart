import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/word_model.dart';

class WordLoader {
  static const String _assetsPath = 'assets/words/';
  
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
  
  /// Load words from a specific category JSON file
  static Future<List<Word>> loadCategoryWords(String category) async {
    try {
      final String jsonString = await rootBundle.loadString('$_assetsPath$category.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => Word.fromJson(json)).toList();
    } catch (e) {
      print('Error loading words for category $category: $e');
      return [];
    }
  }
  
  /// Load all words from all category files
  static Future<List<Word>> loadAllCategoryWords() async {
    List<Word> allWords = [];
    
    for (String category in categories.keys) {
      final categoryWords = await loadCategoryWords(category);
      allWords.addAll(categoryWords);
    }
    
    return allWords;
  }
  
  /// Get word count for a specific category
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
}