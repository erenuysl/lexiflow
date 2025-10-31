import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script to update missing level fields in leaderboard_stats collection
/// This fixes the issue where level segment shows 0 docs
void main() async {
  print('🔧 Starting level field update script...');
  
  try {
    // Firebase'i başlat
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;
    
    print('📊 Checking leaderboard_stats collection...');
    
    // Mevcut tüm dokümanları getir
    final snapshot = await firestore.collection('leaderboard_stats').get();
    print('📋 Found ${snapshot.docs.length} documents in leaderboard_stats');
    
    int updatedCount = 0;
    int skippedCount = 0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = doc.id;
      
      // Level alanı var mı kontrol et
      if (data['level'] == null) {
        print('🔄 Updating level field for user: $userId');
        
        // currentLevel veya highestLevel'dan level değerini belirle
        final currentLevel = data['currentLevel'] ?? 1;
        final highestLevel = data['highestLevel'] ?? currentLevel;
        final level = highestLevel > currentLevel ? highestLevel : currentLevel;
        
        // Level alanını güncelle
        await doc.reference.update({'level': level});
        updatedCount++;
        
        print('✅ Updated $userId: level = $level (currentLevel: $currentLevel, highestLevel: $highestLevel)');
      } else {
        print('⏭️  Skipping $userId: level field already exists (${data['level']})');
        skippedCount++;
      }
    }
    
    print('🎉 Update completed!');
    print('📊 Updated: $updatedCount documents');
    print('⏭️  Skipped: $skippedCount documents');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('📍 Stack trace: $stackTrace');
    exit(1);
  }
}