// lib/services/favorites_cleanup_service.dart
// Service to clean up duplicate favorites in Hive storage

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class FavoritesCleanupService {
  static const String _favoritesBoxName = 'favorites';

  /// Clean up duplicate favorites in Hive storage
  static Future<int> cleanupDuplicateFavorites() async {
    try {
      final favBox = Hive.box<String>(_favoritesBoxName);
      final allValues = favBox.values.toList();
      final allKeys = favBox.keys.toList();
      
      // Track unique words and their first occurrence
      final Map<String, dynamic> uniqueWords = {};
      final List<dynamic> keysToDelete = [];
      
      for (int i = 0; i < allValues.length; i++) {
        final word = allValues[i];
        final key = allKeys[i];
        
        if (uniqueWords.containsKey(word)) {
          // This is a duplicate, mark for deletion
          keysToDelete.add(key);
        } else {
          // First occurrence, keep it
          uniqueWords[word] = key;
        }
      }
      
      // Delete duplicate entries
      for (final key in keysToDelete) {
        await favBox.delete(key);
      }
      
      if (kDebugMode) {
        print('🧹 Cleaned up ${keysToDelete.length} duplicate favorites');
      }
      return keysToDelete.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cleaning up favorites: $e');
      }
      return 0;
    }
  }

  /// Get statistics about favorites storage
  static Map<String, int> getFavoritesStats() {
    try {
      final favBox = Hive.box<String>(_favoritesBoxName);
      final allValues = favBox.values.toList();
      final uniqueValues = allValues.toSet();
      
      return {
        'total': allValues.length,
        'unique': uniqueValues.length,
        'duplicates': allValues.length - uniqueValues.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting favorites stats: $e');
      }
      return {'total': 0, 'unique': 0, 'duplicates': 0};
    }
  }
}