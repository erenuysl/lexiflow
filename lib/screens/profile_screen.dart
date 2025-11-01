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
  
  // Local state for immediate UI updates
  String? _currentUsername;
  String? _currentAvatar;

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
      resizeToAvoidBottomInset: true,
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
          // Initialize local state if null
          _currentUsername ??= sessionService.currentUser?.displayName;
          _currentAvatar ??= sessionService.currentUser?.photoURL;
          
          final username = _currentUsername ?? 'Kullanıcı';
          final avatar = _currentAvatar ?? 'assets/icons/boy.svg';

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
    final favorites = sessionService.favoritesCount;
    final streak = profileStatsProvider.currentStreak; 

    // XP values for the progress bar - use new level system if available
    final currentXP = levelData?.xpIntoLevel ?? (stats.totalXp % stats.xpToNextLevel);
    final xpToNext = levelData?.xpNeeded ?? stats.xpToNextLevel;
    final totalXPForNextLevel = levelData?.levelEndXp ?? (stats.totalXp + stats.xpToNextLevel);

    // Level-up detection and banner trigger
    if (levelData != null && _lastKnownLevel != null && levelData.level > _lastKnownLevel!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          LevelUpBanner.show(context, levelData.level);
        }
      });
    }
    _lastKnownLevel = levelData?.level ?? level;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                    // Header Section (Avatar + Name + Level) - 220-240px
                    _buildPixelPerfectHeader(context, username, avatar, level, userId),
                    
                    const SizedBox(height: 12),
                    
                    // Achievement Badges Section
                    _buildAchievementBadges(context, stats),
                    
                    const SizedBox(height: 20),
                    
                    // Experience Card - max 130px height
                    _buildCompactXPCard(context, currentXP, totalXPForNextLevel, xpToNext),
                    
                    const SizedBox(height: 16),
                    
                    // Stats Grid (2x2) with proper spacing
                    _buildBalancedStatsGrid(context, learnedCount, quizzesCompleted, favorites, totalXP),
                    
                    const SizedBox(height: 16),
                    
                    // Daily Streak Card - full width with gradient
                    _buildStreakCard(context, streak),
                    
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            );
  }

  Widget _buildPixelPerfectHeader(BuildContext context, String username, String avatar, int level, String? userId) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Settings icon in top right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 20, top: 10),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                  icon: Icon(
                    Icons.settings_outlined, 
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          
          // Avatar with camera icon - 90-100px size
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: avatar.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              avatar,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 40,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showAvatarPicker(context, userId ?? ''),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface, 
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 18), // 16-20px spacing as specified
          
          // Name with edit icon
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                username,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => _showUsernameEditor(context, userId ?? ''),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Level chip with star icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6D4AFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_border_rounded,
                  size: 16,
                  color: Color(0xFF6D4AFF),
                ),
                const SizedBox(width: 4),
                Text(
                  'Level $level',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6D4AFF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactXPCard(BuildContext context, int currentXP, int totalXPForNextLevel, int xpToNext) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deneyim Puanı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currentXP / $totalXPForNextLevel XP',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: currentXP / totalXPForNextLevel,
            backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            'Bir sonraki seviyeye $xpToNext XP kaldı!',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancedStatsGrid(BuildContext context, int learnedCount, int quizzesCompleted, int favorites, int totalXP) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          _buildStatCard(
            context,
            icon: Icons.school_rounded,
            value: learnedCount.toString(),
            label: 'Öğrenilen Kelime',
            color: const Color(0xFF4CAF50),
          ),
          _buildStatCard(
            context,
            icon: Icons.quiz_rounded,
            value: quizzesCompleted.toString(),
            label: 'Tamamlanan Quiz',
            color: const Color(0xFF2196F3),
          ),
          _buildStatCard(
            context,
            icon: Icons.favorite_rounded,
            value: favorites.toString(),
            label: 'Favori Kelime',
            color: const Color(0xFFE91E63),
          ),
          _buildStatCard(
            context,
            icon: Icons.stars_rounded,
            value: totalXP.toString(),
            label: 'Toplam XP',
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 30,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, int streak) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Günlük Seri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$streak gün üst üste!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  streak.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Username editor dialog method
  void _showUsernameEditor(BuildContext context, String userId) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Kullanıcı Adını Düzenle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Yeni kullanıcı adı',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _updateUsername(context, userId, controller.text.trim(), dialogContext: context);
                // Navigator.pop satırı silindi - _updateUsername içinde yapılacak
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                    onTap: () => _updateAvatar(context, userId, avatarPath, dialogContext: context),
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

  void _showUsernameEditDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kullanıcı Adını Düzenle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Yeni kullanıcı adı',
              border: OutlineInputBorder(),
            ),
            maxLength: 20,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  // TODO: Implement username update logic
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kullanıcı adı güncellendi')),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }



  Future<void> _updateAvatar(BuildContext context, String userId, String avatarPath, {required BuildContext dialogContext}) async {
    // Referansları tanımla
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final leaderboardDocRef = FirebaseFirestore.instance.collection('leaderboard_stats').doc(userId);

    try {
      // Batch write başlat
      final batch = FirebaseFirestore.instance.batch();

      // 1. users koleksiyonunu güncelle
      batch.update(userDocRef, {'photoURL': avatarPath});

      // 2. leaderboard_stats koleksiyonunu güncelle
      batch.update(leaderboardDocRef, {'photoURL': avatarPath});
      
      // 3. FirebaseAuth kullanıcısını güncelle (photoURL alanını avatar path'i olarak kullanıyoruz)
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(avatarPath);

      // Batch işlemlerini uygula
      await batch.commit();
      
      // Servisleri ve local state'i yenile
      await FirebaseAuth.instance.currentUser?.reload();
      context.read<SessionService>().refreshUser();

      if (mounted) {
        setState(() {
          _currentAvatar = avatarPath; // Anında UI güncellemesi
        });
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.greenAccent.shade400,
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Avatar başarıyla güncellendi!', style: TextStyle(color: Colors.white))),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.redAccent,
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Avatar güncellenirken hata oluştu: $e', style: const TextStyle(color: Colors.white))),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateUsername(BuildContext context, String userId, String newUsername, {required BuildContext dialogContext}) async {
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.redAccent,
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Kullanıcı adı boş olamaz!', style: TextStyle(color: Colors.white))),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Kullanıcı adı benzersizlik kontrolü - basit yaklaşım
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: newUsername)
          .limit(5) // performans için sınırla
          .get();

      // Kendi dokümanımızı hariç tut
      final otherUsersWithSameUsername = query.docs
          .where((doc) => doc.id != userId)
          .toList();

      if (otherUsersWithSameUsername.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.redAccent,
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Bu kullanıcı adı zaten alınmış!', style: TextStyle(color: Colors.white))),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

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
          'photoURL': FirebaseAuth.instance.currentUser?.photoURL ?? 'assets/icons/boy.svg',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Firebase Auth kullanıcı adını güncelle
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newUsername);
      
      // Commit the batch
      await batch.commit();
      
      // Firebase Auth kullanıcısını yenile
      await FirebaseAuth.instance.currentUser?.reload();
      context.read<SessionService>().refreshUser();
      
      if (mounted) {
        setState(() {
          _currentUsername = newUsername; // Anında UI güncellemesi
        });
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.greenAccent.shade400,
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Kullanıcı adı başarıyla güncellendi!', style: TextStyle(color: Colors.white))),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.redAccent,
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Kullanıcı adı güncellenirken hata oluştu: $e', style: const TextStyle(color: Colors.white))),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildAchievementBadges(BuildContext context, AggregatedProfileStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBadge(
            context,
            icon: Icons.military_tech_rounded,
            label: 'Kelime',
            color: const Color(0xFFFFC107),
            currentValue: stats.learnedWordsCount,
            baseTarget: 100,
          ),
          _buildBadge(
            context,
            icon: Icons.local_fire_department_rounded,
            label: 'Gün Seri',
            color: const Color(0xFFD32F2F),
            currentValue: stats.currentStreak,
            baseTarget: 10,
          ),
          _buildBadge(
            context,
            icon: Icons.quiz_rounded,
            label: 'Quiz',
            color: const Color(0xFF1976D2),
            currentValue: stats.totalQuizzesCompleted,
            baseTarget: 25,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, {
    required IconData icon, 
    required String label, 
    required Color color,
    required int currentValue,
    required int baseTarget,
  }) {
    // Calculate the current milestone target
    int currentTarget = baseTarget;
    while (currentValue >= currentTarget) {
      currentTarget *= 2;
    }
    
    // Check if the badge is completed
    bool isCompleted = currentValue >= baseTarget;
    
    // Calculate progress for the current milestone
    double progress = currentValue / currentTarget;
    
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(isCompleted ? 1.0 : 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: color.withOpacity(isCompleted ? 1.0 : 0.4), 
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Show progress only if not at the first milestone completion
            if (currentValue < currentTarget) ...[
              const SizedBox(height: 4),
              Text(
                '$currentValue/$currentTarget',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color.withOpacity(0.7),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
