import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data.dart';

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
  void incrementWordsLearned() {
    final userData = getUserData();
    userData.totalWordsLearned++;
    userData.save();
  }

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
    return getUserData().currentLevel;
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
      
      final rawCurrentLevel = statsData['currentLevel'] ?? data['currentLevel'];
      final currentLevel = rawCurrentLevel is int ? rawCurrentLevel : 1;
      
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
        currentLevel: currentLevel,
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
      print('   Current Level: ${userData.currentLevel}');
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
        'currentLevel': userData.currentLevel,
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
      currentLevel: 1,
      totalWordsLearned: 0,
      totalQuizzesTaken: 0,
    );
    await box.put(_userDataKey, userData);
    print('✅ User data reset to default');
  }
}
