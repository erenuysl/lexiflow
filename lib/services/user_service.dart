import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data.dart';
import '../utils/logger.dart';

class UserService {
  static const String _userDataBoxName = 'user_data';
  static const String _userDataKey = 'current_user';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize and get or create user data
  Future<void> init() async {
    await Hive.openBox<UserData>(_userDataBoxName);
    
    // Create default user data if doesn't exist
    final box = Hive.box<UserData>(_userDataBoxName);
    if (box.get(_userDataKey) == null) {
      final userData = UserData(
        lastLoginDate: DateTime.now(),
        currentStreak: 1,
      );
      await box.put(_userDataKey, userData);
    }
  }

  // Get current user data
  UserData getUserData() {
    final box = Hive.box<UserData>(_userDataBoxName);
    return box.get(_userDataKey)!;
  }

  // Update streak on app launch
  void updateStreak() {
    final userData = getUserData();
    userData.updateStreak(DateTime.now());
  }

  // Add XP and return true if leveled up
  bool addXp(int amount) {
    final userData = getUserData();
    return userData.addXp(amount);
  }

  // Increment stats
  void incrementQuizzesTaken() {
    final userData = getUserData();
    userData.totalQuizzesTaken++;
    userData.save();
  }

  // Get current streak
  int getCurrentStreak() {
    return getUserData().currentStreak;
  }

  // Get current level
  int getCurrentLevel() {
    return getUserData().level; // using standardized level field
  }

  // Get total XP
  int getTotalXp() {
    return getUserData().totalXp;
  }

  // Get level progress (0.0 to 1.0)
  double getLevelProgress() {
    return getUserData().levelProgress;
  }

  // Get XP for next level
  int getXpForNextLevel() {
    return getUserData().xpForNextLevel;
  }

  // Check if user can play free daily quiz
  bool canPlayFreeQuiz() {
    final userData = getUserData();
    if (userData.lastFreeQuizDate == null) return true;
    
    final today = DateTime.now();
    final lastQuiz = userData.lastFreeQuizDate!;
    
    // Check if it's a different day
    return today.year != lastQuiz.year ||
           today.month != lastQuiz.month ||
           today.day != lastQuiz.day;
  }

  // Mark that user played free quiz today
  void markFreeQuizPlayed() {
    final userData = getUserData();
    userData.lastFreeQuizDate = DateTime.now();
    userData.save();
  }

  // Get last free quiz date
  DateTime? getLastFreeQuizDate() {
    return getUserData().lastFreeQuizDate;
  }

  /// Load user data from Firestore and sync with local Hive
  /// Returns true if user data was loaded from Firestore
  Future<bool> loadUserDataFromFirestore(String uid) async {
    try {
      print('📥 Loading user data from Firestore for UID: $uid');
      
      // Ana kullanıcı dokümanını al
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        print('⚠️ No Firestore document found for user $uid');
        return false;
      }
      
      final data = userDoc.data()!;
      print('✅ Firestore user data loaded: ${data.keys.join(', ')}');
      
      // Ana kullanıcı dokümanından veri al (streak ve level burada)
      Map<String, dynamic> statsData = data;
      
      // Create UserData from Firestore data, öncelikle stats koleksiyonundan al, yoksa ana dokümanı kullan
      // Type guards for numeric fields to prevent FieldValue type errors
      final rawCurrentStreak = statsData['currentStreak'] ?? data['currentStreak'];
      final currentStreak = rawCurrentStreak is int ? rawCurrentStreak : 0;
      
      final rawLongestStreak = statsData['longestStreak'] ?? data['longestStreak'];
      final longestStreak = rawLongestStreak is int ? rawLongestStreak : 0;
      
      final rawTotalXp = statsData['totalXp'] ?? data['totalXp'];
      final totalXp = rawTotalXp is int ? rawTotalXp : 0;
      
      final rawLevel = statsData['level'] ?? statsData['currentLevel'] ?? data['level'] ?? data['currentLevel'];
      final level = rawLevel is int ? rawLevel : 1;
      
      final rawTotalWordsLearned = statsData['learnedWordsCount'] ?? data['totalWordsLearned'];
      final totalWordsLearned = rawTotalWordsLearned is int ? rawTotalWordsLearned : 0;
      
      final rawTotalQuizzesTaken = statsData['totalQuizzesCompleted'] ?? data['totalQuizzesTaken'];
      final totalQuizzesTaken = rawTotalQuizzesTaken is int ? rawTotalQuizzesTaken : 0;
      
      final userData = UserData(
        lastLoginDate: (statsData['lastLoginDate'] as Timestamp?)?.toDate() ?? 
                      (data['lastLoginAt'] as Timestamp?)?.toDate() ?? 
                      DateTime.now(),
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        totalXp: totalXp,
        level: level, // using standardized level field
        totalWordsLearned: totalWordsLearned,
        totalQuizzesTaken: totalQuizzesTaken,
        lastFreeQuizDate: (data['lastFreeQuizDate'] as Timestamp?)?.toDate(),
      );
      
      // Save to Hive
      final box = Hive.box<UserData>(_userDataBoxName);
      await box.put(_userDataKey, userData);
      
      print('✅ User data synced to Hive with values:');
      print('   Current Streak: ${userData.currentStreak}');
      print('   Longest Streak: ${userData.longestStreak}');
      print('   Level: ${userData.level}'); // using standardized level field
      print('   Total XP: ${userData.totalXp}');
      
      return true;
    } catch (e) {
      print('❌ Error loading user data from Firestore: $e');
      return false;
    }
  }

  /// Sync local Hive data to Firestore
  Future<void> syncToFirestore(String uid) async {
    try {
      final userData = getUserData();
      
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'currentStreak': userData.currentStreak,
        'longestStreak': userData.longestStreak,
        'totalXp': userData.totalXp,
        'level': userData.level, // using standardized level field
        'totalWordsLearned': userData.totalWordsLearned,
        'totalQuizzesTaken': userData.totalQuizzesTaken,
        'lastFreeQuizDate': userData.lastFreeQuizDate != null 
            ? Timestamp.fromDate(userData.lastFreeQuizDate!)
            : null,
      });
      
      print('✅ User data synced to Firestore');
    } catch (e) {
      print('❌ Error syncing to Firestore: $e');
    }
  }

  /// Reset local user data to default values (for new users or guest mode)
  Future<void> resetToDefault() async {
    final box = Hive.box<UserData>(_userDataBoxName);
    final userData = UserData(
      lastLoginDate: DateTime.now(),
      currentStreak: 0,
      longestStreak: 0,
      totalXp: 0,
      level: 1, // standardized level field
      totalWordsLearned: 0,
      totalQuizzesTaken: 0,
    );
    await box.put(_userDataKey, userData);
    print('✅ User data reset to default');
  }

  /// Update user statistics atomically
  Future<void> updateUserStats({
    required String userId,
    int? totalXp,
    int? learnedWordsCount,
    int? totalQuizzesCompleted,
    int? favoritesCount,
    int? currentStreak,
    int? longestStreak,
    int? level,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      
      final updateData = <String, dynamic>{};
      
      if (totalXp != null) updateData['totalXp'] = totalXp;
      if (learnedWordsCount != null) updateData['learnedWordsCount'] = learnedWordsCount;
      if (totalQuizzesCompleted != null) updateData['totalQuizzesCompleted'] = totalQuizzesCompleted;
      if (favoritesCount != null) updateData['favoritesCount'] = favoritesCount;
      if (currentStreak != null) updateData['currentStreak'] = currentStreak;
      if (longestStreak != null) updateData['longestStreak'] = longestStreak;
      if (level != null) updateData['level'] = level;
      
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          transaction.update(docRef, updateData);
        } else {
          // kullanıcı dokümanı yoksa oluştur
          transaction.set(docRef, updateData);
        }
      });
      
      Logger.i('📊 User stats updated: $updateData', 'UserService');
    } catch (e) {
      Logger.e('Failed to update user stats', e, null, 'UserService');
      throw e;
    }
  }

  /// Load user data with standardized field names
  Future<UserData?> loadUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        Logger.w('User document not found for ID: $userId', 'UserService');
        return null;
      }

      final data = doc.data()!;
      Logger.i('📊 Loading user data: totalXp=${data['totalXp']}, learnedWords=${data['learnedWordsCount']}, quizzes=${data['totalQuizzesCompleted']}', 'UserService');

      // Map Firestore fields to UserData with standardized names
      final userData = UserData(
        lastLoginDate: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        currentStreak: data['currentStreak'] ?? 0,
        longestStreak: data['longestStreak'] ?? 0,
        totalXp: data['totalXp'] ?? 0, // Standardized field name
        level: data['level'] ?? data['currentLevel'] ?? 1, // standardized level field
        totalWordsLearned: data['learnedWordsCount'] ?? 0, // Map to standardized field
        totalQuizzesTaken: data['totalQuizzesCompleted'] ?? 0, // Map to standardized field
        lastFreeQuizDate: (data['lastFreeQuizDate'] as Timestamp?)?.toDate(),
      );

      // Cache in Hive for offline access
      await _saveUserDataToHive(userData);
      
      Logger.i('✅ User data loaded and cached successfully', 'UserService');
      return userData;
    } catch (e) {
      Logger.e('Failed to load user data', e, null, 'UserService');
      return await _loadUserDataFromHive(userId);
    }
  }

  /// Helper method to save UserData to Hive
  Future<void> _saveUserDataToHive(UserData userData) async {
    try {
      final box = Hive.box<UserData>(_userDataBoxName);
      await box.put(_userDataKey, userData);
    } catch (e) {
      Logger.e('Failed to save user data to Hive', e, null, 'UserService');
    }
  }

  /// Helper method to load UserData from Hive
  Future<UserData?> _loadUserDataFromHive(String userId) async {
    try {
      final box = Hive.box<UserData>(_userDataBoxName);
      return box.get(_userDataKey);
    } catch (e) {
      Logger.e('Failed to load user data from Hive', e, null, 'UserService');
      return null;
    }
  }
}
