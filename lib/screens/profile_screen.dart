import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../services/level_service.dart';
import '../providers/profile_stats_provider.dart';
import '../models/aggregated_profile_stats.dart';
import '../widgets/username_edit_dialog.dart';
import '../widgets/level_up_banner.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> _availableAvatars = [
    'assets/icons/bear.svg',
    'assets/icons/boy.svg',
    'assets/icons/gamer.svg',
    'assets/icons/girl.svg',
    'assets/icons/hacker.svg',
    'assets/icons/rabbit.svg',
    'assets/icons/woman.svg',
  ];

  // Level-up detection
  int? _lastKnownLevel;

  @override
  void initState() {
    super.initState();
    
    // Delay initialization until widget is fully mounted to prevent disposal races
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final profileStatsProvider = context.read<ProfileStatsProvider>();
          profileStatsProvider.initializeForUser(user.uid);
          _syncUsernameToLeaderboard(user.uid, user.displayName ?? '');
        }
      }
    });
  }

  // Sync username to leaderboard_stats
  Future<void> _syncUsernameToLeaderboard(String userId, String displayName) async {
    try {
      await FirebaseFirestore.instance
          .collection('leaderboard_stats')
          .doc(userId)
          .update({'displayName': displayName});
      
      debugPrint('Username synced to leaderboard: $displayName');
    } catch (e) {
      debugPrint('Error syncing username to leaderboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<SessionService, ProfileStatsProvider>(
        builder: (context, sessionService, profileStatsProvider, child) {
          // SessionService henüz başlatılmadıysa loading göster
          if (!sessionService.isInitialized) {
            return _buildInitializingState();
          }

          if (!sessionService.isAuthenticated) {
            return const Center(
              child: Text('Lütfen giriş yapın'),
            );
          }

          final userId = sessionService.currentUser?.uid;
          if (userId == null) {
            return _buildAuthLoadingState();
          }

          // Use ProfileStatsProvider for unified stats
          final stats = profileStatsProvider.stats;
          final error = profileStatsProvider.error;
          
          // Show error state with retry option
          if (error != null) {
            return _buildErrorState(error, () {
              if (mounted) {
                profileStatsProvider.retry();
              }
            });
          }
          
          if (stats.isLoading) {
            return _buildLoadingState();
          }

          // Get user profile data (avatar, username) from SessionService
          final username = sessionService.currentUser?.displayName ?? 'Kullanıcı';
          final avatar = 'assets/icons/boy.svg'; // Default avatar, can be enhanced later

          return _buildProfileContent(context, sessionService, stats, username, avatar, userId);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Profil yükleniyor...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Profil yüklenemedi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden dene'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitializingState() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Oturum başlatılıyor...'),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthLoadingState() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Kimlik doğrulanıyor...'),
          ],
        ),
      ),
    );
  }



  Widget _buildPermissionErrorState() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Erişim İzNi Gerekli'),
            const SizedBox(height: 8),
            const Text(
              'Profil verilerinize erişim için giriş yapmanız gerekiyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Çıkış yap ve tekrar giriş yap
                FirebaseAuth.instance.signOut();
              },
              child: const Text('Tekrar Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, SessionService sessionService,
      AggregatedProfileStats stats, String username, String avatar, String? userId) {
    
    // Get level data from ProfileStatsProvider
    final profileStatsProvider = context.read<ProfileStatsProvider>();
    final levelData = profileStatsProvider.currentLevelData;
    
    // Use new level system if available, fallback to old system
    final level = levelData?.level ?? stats.level;
    final totalXP = stats.totalXp;
    final learnedCount = stats.learnedWordsCount; 
    final quizzesCompleted = stats.totalQuizzesCompleted; 
    final favorites = sessionService.favoritesCount; // Keep from SessionService for now
    final streak = stats.currentStreak; 
    final longestStreak = stats.longestStreak;

    // XP values for the progress bar - use new level system if available
    final currentXP = levelData?.xpIntoLevel ?? (stats.totalXp % stats.xpToNextLevel);
    final xpToNext = levelData?.xpNeeded ?? stats.xpToNextLevel;

    // Level-up detection and banner trigger
    if (levelData != null && _lastKnownLevel != null && levelData.level > _lastKnownLevel!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          LevelUpBanner.show(context, levelData.level);
        }
      });
    }
    _lastKnownLevel = levelData?.level ?? level;

    // Log profile stats combination
    debugPrint('[PROFILE] stats <- xp=$totalXP, quizzes=$quizzesCompleted, learned=$learnedCount, level=$level');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            // Gradient Header
            _buildGradientHeader(context, username, level, avatar, userId ?? ''),
            
            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Deneyim Kartı
                  _buildXPCard(context, currentXP, xpToNext),
                  
                  const SizedBox(height: 24),
                  
                  // Stats Grid - Gerçek zamanlı veri doğrulama ile
                  _buildStatsGrid(context, userId ?? '', learnedCount, quizzesCompleted, favorites, totalXP),
                  
                  const SizedBox(height: 24),
                  
                  // Günlük Seri
                  _buildStreakSection(context, streak, longestStreak),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader(BuildContext context, String username, int level, String avatar, String userId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4FACFE), Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Action Icons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                  );
                },
                icon: const Icon(Icons.bar_chart_outlined, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Avatar with Camera Icon
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                ),
                child: ClipOval(
                  child: Container(
                    color: Colors.white.withOpacity(0.1),
                    child: SvgPicture.asset(
                      avatar,
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showAvatarPicker(context, userId),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: Color(0xFF8E2DE2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Username with Edit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Merhaba, $username!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showUsernameEditDialog(context, userId, username),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Level Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              'Level $level',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPCard(BuildContext context, int currentXP, int xpToNext) {
    final progress = currentXP / xpToNext;
    final xpNeeded = xpToNext - currentXP;
    
    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        final weeklyXp = sessionService.weeklyXp;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deneyim Puanı',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$currentXP / $xpToNext XP',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 8,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  xpNeeded > 0 ? 'Bir sonraki seviyeye $xpNeeded XP kaldı!' : 'Seviye atlamaya hazır!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                
                // haftalık XP bilgisi
                if (weeklyXp > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today, // haftalık XP için uygun icon
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bu hafta: $weeklyXp XP',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, String userId, int learnedWordsCount, 
      int quizzesCompleted, int favorites, int totalXP) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        final crossAxisCount = isWideScreen ? 3 : 2;
        
        return Column(
          children: [
            // Use ProfileStatsProvider as single source of truth for learned count
            Consumer<ProfileStatsProvider>(
              builder: (context, profileProvider, child) {
                final learnedCount = profileProvider.learnedCount;
                
                final stats = [
                  {
                    'title': 'Öğrenilen Kelime',
                    'value': learnedCount.toString(),
                    'icon': Icons.school_outlined,
                    'color': Theme.of(context).colorScheme.primary,
                  },
                  {
                    'title': 'Quiz Sayısı',
                    'value': quizzesCompleted.toString(),
                    'icon': Icons.quiz_outlined,
                    'color': Theme.of(context).colorScheme.secondary,
                  },
                  {
                    'title': 'Favoriler',
                    'value': favorites.toString(),
                    'icon': Icons.favorite_border_rounded,
                    'color': Colors.red,
                  },
                  {
                    'title': 'Toplam XP',
                    'value': totalXP.toString(),
                    'icon': Icons.star_rounded,
                    'color': Colors.amber,
                  },
                ];

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final stat = stats[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          border: Border.all(
                            color: (stat['color'] as Color).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              stat['icon'] as IconData,
                              size: 32,
                              color: stat['color'] as Color,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              stat['value'] as String,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: stat['color'] as Color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stat['title'] as String,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreakSection(BuildContext context, int streak, int longestStreak) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.orange.withOpacity(0.1),
              Colors.red.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔥',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Günlük Seri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              '$streak gün üst üste!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'En uzun seri: $longestStreak gün',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Avatar Seç',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _availableAvatars.length,
                itemBuilder: (context, index) {
                  final avatarPath = _availableAvatars[index];
                  return GestureDetector(
                    onTap: () => _updateAvatar(context, userId, avatarPath),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SvgPicture.asset(
                              avatarPath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUsernameEditDialog(BuildContext context, String userId, String currentUsername) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UsernameEditDialog(
        currentUsername: currentUsername,
        onSave: (newUsername) => _updateUsername(context, userId, newUsername),
      ),
    );
  }

  Future<void> _updateAvatar(BuildContext context, String userId, String avatarPath) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'avatar': avatarPath});
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar güncellenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateUsername(BuildContext context, String userId, String newUsername) async {
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı boş olamaz!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Define document references
      final userDataRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      
      final leaderboardRef = FirebaseFirestore.instance
          .collection('leaderboard_stats')
          .doc(userId);

      // PHASE 1: Perform all reads first (before batch operations)
      final userDataDoc = await userDataRef.get();
      final leaderboardDoc = await leaderboardRef.get();

      // PHASE 2: Create batch and perform all writes
      final batch = FirebaseFirestore.instance.batch();

      // Update user_data stats
      batch.update(userDataRef, {
        'username': newUsername,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update or create leaderboard_stats document
      if (leaderboardDoc.exists) {
        batch.update(leaderboardRef, {
          'displayName': newUsername,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create leaderboard entry with current user data if it doesn't exist
        final userData = userDataDoc.data() as Map<String, dynamic>?;
        batch.set(leaderboardRef, {
          'userId': userId,
          'displayName': newUsername,
          'currentLevel': userData?['level'] ?? 1,
          'highestLevel': userData?['level'] ?? 1,
          'totalXp': userData?['totalXp'] ?? 0,
          'weeklyXp': 0,
          'currentStreak': userData?['currentStreak'] ?? 0,
          'longestStreak': userData?['longestStreak'] ?? 0,
          'quizzesCompleted': userData?['quizzesCompleted'] ?? 0,
          'learnedWordsCount': userData?['learnedWordsCount'] ?? userData?['wordsLearned'] ?? 0, // fallback for migration
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch
      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı adı başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kullanıcı adı güncellenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
