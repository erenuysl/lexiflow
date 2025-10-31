import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/logger.dart';
import 'sync_manager.dart';
import 'offline_storage_manager.dart';
import 'offline_auth_service.dart';
import 'user_service.dart';
import 'leaderboard_service.dart';
import 'weekly_xp_service.dart';
import 'level_service.dart';

/// Kullanıcı oturum durumunu ve verilerini yöneten servis
class SessionService extends ChangeNotifier {
  // Singleton pattern
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  // Firebase örnekleri
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Servis örnekleri
  final SyncManager _syncManager = SyncManager();
  final OfflineStorageManager _offlineStorageManager = OfflineStorageManager();
  
  // Core ready stream for UI to listen when critical services are ready
  final StreamController<bool> _coreReadyController = StreamController<bool>.broadcast();
  Stream<bool> get coreReadyStream => _coreReadyController.stream;
  bool _isCoreReady = false;
  bool get isCoreReady => _isCoreReady;

  // Kullanıcı verileri
  User? _user;
  OfflineGuestUser? _offlineUser;
  Map<String, dynamic>? _firestoreUserData;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isOfflineMode = false;

  // Gerçek zamanlı dinleyiciler
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  StreamSubscription<QuerySnapshot>? _leaderboardStatsSubscription;
  
  // aşırı rebuild'leri önlemek için notifyListeners debouncing
  Timer? _notifyDebounceTimer;
  static const Duration _notifyDebounceDelay = Duration(milliseconds: 100);

  // Getter'lar
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null || _offlineUser != null;
  bool get isGuest => _user?.isAnonymous ?? _offlineUser?.isAnonymous ?? false;
  bool get isAnonymous => _user?.isAnonymous ?? _offlineUser?.isAnonymous ?? false;
  bool get isOfflineMode => _isOfflineMode;
  User? get currentUser => _user;
  OfflineGuestUser? get offlineUser => _offlineUser;
  
  // FieldValue hatalarını önlemek için güvenli tip dönüştürme ile kullanıcı istatistikleri getter'ları
  int get favoritesCount {
    final raw = _firestoreUserData?['favoritesCount'];
    return raw is int ? raw : 0;
  }
  
  int get level {
    // LevelService kullanarak totalXp'den level hesapla
    final totalXp = this.totalXp;
    final levelData = LevelService.computeLevelData(totalXp);
    final calculatedLevel = levelData.level;
    
    // migration için eski level değerlerini kontrol et
    final rawLevel = _firestoreUserData?['level'];
    final rawCurrentLevel = _firestoreUserData?['currentLevel'];
    final storedLevel = rawLevel is int ? rawLevel : (rawCurrentLevel is int ? rawCurrentLevel : 1);
    
    // hesaplanan level ile saklanan level arasında fark varsa log'la
    if (calculatedLevel != storedLevel) {
      Logger.w('Level mismatch in SessionService: calculated=$calculatedLevel, stored=$storedLevel, totalXp=$totalXp');
    }
    
    return calculatedLevel; // LevelService hesaplamasını kullan
  }
  
  int get totalXp {
    final raw = _firestoreUserData?['totalXp'];
    return raw is int ? raw : 0;
  }
  
  int get currentStreak {
    final raw = _firestoreUserData?['currentStreak'];
    return raw is int ? raw : 0;
  }
  
  int get longestStreak {
    final raw = _firestoreUserData?['longestStreak'];
    return raw is int ? raw : 0;
  }
  
  int get learnedWordsCount {
    final raw = _firestoreUserData?['learnedWordsCount'];
    return raw is int ? raw : 0;
  }
  
  int get totalQuizzesTaken {
    final raw = _firestoreUserData?['totalQuizzesTaken'];
    return raw is int ? raw : 0;
  }
  
  int get weeklyXp {
    final raw = _firestoreUserData?['weeklyXp'];
    return raw is int ? raw : 0;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final perfTask = Logger.startPerformanceTask('initialize_session', 'SessionService');
    try {
      _isLoading = true;
      notifyListeners();
      
      // PHASE 1: Critical initialization - user auth and basic data
      await _initializeCriticalServices();
      
      // Mark core as ready for UI
       _isCoreReady = true;
       _coreReadyController.add(true);
       debugPrint('I/flutter: [SESSION] coreReady=true (non-critical continue in bg)');
       Logger.i('🚀 Core services ready - UI can proceed', 'SessionService');
      
      // PHASE 2: Non-critical initialization - can happen in background
      _initializeNonCriticalServices();
      
      _isInitialized = true;
      _isLoading = false;
      
      Logger.i('SessionService initialized', 'SessionService');
    } catch (e) {
      _isLoading = false;
      _isInitialized = true; // hata olsa bile service initialize sayılsın
      Logger.e('Failed to initialize SessionService', e, null, 'SessionService');
    } finally {
      // Ensure perfTask.finish() is always called safely
      Logger.finishPerformanceTask(perfTask, 'SessionService', 'initialize');
      notifyListeners();
    }
  }
  
  /// Phase 1: Critical services that must complete before UI can proceed
  Future<void> _initializeCriticalServices() async {
    Logger.i('🔄 Initializing critical services...', 'SessionService');
    
    // İlk olarak Firebase auth durumunu kontrol et
    _user = _auth.currentUser;
    
    if (_user != null) {
      // Firebase kullanıcısı mevcut - Firebase modunu kullan
      _isOfflineMode = false;
      _offlineUser = null; // Mevcut offline kullanıcıyı temizle
      
      // Tüm gerekli alt koleksiyonlarla birlikte kullanıcı dokümanının var olduğundan emin ol
      await ensureUserDocumentExists(_user!);
      await _loadUserData();
      Logger.i('✅ Critical: Firebase session restored: ${_user?.uid}', 'SessionService');
    } else {
      // No Firebase user - check for offline session
      final isOfflineSessionActive = await OfflineAuthService.isOfflineSessionActive();
      if (isOfflineSessionActive) {
        _offlineUser = await OfflineAuthService.getCurrentOfflineUser();
        if (_offlineUser != null) {
          _isOfflineMode = true;
          await _loadOfflineUserData();
          Logger.i('✅ Critical: Offline session restored: ${_offlineUser?.uid}', 'SessionService');
        }
      } else {
        // No existing session found - let the user choose sign-in method
        Logger.i('✅ Critical: No existing session found, waiting for user action', 'SessionService');
      }
    }
  }
  
  /// Phase 2: Non-critical services that can initialize in background
  void _initializeNonCriticalServices() {
    Logger.i('🔄 Starting non-critical services in background...', 'SessionService');
    
    // Run non-critical initialization in background
    Future.microtask(() async {
      try {
        if (_user != null) {
          // Check if this is a new user for leaderboard initialization
          final userRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
          final userDoc = await userRef.get();
          final isNewUser = !userDoc.exists;
          
          // 🔥 CRITICAL FIX: Only initialize leaderboard stats for NEW users
          if (isNewUser) {
            Logger.i('👤 Non-critical: NEW USER - Initializing leaderboard stats for ${_user!.uid}', 'SessionService');
            await LeaderboardService().updateUserStats(_user!.uid);
          } else {
            Logger.i('👤 Non-critical: EXISTING USER - Skipping leaderboard initialization for ${_user!.uid}', 'SessionService');
          }
          
          // Set up real-time listeners after core initialization
          _setupRealTimeListener();
        }
        
        Logger.i('✅ Non-critical services initialized', 'SessionService');
      } catch (e) {
        Logger.e('Non-critical service initialization failed (app continues normally)', e, null, 'SessionService');
      }
    });
  }

  /// Tüm gerekli alt koleksiyonlarla birlikte Firestore'da kullanıcı dokümanının var olduğundan emin ol
  /// Yeni kullanıcıysa (ilk kez giriş) true döndürür
  Future<void> ensureUserDocumentExists(User firebaseUser) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set({
        'username': firebaseUser.displayName ?? 'User',
        'email': firebaseUser.email ?? null,
        'photoURL': firebaseUser.photoURL ?? 'assets/icons/boy.svg',
        'level': 1,
        'totalXp': 0,
        'learnedWordsCount': 0,
        'favoritesCount': 0,
        'totalQuizzesTaken': 0,
        'totalCorrectAnswers': 0,
        'totalWrongAnswers': 0,
        'currentStreak': 0,
        'longestStreak': 0,
        'lastLoginDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await userRef.update({
        'lastLoginDate': FieldValue.serverTimestamp(),
        'email': firebaseUser.email ?? null,
        'photoURL': firebaseUser.photoURL ?? 'assets/icons/boy.svg',
      });
    }
  }

  /// Firestore'dan kullanıcı verilerini yükle
  Future<void> _loadUserData() async {
    if (_user == null) return;
    
    try {
      final docRef = _firestore
          .collection('users')
          .doc(_user!.uid);
      
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        // Ana kullanıcı dokümanından mevcut istatistikleri yükle
        _firestoreUserData = docSnapshot.data();
        Logger.i('Loaded existing user stats for ${_user!.uid}: totalXp=${_firestoreUserData?['totalXp']}, level=${_firestoreUserData?['level']}, currentStreak=${_firestoreUserData?['currentStreak']}', 'SessionService');
      } else {
        // ensureUserDocumentExists dokümanı oluşturduğu için bu olmamalı
        Logger.w('User document does not exist for ${_user!.uid}', 'SessionService');
        _firestoreUserData = {};
      }
      
      // Real-time listener will be set up in non-critical phase
    } catch (e) {
      Logger.e('Failed to load user data', e, null, 'SessionService');
    }
  }

  /// Yerel depolamadan offline kullanıcı verilerini yükle
  Future<void> _loadOfflineUserData() async {
    if (_offlineUser == null) return;
    
    // Don't reload if we already have data loaded for this user and we're in offline mode
    // This prevents overwriting updated XP data with old cached data
    if (_firestoreUserData != null && _isOfflineMode) {
      Logger.i('⏭️ Skipping offline data reload - data already loaded for ${_offlineUser!.uid}', 'SessionService');
      Logger.i('📊 Current cached data: totalXp=${_firestoreUserData!['totalXp']}, level=${_firestoreUserData!['level'] ?? _firestoreUserData!['currentLevel']}', 'SessionService');
      return;
    }
    
    try {
      final userData = await _offlineStorageManager.loadUserData(_offlineUser!.uid);
      if (userData != null) {
        // Only update if we don't have data or if the loaded data is different
        if (_firestoreUserData == null || 
            _firestoreUserData!['totalXp'] != userData['totalXp'] ||
            (_firestoreUserData!['level'] ?? _firestoreUserData!['currentLevel']) != (userData['level'] ?? userData['currentLevel'])) {
          _firestoreUserData = userData;
          Logger.i('📥 Loaded offline user data for ${_offlineUser!.uid}: totalXp=${userData['totalXp']}, level=${userData['level'] ?? userData['currentLevel']}', 'SessionService');
        } else {
          Logger.i('📊 Offline data unchanged, keeping current cache', 'SessionService');
        }
      } else {
        // Create default offline user data only if we don't have any data
        if (_firestoreUserData == null) {
          _firestoreUserData = {
            'favoritesCount': 0,
            'level': 1, // standardized level field
            'totalXp': 0,
            'currentStreak': 0,
            'longestStreak': 0,
            'learnedWordsCount': 0,
            'totalQuizzesTaken': 0,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          };
          
          await _offlineStorageManager.saveUserData(_offlineUser!.uid, _firestoreUserData!);
          Logger.i('🆕 Created default offline user data for ${_offlineUser!.uid}', 'SessionService');
        }
      }
      _isOfflineMode = true;
    } catch (e) {
      Logger.e('Failed to load offline user data', e, null, 'SessionService');
    }
  }

  /// Create a mock Firebase User for offline compatibility
  User? _createMockFirebaseUser(OfflineGuestUser offlineUser) {
    // This is a simplified mock - in a real implementation you might need
    // a more sophisticated mock or wrapper class
    return null; // For now, we'll handle offline users separately
  }
  
  /// Set the user service for this session
  void setUserService(UserService userService) {
    // Implementation for connecting user service
    Logger.i('UserService connected to SessionService', 'SessionService');
  }
  
  /// Update user streak
  Future<void> updateStreak() async {
    if (_user == null) return;
    
    try {
      final now = DateTime.now();
      final lastLoginDate = _firestoreUserData?['lastLoginDate']?.toDate() ?? now;
      final currentStreak = _firestoreUserData?['currentStreak'] ?? 0;
      final longestStreak = _firestoreUserData?['longestStreak'] ?? 0;
      
      // Check if last login was yesterday
      final isConsecutiveDay = now.difference(lastLoginDate).inDays == 1;
      
      final newStreak = isConsecutiveDay ? currentStreak + 1 : 1;
      final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;
      
      await updateUserData({
        'currentStreak': newStreak,
        'longestStreak': newLongestStreak,
        'lastLoginDate': FieldValue.serverTimestamp(),
      });
      
      Logger.i('Updated user streak: $newStreak', 'SessionService');
    } catch (e) {
      Logger.e('Failed to update streak', e, null, 'SessionService');
    }
  }
  
  /// Add XP to user account
  Future<void> addXp(int amount) async {
    print('🔍 addXp called with amount: $amount');
    print('🔍 _user: $_user');
    print('🔍 _offlineUser: $_offlineUser');
    print('🔍 _isOfflineMode: $_isOfflineMode');
    print('🔍 amount <= 0: ${amount <= 0}');
    
    if ((_user == null && _offlineUser == null) || amount <= 0) {
      print('❌ addXp returning early - user check failed or amount <= 0');
      return;
    }
    
    print('✅ addXp proceeding with XP addition');
    
    try {
      final userId = _user?.uid;
      if (userId == null) {
        Logger.e('Cannot add XP: user ID is null', 'SessionService');
        return;
      }

      // Use WeeklyXpService for comprehensive XP tracking (total + weekly)
      await WeeklyXpService.addXp(userId, amount);

      // Log XP addition
      debugPrint('[XP] +$amount → leaderboard_stats with weekly tracking (uid=$userId)');
      
      Logger.i('✅ XP Added successfully: $amount via WeeklyXpService', 'SessionService');
    } catch (e) {
      Logger.e('Failed to add XP', e, null, 'SessionService');
    }
  }
  
  /// Check if display name is unique
  Future<bool> isDisplayNameUnique(String displayName) async {
    if (_user == null) return false;
    
    try {
      final snapshot = await _firestore
          .collection('leaderboard_stats')
          .where('displayName', isEqualTo: displayName)
          .where(FieldPath.documentId, isNotEqualTo: _user!.uid)
          .limit(1)
          .get();
      
      return snapshot.docs.isEmpty;
    } catch (e) {
      Logger.e('Error checking display name uniqueness', e, null, 'SessionService');
      return false;
    }
  }

  /// Update display name with uniqueness check
  Future<Map<String, dynamic>> updateDisplayName(String displayName) async {
    if (_user == null) {
      return {'success': false, 'error': 'Kullanıcı oturumu bulunamadı'};
    }
    
    try {
      // Check if the name is unique
      final isUnique = await isDisplayNameUnique(displayName);
      if (!isUnique) {
        return {'success': false, 'error': 'Bu isim zaten kullanılıyor. Lütfen farklı bir isim seçin.'};
      }

      // Update Firebase Auth display name
      await _user!.updateDisplayName(displayName);
      
      // 🔥 CRITICAL FIX: Reload Firebase Auth user to get fresh data
      await _user!.reload();
      _user = _auth.currentUser; // Get the updated user object
      
      // Update user_data collection
      await updateUserData({'displayName': displayName});
      
      // 🔥 CRITICAL FIX: Update leaderboard_stats collection with new displayName
      await _updateLeaderboardDisplayName(displayName);
      
      notifyListeners();
      Logger.i('Updated display name to: $displayName', 'SessionService');
      return {'success': true, 'message': 'İsminiz başarıyla güncellendi!'};
    } catch (e) {
      Logger.e('Failed to update display name', e, null, 'SessionService');
      return {'success': false, 'error': 'İsim güncellenirken bir hata oluştu'};
    }
  }

  /// Update display name in leaderboard_stats collection
  Future<void> _updateLeaderboardDisplayName(String displayName) async {
    if (_user == null) return;
    
    try {
      final docRef = _firestore.collection('leaderboard_stats').doc(_user!.uid);
      final doc = await docRef.get();
      
      if (doc.exists) {
        await docRef.update({
          'displayName': displayName,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        Logger.i('Updated leaderboard displayName to: $displayName', 'SessionService');
      } else {
        // If leaderboard stats don't exist, create them with current user data
        final userData = _firestoreUserData ?? {};
        
        // LevelService kullanarak level hesapla
        final rawTotalXp = userData['totalXp'];
        final totalXp = rawTotalXp is int ? rawTotalXp : 0;
        final levelData = LevelService.computeLevelData(totalXp);
        final level = levelData.level;
        
        final rawHighestLevel = userData['highestLevel'];
        final highestLevel = rawHighestLevel is int ? rawHighestLevel : level;
        
        final rawWeeklyXp = userData['weeklyXp'];
        final weeklyXp = rawWeeklyXp is int ? rawWeeklyXp : 0;
        
        final rawCurrentStreak = userData['currentStreak'];
        final currentStreak = rawCurrentStreak is int ? rawCurrentStreak : 0;
        
        final rawLongestStreak = userData['longestStreak'];
        final longestStreak = rawLongestStreak is int ? rawLongestStreak : currentStreak;
        
        final rawQuizzesCompleted = userData['totalQuizzesCompleted'];
        final quizzesCompleted = rawQuizzesCompleted is int ? rawQuizzesCompleted : 0;
        
        final rawLearnedWordsCount = userData['learnedWordsCount'];
        final learnedWordsCount = rawLearnedWordsCount is int ? rawLearnedWordsCount : 0;
        
        await docRef.set({
          'userId': _user!.uid,
          'displayName': displayName,
          'photoURL': _user!.photoURL,
          'level': level, // standardized level field
          'highestLevel': highestLevel,
          'totalXp': totalXp,
          'weeklyXp': weeklyXp,
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'quizzesCompleted': quizzesCompleted,
          'learnedWordsCount': learnedWordsCount,
          'lastUpdated': FieldValue.serverTimestamp(),
          'weekResetDate': _getNextMondayMidnight(),
        });
        Logger.i('Created leaderboard stats with displayName: $displayName', 'SessionService');
      }
      
      // Note: Removed excessive cache clearing that was causing constant refreshes
      // The leaderboard will update naturally through Firestore real-time listeners
      // _clearLeaderboardCache();
      
    } catch (e) {
      Logger.e('Failed to update leaderboard displayName', e, null, 'SessionService');
    }
  }

  /// Clear leaderboard cache to force refresh
  void _clearLeaderboardCache() {
    try {
      // Import and clear LeaderboardService cache
      final leaderboardService = LeaderboardService();
      leaderboardService.clearCache();
      Logger.i('Cleared leaderboard cache after displayName update', 'SessionService');
    } catch (e) {
      Logger.e('Failed to clear leaderboard cache', e, null, 'SessionService');
    }
  }

  /// Update photo URL in leaderboard_stats collection
  Future<void> _updateLeaderboardPhotoURL(String photoURL) async {
    if (_user == null) return;
    
    try {
      final docRef = _firestore.collection('leaderboard_stats').doc(_user!.uid);
      final doc = await docRef.get();
      
      if (doc.exists) {
        await docRef.update({
          'photoURL': photoURL,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        Logger.i('Updated leaderboard photoURL', 'SessionService');
      } else {
        // If leaderboard stats don't exist, create them with current user data
        final userData = _firestoreUserData ?? {};
        
        // LevelService kullanarak level hesapla
        final rawTotalXp = userData['totalXp'];
        final totalXp = rawTotalXp is int ? rawTotalXp : 0;
        final levelData = LevelService.computeLevelData(totalXp);
        final level = levelData.level;
        
        final rawHighestLevel = userData['highestLevel'];
        final highestLevel = rawHighestLevel is int ? rawHighestLevel : level;
        
        final rawWeeklyXp = userData['weeklyXp'];
        final weeklyXp = rawWeeklyXp is int ? rawWeeklyXp : 0;
        
        final rawCurrentStreak = userData['currentStreak'];
        final currentStreak = rawCurrentStreak is int ? rawCurrentStreak : 0;
        
        final rawLongestStreak = userData['longestStreak'];
        final longestStreak = rawLongestStreak is int ? rawLongestStreak : currentStreak;
        
        final rawQuizzesCompleted = userData['totalQuizzesCompleted'];
        final quizzesCompleted = rawQuizzesCompleted is int ? rawQuizzesCompleted : 0;
        
        final rawLearnedWordsCount = userData['learnedWordsCount'];
        final learnedWordsCount = rawLearnedWordsCount is int ? rawLearnedWordsCount : 0;
        
        await docRef.set({
          'userId': _user!.uid,
          'displayName': _user!.displayName ?? 'Kullanıcı',
          'photoURL': photoURL,
          'level': level, // standardized level field
          'highestLevel': highestLevel,
          'totalXp': totalXp,
          'weeklyXp': weeklyXp,
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'quizzesCompleted': quizzesCompleted,
          'learnedWordsCount': learnedWordsCount,
          'lastUpdated': FieldValue.serverTimestamp(),
          'weekResetDate': _getNextMondayMidnight(),
        });
        Logger.i('Created leaderboard stats with photoURL', 'SessionService');
      }
      
      // Note: Removed excessive cache clearing that was causing constant refreshes
      // The leaderboard will update naturally through Firestore real-time listeners
      // _clearLeaderboardCache();
      
    } catch (e) {
      Logger.e('Failed to update leaderboard photoURL', e, null, 'SessionService');
    }
  }

  /// Get next Monday midnight for week reset
  DateTime _getNextMondayMidnight() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    final nextMonday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
  }
  
  /// Update photo URL
  Future<void> updatePhotoURL(String photoURL) async {
    if (_user == null) return;
    
    try {
      await _user!.updatePhotoURL(photoURL);
      
      // 🔥 CRITICAL FIX: Reload Firebase Auth user to get fresh data
      await _user!.reload();
      _user = _auth.currentUser; // Get the updated user object
      
      await updateUserData({'photoURL': photoURL});
      
      // 🔥 CRITICAL FIX: Update leaderboard_stats collection with new photoURL
      await _updateLeaderboardPhotoURL(photoURL);
      
      notifyListeners();
      Logger.i('Updated photo URL', 'SessionService');
    } catch (e) {
      Logger.e('Failed to update photo URL', e, null, 'SessionService');
    }
  }
  
  /// Sign out the current user
  Future<void> signOut() async {
    try {
      // Always clear local state first, regardless of network status
      _user = null;
      _firestoreUserData = null;
      // Keep _isInitialized = true to prevent AuthWrapper from showing loading screen
      // The service remains initialized, just without a user
      notifyListeners();
      
      if (_syncManager.isOnline) {
        await _auth.signOut();
        Logger.i('User signed out from Firebase', 'SessionService');
      } else {
        Logger.i('User signed out locally (offline mode)', 'SessionService');
      }
      
      await _offlineStorageManager.savePendingOperations([]);
      
    } catch (e) {
      // Firebase sign out fails, we've already cleared local state
      Logger.e('Error during sign out (local state cleared)', e, null, 'SessionService');
    }
  }
  
  /// Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      Logger.i('Starting Google Sign-In process', 'SessionService');
      
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        Logger.w('Google Sign-In cancelled by user', 'SessionService');
        return null;
      }
      
      Logger.i('Google account selected: ${googleUser.email}', 'SessionService');
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        Logger.e('Google authentication tokens are null', null, null, 'SessionService');
        return null;
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      Logger.i('Attempting Firebase authentication with Google credentials', 'SessionService');
      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      
      if (_user != null) {
        Logger.i('Loading user data after Google Sign-In for ${_user!.uid}', 'SessionService');
        
        final userRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
        final userDoc = await userRef.get();
        final isNewUser = !userDoc.exists;
        
        await ensureUserDocumentExists(_user!);
        
        await _loadUserData();
        notifyListeners();
        Logger.i('Google Sign-In successful: ${_user?.displayName} (${_user?.email})', 'SessionService');
        Logger.i('Final stats after Google Sign-In: totalXp=$totalXp, level=$level, currentStreak=$currentStreak', 'SessionService');
        
        // sadece YENİ kullanıcılar için leaderboard stats başlat
        if (isNewUser) {
          Logger.i('👤 NEW USER: Initializing leaderboard stats after Google Sign-In for ${_user!.uid}', 'SessionService');
          Logger.i('🔥 DEBUG: About to call LeaderboardService().updateUserStats for NEW user', 'SessionService');
          await LeaderboardService().updateUserStats(_user!.uid);
          Logger.i('✅ DEBUG: LeaderboardService().updateUserStats completed for NEW user', 'SessionService');
        } else {
          Logger.i('👤 EXISTING USER: Skipping leaderboard initialization after Google Sign-In for ${_user!.uid}', 'SessionService');
          Logger.i('🔥 DEBUG: NOT calling LeaderboardService().updateUserStats for EXISTING user - preventing data reset', 'SessionService');
        }
      } else {
        Logger.e('Firebase user is null after successful credential sign-in', null, null, 'SessionService');
      }
      
      return _user;
    } on FirebaseAuthException catch (e) {
      Logger.e('Firebase Auth error during Google Sign-In', e, null, 'SessionService');
      Logger.e('Error code: ${e.code}, message: ${e.message}', null, null, 'SessionService');
      return null;
    } catch (e, stackTrace) {
      Logger.e('Unexpected error during Google Sign-In', e, stackTrace, 'SessionService');
      return null;
    }
  }
  
  /// Sign in as guest (anonymous) with offline support
  Future<User?> signInAsGuest() async {
    try {
      Logger.i('Starting Anonymous Sign-In process', 'SessionService');
      
      final isOnline = _syncManager.isOnline;
      
      if (isOnline) {
        // online'dayken Firebase anonymous sign-in dene
        try {
          final userCredential = await _auth.signInAnonymously();
          _user = userCredential.user;
          _isOfflineMode = false;
          
          if (_user != null) {
            final userRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
            final userDoc = await userRef.get();
            final isNewUser = !userDoc.exists;
            
            await ensureUserDocumentExists(_user!);
            
            await _loadUserData();
            notifyListeners();
            Logger.i('Firebase Anonymous Sign-In successful: ${_user?.uid}', 'SessionService');
            
            // sadece YENİ kullanıcılar için leaderboard stats başlat
            if (isNewUser) {
              Logger.i('👤 NEW USER: Initializing leaderboard stats after Anonymous Sign-In for ${_user!.uid}', 'SessionService');
              Logger.i('🔥 DEBUG: About to call LeaderboardService().updateUserStats for NEW anonymous user', 'SessionService');
              await LeaderboardService().updateUserStats(_user!.uid);
              Logger.i('✅ DEBUG: LeaderboardService().updateUserStats completed for NEW anonymous user', 'SessionService');
            } else {
              Logger.i('👤 EXISTING USER: Skipping leaderboard initialization after Anonymous Sign-In for ${_user!.uid}', 'SessionService');
              Logger.i('🔥 DEBUG: NOT calling LeaderboardService().updateUserStats for EXISTING anonymous user - preventing data reset', 'SessionService');
            }
            
            return _user;
          }
        } on FirebaseAuthException catch (e) {
          Logger.w('Firebase Auth failed, falling back to offline mode', 'SessionService');
          Logger.w('Error code: ${e.code}, message: ${e.message}', 'SessionService');
        }
      }
      
      // offline mode veya Firebase başarısız - offline authentication kullan
      Logger.i('Using offline guest mode', 'SessionService');
      _offlineUser = await OfflineAuthService.createOfflineGuestUser();
      
      if (_offlineUser != null) {
        _isOfflineMode = true;
        _user = null; // offline olduğumuz için Firebase user'ı temizle
        
        await _loadOfflineUserData();
        notifyListeners();
        
        Logger.i('Offline Anonymous Sign-In successful: ${_offlineUser?.uid}', 'SessionService');
        return null; // offline user kullandığımız için Firebase User null döner
      } else {
        Logger.e('Failed to create offline guest user', null, null, 'SessionService');
        return null;
      }
      
    } catch (e, stackTrace) {
      Logger.e('Unexpected error during Guest Sign-In', e, stackTrace, 'SessionService');
      return null;
    }
  }
  
  /// Update leaderboard after quiz
  Future<void> updateLeaderboardAfterQuiz(int score) async {
    if (_user == null && _offlineUser == null) return;
    
    try {
      // hesaplanmış değerlerle local cache'i direkt güncelle
      final currentQuizzes = _firestoreUserData?['totalQuizzesTaken'] ?? 0;
      final currentXp = _firestoreUserData?['totalXp'] ?? 0;
      
      final updates = {
        'totalQuizzesTaken': currentQuizzes + 1,
        'totalXp': currentXp + score,
      };
      
      // Firestore sync için FieldValue güncellemeleri hazırla
      final firestoreUpdates = {
        'totalQuizzesTaken': FieldValue.increment(1),
        'totalXp': FieldValue.increment(score),
      };
      
      await updateUserData(updates);
      
      if (_user != null && !_isOfflineMode) {
        final userId = _user!.uid;
        await SyncManager().addOperation(
          path: 'users/$userId',
          type: SyncOperationType.update,
          data: firestoreUpdates,
        );
        
        debugPrint('🔥 DEBUG: Updating leaderboard stats after quiz - XP: $score, Quizzes: 1');
        await LeaderboardService().updateUserStats(
          userId,
          xpEarned: score,
          quizzesCompleted: 1,
          displayName: _user!.displayName ?? 'Anonymous',
          photoURL: _user!.photoURL,
        );
        debugPrint('✅ DEBUG: Leaderboard stats updated successfully after quiz');
      }
      
      Logger.i('Updated leaderboard after quiz with score: $score', 'SessionService');
    } catch (e) {
      Logger.e('Failed to update leaderboard after quiz', e, null, 'SessionService');
    }
  }
  
  /// Update leaderboard after word learned
  Future<void> updateLeaderboardAfterWordLearned(int xpGained) async {
    if ((_user == null && _offlineUser == null) || xpGained <= 0) return;
    
    try {
      final currentXp = _firestoreUserData?['totalXp'] ?? 0;
      
      final updates = {
        'totalXp': currentXp + xpGained,
      };
      
      final firestoreUpdates = {
        'totalXp': FieldValue.increment(xpGained),
      };
      
      await updateUserData(updates);
      
      if (_user != null && !_isOfflineMode) {
        final userId = _user!.uid;
        await SyncManager().addOperation(
          path: 'users/$userId',
          type: SyncOperationType.update,
          data: firestoreUpdates,
        );
        
        debugPrint('🔥 DEBUG: Updating leaderboard stats after word learned - XP: $xpGained');
        await LeaderboardService().updateUserStats(
          userId,
          xpEarned: xpGained,
          displayName: _user!.displayName ?? 'Anonymous',
          photoURL: _user!.photoURL,
        );
        debugPrint('✅ DEBUG: Leaderboard stats updated successfully after word learned');
      }
      
      Logger.i('Updated leaderboard after word learned with XP: $xpGained', 'SessionService');
    } catch (e) {
      Logger.e('Failed to update leaderboard after word learned', e, null, 'SessionService');
    }
  }
  
  /// Update user data with offline-first approach
  Future<void> updateUserData(Map<String, dynamic> data) async {
    if (_user == null && _offlineUser == null) return;
    
    final perfTask = Logger.startPerformanceTask('update_user_data', 'SessionService');
    try {
      final userId = _user?.uid ?? _offlineUser?.uid;
      if (userId == null) return;
      
      // FieldValue increment'leri local cache için işle
      final processedData = <String, dynamic>{};
      for (final entry in data.entries) {
        if (entry.value is FieldValue) {
          final fieldValue = entry.value as FieldValue;
          if (fieldValue.toString().contains('increment')) {
            final currentValue = _firestoreUserData?[entry.key] ?? 0;
            if (currentValue is int) {
              // increment işlemleri çağıran methodlarda halledilecek
              if (entry.key == 'totalXp' || entry.key == 'totalQuizzesTaken' || entry.key == 'learnedWordsCount') {
                continue;
              }
            }
          }
        } else {
          processedData[entry.key] = entry.value;
        }
      }
      
      // önce local in-memory state'i hemen güncelle
      _firestoreUserData = {
        if (_firestoreUserData != null) ..._firestoreUserData!,
        ...processedData,
      };
      
      Logger.i('📝 Updated local cache with: $processedData', 'SessionService');
      Logger.i('📊 New local data: totalXp=${_firestoreUserData!['totalXp']}, level=${_firestoreUserData!['level'] ?? _firestoreUserData!['currentLevel']}', 'SessionService');
      
      await OfflineStorageManager().saveUserData(userId, _firestoreUserData!);
      Logger.i('💾 Saved to offline storage for user: $userId', 'SessionService');
      
      // sadece online user için Firestore sync operation kuyruğa al
      if (_user != null && !_isOfflineMode) {
        await SyncManager().addOperation(
          path: 'users/$userId',
          type: SyncOperationType.update,
          data: data,
        );
        Logger.i('🔄 Queued sync operation for Firestore', 'SessionService');
      }
      
      notifyListeners();
      
      Logger.i('✅ updateUserData completed successfully', 'SessionService');
    } catch (e) {
      Logger.e('Failed to update user data', e, null, 'SessionService');
    } finally {
      Logger.finishPerformanceTask(perfTask, 'SessionService', 'updateUserData');
    }
  }

  /// Real-time stats synchronization method
  Future<void> refreshStats() async {
    if (_user == null) return;
    
    try {
      final docRef = _firestore.collection('users').doc(_user!.uid);
      final snapshot = await docRef.get();
      
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        
        // Update local cache with fresh Firestore data
        _firestoreUserData = {
          ..._firestoreUserData ?? {},
          'totalXp': data['totalXp'] ?? 0,
          'learnedWordsCount': data['learnedWordsCount'] ?? 0,
          'totalQuizzesCompleted': data['totalQuizzesCompleted'] ?? 0,
          'favoritesCount': data['favoritesCount'] ?? 0,
          'currentStreak': data['currentStreak'] ?? 0,
          'longestStreak': data['longestStreak'] ?? 0,
          'level': data['level'] ?? data['currentLevel'] ?? 1, // prioritize level field
        };
        
        Logger.i('📊 Stats refreshed: totalXp=${_firestoreUserData!['totalXp']}, learnedWords=${_firestoreUserData!['learnedWordsCount']}, quizzes=${_firestoreUserData!['totalQuizzesCompleted']}', 'SessionService');
        
        // Notify listeners for UI updates
        notifyListeners();
      }
    } catch (e) {
      Logger.e('Failed to refresh stats', e, null, 'SessionService');
    }
  }

  /// Enhanced real-time listener with proper field mapping
  void _setupRealTimeListener() {
    if (_user == null || _isOfflineMode) return;
    
    _userDataSubscription?.cancel();
    _leaderboardStatsSubscription?.cancel();
    
    try {
      final docRef = _firestore.collection('users').doc(_user!.uid);
      
      _userDataSubscription = docRef.snapshots().listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final newData = snapshot.data()!;
            
            // Override cache with fresh Firestore data (no merge)
            _firestoreUserData = {
              'totalXp': newData['totalXp'] ?? 0,
              'learnedWordsCount': newData['learnedWordsCount'] ?? 0,
              'totalQuizzesCompleted': newData['totalQuizzesCompleted'] ?? 0,
              'favoritesCount': newData['favoritesCount'] ?? 0,
              'currentStreak': newData['currentStreak'] ?? 0,
              'longestStreak': newData['longestStreak'] ?? 0,
              'level': newData['level'] ?? newData['currentLevel'] ?? 1, // prioritize level field
              'username': newData['username'],
              'avatar': newData['avatar'],
              'createdAt': newData['createdAt'],
              'updatedAt': newData['updatedAt'],
            };
            
            Logger.i('📡 Real-time update: totalXp=${newData['totalXp']}, learnedWords=${newData['learnedWordsCount']}, quizzes=${newData['totalQuizzesCompleted']}', 'SessionService');
            
            // Immediate UI notification
            notifyListeners();
          }
        },
        onError: (error) {
          Logger.e('Real-time listener error', error, null, 'SessionService');
        },
      );
      
      _setupLeaderboardStatsListener();
      
      Logger.i('📡 Enhanced real-time listener set up for user stats', 'SessionService');
    } catch (e) {
      Logger.e('Failed to set up real-time listener', e, null, 'SessionService');
    }
  }

  /// gereksiz güncellemeleri önlemek için verimli data karşılaştırması
  bool _isDataEqual(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    // UI güncellemeleri için önemli olan alanları karşılaştır
    final criticalFields = [
      'favoritesCount',
      'learnedWordsCount', 
      'totalXp',
      'level', // standardized level field
      'currentStreak',
      'longestStreak',
      'weeklyXp',
      'totalQuizzesTaken'
    ];
    
    for (final field in criticalFields) {
      if (oldData[field] != newData[field]) {
        return false;
      }
    }
    
    return true;
  }

  /// aşırı rebuild'leri önlemek için debounced notifyListeners
  void _debouncedNotifyListeners() {
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = Timer(_notifyDebounceDelay, () {
      notifyListeners();
    });
  }

  /// Set up real-time listener for leaderboard_stats collection
  void _setupLeaderboardStatsListener() {
    if (_user == null || _isOfflineMode) return;
    
    try {
      final userLeaderboardRef = _firestore
          .collection('leaderboard_stats')
          .where('userId', isEqualTo: _user!.uid)
          .limit(1);
      
      _leaderboardStatsSubscription = userLeaderboardRef.snapshots().listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final leaderboardData = snapshot.docs.first.data();
            
            // sadece anlamlı güncelleme varsa ve data gerçekten değiştiyse notify et
            if (_firestoreUserData != null) {
              final hasChanges = _firestoreUserData!['currentStreak'] != leaderboardData['currentStreak'] ||
                                _firestoreUserData!['longestStreak'] != leaderboardData['longestStreak'] ||
                                _firestoreUserData!['weeklyXp'] != leaderboardData['weeklyXp'];
              
              if (hasChanges) {
                Logger.i('📊 Leaderboard stats update: currentStreak=${leaderboardData['currentStreak']}, longestStreak=${leaderboardData['longestStreak']}, weeklyXp=${leaderboardData['weeklyXp']}', 'SessionService');
                
                _debouncedNotifyListeners();
              }
            }
          }
        },
        onError: (error) {
          Logger.e('Leaderboard stats listener error', error, null, 'SessionService');
        },
      );
      
      Logger.i('📊 Real-time listener set up for leaderboard stats', 'SessionService');
    } catch (e) {
      Logger.e('Failed to set up leaderboard stats listener', e, null, 'SessionService');
    }
  }

  /// Test method to verify synchronization between cached and Firestore data
  Future<void> testSynchronizationFix() async {
    print('🔄 SYNCHRONIZATION TEST STARTED');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ SYNC TEST: No authenticated user');
      return;
    }

    try {
      // Get fresh data from Firestore
      final freshDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!freshDoc.exists) {
        print('❌ SYNC TEST: User document does not exist');
        return;
      }

      final freshData = freshDoc.data()!;
      
      // Compare with cached data
      print('🔍 SYNC TEST: Comparing cached vs Firestore data');
      print('📊 Cached totalXp: ${_firestoreUserData?['totalXp']} | Firestore totalXp: ${freshData['totalXp']}');
      print('📊 Cached learnedWordsCount: ${_firestoreUserData?['learnedWordsCount']} | Firestore learnedWordsCount: ${freshData['learnedWordsCount']}');
      print('📊 Cached totalQuizzesCompleted: ${_firestoreUserData?['totalQuizzesCompleted']} | Firestore totalQuizzesCompleted: ${freshData['totalQuizzesCompleted']}');
      
      bool needsSync = false;
      
      if (_firestoreUserData?['totalXp'] != freshData['totalXp']) {
        print('⚠️ SYNC ISSUE: totalXp mismatch');
        needsSync = true;
      }
      
      if (_firestoreUserData?['learnedWordsCount'] != freshData['learnedWordsCount']) {
        print('⚠️ SYNC ISSUE: learnedWordsCount mismatch');
        needsSync = true;
      }
      
      if (_firestoreUserData?['totalQuizzesCompleted'] != freshData['totalQuizzesCompleted']) {
        print('⚠️ SYNC ISSUE: totalQuizzesCompleted mismatch');
        needsSync = true;
      }
      
      if (needsSync) {
        print('🔄 SYNC TEST: Triggering refreshStats()');
        await refreshStats();
        print('✅ SYNC TEST: Stats refreshed successfully');
      } else {
        print('✅ SYNC TEST: All data is synchronized');
      }
      
    } catch (e) {
      print('❌ SYNC TEST ERROR: $e');
    }
    
    print('🏁 SYNCHRONIZATION TEST COMPLETED');
  }

  /// Dispose resources
  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _leaderboardStatsSubscription?.cancel();
    _notifyDebounceTimer?.cancel();
    _coreReadyController.close();
    super.dispose();
  }
}
