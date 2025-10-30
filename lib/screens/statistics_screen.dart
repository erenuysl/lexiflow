// lib/screens/statistics_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session_service.dart';
import '../services/statistics_service.dart';
import '../utils/share_utils.dart';
import '../widgets/lexiflow_toast.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StatisticsService _statsService;

  // Yükleme durumu yönetimi
  final ValueNotifier<bool> _isStatsLoaded = ValueNotifier<bool>(false);
  final ValueNotifier<int> _loadingComponents = ValueNotifier<int>(0);
  final int _totalComponents = 3; // Genel Bakış, Haftalık Grafik, XP Grafiği

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _statsService = StatisticsService();
    
    // Yüklenen bileşen değişikliklerini dinle
    _loadingComponents.addListener(_checkAllComponentsLoaded);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _isStatsLoaded.dispose();
    _loadingComponents.dispose();
    super.dispose();
  }

  void _checkAllComponentsLoaded() {
    if (_loadingComponents.value >= _totalComponents) {
      _isStatsLoaded.value = true;
    }
  }

  void _onComponentLoaded() {
    _loadingComponents.value = _loadingComponents.value + 1;
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İstatistikler'),
        centerTitle: true,
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _isStatsLoaded,
            builder: (context, isLoaded, child) {
              return FutureBuilder<bool>(
                future: ShareUtils.isSharingAvailable(),
                builder: (context, snapshot) {
                  final isAvailable = snapshot.data ?? true;
                  final canShare = isAvailable && isLoaded;
                  
                  return IconButton(
                    icon: Icon(
                      Icons.share,
                      color: canShare 
                        ? null 
                        : Theme.of(context).disabledColor,
                    ),
                    onPressed: canShare 
                      ? () => _shareStats(sessionService, isDark)
                      : () => isAvailable 
                        ? _showLoadingMessage()
                        : _showOfflineMessage(),
                    tooltip: !isAvailable 
                      ? 'No connection' 
                      : !isLoaded 
                        ? 'Statistics loading...' 
                        : 'Share Statistics',
                  );
                },
              );
            },
          ),
        ],
      ),
      body:
          sessionService.isGuest || sessionService.isAnonymous
              ? _buildGuestView()
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Genel Bakış Kartları
                    _buildOverviewCards(sessionService, isDark),
                    const SizedBox(height: 24),

                    // Haftalık Aktivite Grafiği
                    _buildWeeklyActivityChart(sessionService, isDark),
                    const SizedBox(height: 24),

                    // XP İlerleme Grafiği
                    _buildXpProgressChart(sessionService, isDark),
                    const SizedBox(height: 24),

                    // Başarımlar
                    _buildAchievementsSection(sessionService, isDark),
                  ],
                ),
              ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'İstatistikler Kullanılamıyor',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'İstatistiklerinizi görmek için giriş yapmanız gerekiyor.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(SessionService session, bool isDark) {
    // Senkron veri kullandığı için bu bileşeni yüklenmiş olarak işaretle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onComponentLoaded();
    });

    // Hata yönetimi ile güvenli veri okuma
    int currentLevel = 1;
    int totalXp = 0;
    int currentStreak = 0;
    int longestStreak = 0;
    int learnedWordsCount = 0;
    int favoritesCount = 0;

    try {
      currentLevel = session.currentLevel;
      totalXp = session.totalXp;
      currentStreak = session.currentStreak;
      longestStreak = session.longestStreak;
      learnedWordsCount = session.learnedWordsCount;
      favoritesCount = session.favoritesCount;
    } catch (e) {
      print('⚠️ StatisticsScreen: Error reading SessionService data: $e');
      // Varsayılan değerler yukarıda zaten ayarlandı
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          icon: Icons.emoji_events,
          title: 'Level',
          value: '$currentLevel',
          subtitle: '$totalXp XP',
          gradient: [Colors.amber, Colors.orange],
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.local_fire_department,
          title: 'Günlük Seri',
          value: '$currentStreak',
          subtitle: 'En uzun: $longestStreak',
          gradient: [Colors.orange, Colors.deepOrange],
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.school,
          title: 'Öğrenilen',
          value: '$learnedWordsCount',
          subtitle: 'kelime',
          gradient: [Colors.blue, Colors.blueAccent],
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.favorite,
          title: 'Favoriler',
          value: '$favoritesCount',
          subtitle: 'kelime',
          gradient: [Colors.red, Colors.pink],
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required List<Color> gradient,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityChart(SessionService session, bool isDark) {
    final userId = session.currentUser?.uid;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Haftalık Aktivite',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Icon(Icons.trending_up, color: Colors.green[600]),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _statsService.getWeeklyActivity(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Haftalık aktivite verisi yükleniyor...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Veri yüklenirken hata oluştu',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Lütfen internet bağlantınızı kontrol edin',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                            onPressed: () {
                              // Önbelleği temizle ve yeniden oluştur
                              StatisticsService.clearCache(userId);
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Yeniden Dene'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Henüz aktivite verisi yok',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Kelime öğrenmeye başlayın!',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mark this component as loaded
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onComponentLoaded();
                });

                final activityData = snapshot.data!;
                final now = DateTime.now();
                final weekData = List.generate(7, (index) {
                  final date = now.subtract(Duration(days: 6 - index));
                  final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  
                  final dayActivity = activityData.firstWhere(
                    (activity) => activity['date'] == dateKey,
                    orElse: () => {'xpEarned': 0, 'wordsLearned': 0, 'quizzesCompleted': 0},
                  );
                  
                  return (dayActivity['xpEarned'] as num?)?.toDouble() ?? 0.0;
                });

                final maxValue = weekData.isEmpty ? 0.0 : weekData.reduce((a, b) => a > b ? a : b);
                final maxY = maxValue == 0 ? 100.0 : (maxValue * 1.2).clamp(10.0, double.infinity);

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final value = rod.toY.toInt();
                          return BarTooltipItem(
                            value == 0 ? 'Aktivite yok' : '$value XP',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final date = now.subtract(Duration(days: 6 - value.toInt()));
                            final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                            return Text(
                              days[date.weekday - 1],
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      final value = weekData[index];
                      final isToday = index == 6;
                      final hasActivity = value > 0;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: value == 0 ? maxY * 0.02 : value, // Show minimal bar for zero values
                            gradient: LinearGradient(
                              colors: !hasActivity
                                  ? [Colors.grey.shade300, Colors.grey.shade400]
                                  : isToday
                                      ? [Colors.green, Colors.lightGreen]
                                      : [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context).colorScheme.secondary,
                                        ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpProgressChart(SessionService session, bool isDark) {
    // Senkron veri kullandığı için bu bileşeni yüklenmiş olarak işaretle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onComponentLoaded();
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level İlerlemesi',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Level ${session.currentLevel} → Level ${session.currentLevel + 1}',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (session.totalXp % 100) / 100,
              minHeight: 12,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${session.totalXp % 100} XP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '${100 - (session.totalXp % 100)} XP kaldı',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(SessionService session, bool isDark) {
    // Başarım kategorileri
    final categories = [
      {
        'id': 'streak',
        'icon': Icons.local_fire_department,
        'title': 'Seri Başarıları',
        'color': Colors.orange,
        'achievements': [
          {
            'icon': Icons.local_fire_department,
            'title': 'İlk Gün',
            'description': 'İlk girişini yaptın',
            'progress': session.currentStreak.clamp(0, 1),
            'target': 1,
            'unlocked': session.currentStreak >= 1,
          },
          {
            'icon': Icons.local_fire_department,
            'title': '3 Günlük Seri',
            'description': '3 gün üst üste giriş yap',
            'progress': session.currentStreak.clamp(0, 3),
            'target': 3,
            'unlocked': session.currentStreak >= 3,
          },
          {
            'icon': Icons.local_fire_department,
            'title': 'Haftalık Kahraman',
            'description': '7 gün üst üste giriş yap',
            'progress': session.currentStreak.clamp(0, 7),
            'target': 7,
            'unlocked': session.currentStreak >= 7,
          },
          {
            'icon': Icons.local_fire_department,
            'title': 'Seri Ustası',
            'description': '14 gün üst üste giriş yap',
            'progress': session.currentStreak.clamp(0, 14),
            'target': 14,
            'unlocked': session.currentStreak >= 14,
          },
          {
            'icon': Icons.local_fire_department,
            'title': 'Aylık Efsane',
            'description': '30 gün üst üste giriş yap',
            'progress': session.currentStreak.clamp(0, 30),
            'target': 30,
            'unlocked': session.currentStreak >= 30,
          },
        ],
      },
      {
        'id': 'words',
        'icon': Icons.school,
        'title': 'Kelime Başarıları',
        'color': Colors.blue,
        'achievements': [
          {
            'icon': Icons.school,
            'title': 'İlk Kelime',
            'description': 'İlk kelimeyi öğrendin',
            'progress': session.learnedWordsCount.clamp(0, 1),
            'target': 1,
            'unlocked': session.learnedWordsCount >= 1,
          },
          {
            'icon': Icons.school,
            'title': 'Kelime Toplayıcı',
            'description': '10 kelime öğren',
            'progress': session.learnedWordsCount.clamp(0, 10),
            'target': 10,
            'unlocked': session.learnedWordsCount >= 10,
          },
          {
            'icon': Icons.school,
            'title': 'Kelime Avcısı',
            'description': '25 kelime öğren',
            'progress': session.learnedWordsCount.clamp(0, 25),
            'target': 25,
            'unlocked': session.learnedWordsCount >= 25,
          },
          {
            'icon': Icons.school,
            'title': 'Sözlük Bilgini',
            'description': '50 kelime öğren',
            'progress': session.learnedWordsCount.clamp(0, 50),
            'target': 50,
            'unlocked': session.learnedWordsCount >= 50,
          },
          {
            'icon': Icons.school,
            'title': 'Kelime Uzmanı',
            'description': '100 kelime öğren',
            'progress': session.learnedWordsCount.clamp(0, 100),
            'target': 100,
            'unlocked': session.learnedWordsCount >= 100,
          },
          {
            'icon': Icons.school,
            'title': 'Dil Dahisi',
            'description': '200 kelime öğren',
            'progress': session.learnedWordsCount.clamp(0, 200),
            'target': 200,
            'unlocked': session.learnedWordsCount >= 200,
          },
          {
            'icon': Icons.school,
            'title': 'Sözlük Kralı',
            'description': '500 kelime öğren',
            'progress': session.learnedWordsCount.clamp(0, 500),
            'target': 500,
            'unlocked': session.learnedWordsCount >= 500,
          },
        ],
      },
      {
        'id': 'quiz',
        'icon': Icons.quiz,
        'title': 'Quiz Başarıları',
        'color': Colors.purple,
        'achievements': [
          {
            'icon': Icons.quiz,
            'title': 'İlk Quiz',
            'description': 'İlk quizini tamamla',
            'progress': session.totalQuizzesTaken.clamp(0, 1),
            'target': 1,
            'unlocked': session.totalQuizzesTaken >= 1,
          },
          {
            'icon': Icons.quiz,
            'title': 'Quiz Meraklısı',
            'description': '5 quiz tamamla',
            'progress': session.totalQuizzesTaken.clamp(0, 5),
            'target': 5,
            'unlocked': session.totalQuizzesTaken >= 5,
          },
          {
            'icon': Icons.quiz,
            'title': 'Quiz Tutkunu',
            'description': '10 quiz tamamla',
            'progress': session.totalQuizzesTaken.clamp(0, 10),
            'target': 10,
            'unlocked': session.totalQuizzesTaken >= 10,
          },
          {
            'icon': Icons.quiz,
            'title': 'Quiz Ustası',
            'description': '25 quiz tamamla',
            'progress': session.totalQuizzesTaken.clamp(0, 25),
            'target': 25,
            'unlocked': session.totalQuizzesTaken >= 25,
          },
          {
            'icon': Icons.quiz,
            'title': 'Quiz Efsanesi',
            'description': '50 quiz tamamla',
            'progress': session.totalQuizzesTaken.clamp(0, 50),
            'target': 50,
            'unlocked': session.totalQuizzesTaken >= 50,
          },
        ],
      },
      {
        'id': 'level',
        'icon': Icons.emoji_events,
        'title': 'Seviye Başarıları',
        'color': Colors.amber,
        'achievements': [
          {
            'icon': Icons.emoji_events,
            'title': 'Seviye 5',
            'description': '5. seviyeye ulaş',
            'progress': session.currentLevel.clamp(0, 5),
            'target': 5,
            'unlocked': session.currentLevel >= 5,
          },
          {
            'icon': Icons.emoji_events,
            'title': 'Seviye 10',
            'description': '10. seviyeye ulaş',
            'progress': session.currentLevel.clamp(0, 10),
            'target': 10,
            'unlocked': session.currentLevel >= 10,
          },
          {
            'icon': Icons.emoji_events,
            'title': 'Seviye 25',
            'description': '25. seviyeye ulaş',
            'progress': session.currentLevel.clamp(0, 25),
            'target': 25,
            'unlocked': session.currentLevel >= 25,
          },
          {
            'icon': Icons.emoji_events,
            'title': 'Elit Oyuncu',
            'description': '50. seviyeye ulaş',
            'progress': session.currentLevel.clamp(0, 50),
            'target': 50,
            'unlocked': session.currentLevel >= 50,
          },
        ],
      },
      {
        'id': 'favorites',
        'icon': Icons.favorite,
        'title': 'Favori Başarıları',
        'color': Colors.red,
        'achievements': [
          {
            'icon': Icons.favorite,
            'title': 'İlk Favori',
            'description': 'İlk kelimeyi favorilere ekle',
            'progress': session.favoritesCount.clamp(0, 1),
            'target': 1,
            'unlocked': session.favoritesCount >= 1,
          },
          {
            'icon': Icons.favorite,
            'title': 'Favori Koleksiyonu',
            'description': '10 kelimeyi favorilere ekle',
            'progress': session.favoritesCount.clamp(0, 10),
            'target': 10,
            'unlocked': session.favoritesCount >= 10,
          },
          {
            'icon': Icons.favorite,
            'title': 'Kalp Kırıcı',
            'description': '25 kelimeyi favorilere ekle',
            'progress': session.favoritesCount.clamp(0, 25),
            'target': 25,
            'unlocked': session.favoritesCount >= 25,
          },
          {
            'icon': Icons.favorite,
            'title': 'Favori Koleksiyoncusu',
            'description': '50 kelimeyi favorilere ekle',
            'progress': session.favoritesCount.clamp(0, 50),
            'target': 50,
            'unlocked': session.favoritesCount >= 50,
          },
        ],
      },
      {
        'id': 'xp',
        'icon': Icons.stars,
        'title': 'XP Başarıları',
        'color': Colors.green,
        'achievements': [
          {
            'icon': Icons.stars,
            'title': 'XP Toplayıcı',
            'description': '500 XP kazan',
            'progress': session.totalXp.clamp(0, 500),
            'target': 500,
            'unlocked': session.totalXp >= 500,
          },
          {
            'icon': Icons.stars,
            'title': 'XP Avcısı',
            'description': '1000 XP kazan',
            'progress': session.totalXp.clamp(0, 1000),
            'target': 1000,
            'unlocked': session.totalXp >= 1000,
          },
          {
            'icon': Icons.stars,
            'title': 'XP Ustası',
            'description': '2500 XP kazan',
            'progress': session.totalXp.clamp(0, 2500),
            'target': 2500,
            'unlocked': session.totalXp >= 2500,
          },
          {
            'icon': Icons.stars,
            'title': 'XP Efsanesi',
            'description': '5000 XP kazan',
            'progress': session.totalXp.clamp(0, 5000),
            'target': 5000,
            'unlocked': session.totalXp >= 5000,
          },
        ],
      },
    ];

    // Toplam başarımları hesapla
    int totalAchievements = 0;
    int unlockedAchievements = 0;
    for (var category in categories) {
      final achievements = category['achievements'] as List<Map<String, dynamic>>;
      totalAchievements += achievements.length;
      unlockedAchievements += achievements.where((a) => a['unlocked'] as bool).length;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Başarılar',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unlockedAchievements/$totalAchievements',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final achievements = category['achievements'] as List<Map<String, dynamic>>;
              final unlocked = achievements.where((a) => a['unlocked'] as bool).length;
              final total = achievements.length;
              final color = category['color'] as Color;

              return InkWell(
                onTap: () => _showAchievementDialog(context, category, isDark),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.1),
                        color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              category['icon'] as IconData,
                              color: color,
                              size: 22,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unlocked/$total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: unlocked / total,
                                minHeight: 5,
                                backgroundColor:
                                    isDark ? Colors.grey[700] : Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAchievementDialog(
    BuildContext context,
    Map<String, dynamic> category,
    bool isDark,
  ) {
    final achievements = category['achievements'] as List<Map<String, dynamic>>;
    final color = category['color'] as Color;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Başarımlar Listesi
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = achievements[index];
                    final unlocked = achievement['unlocked'] as bool;
                    final progress = achievement['progress'] as int;
                    final target = achievement['target'] as int;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? color.withOpacity(0.1)
                            : (isDark ? Colors.grey[800] : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12),
                        border: unlocked
                            ? Border.all(color: color.withOpacity(0.3), width: 2)
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: unlocked
                                  ? color
                                  : (isDark ? Colors.grey[700] : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              achievement['icon'] as IconData,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  achievement['title'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: unlocked
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : (isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600]),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  achievement['description'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        isDark ? Colors.grey[500] : Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!unlocked) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress / target,
                                      minHeight: 5,
                                      backgroundColor: isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                              '$progress / $target',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                                ],
                              ],
                            ),
                          ),
                          if (unlocked)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareStats(SessionService session, bool isDark) async {
    if (session.isGuest || session.isAnonymous) {
      _showGuestMessage();
      return;
    }

    try {
      // Yeni paylaşım yöntemi ile SharePreviewScreen kullan
      await ShareUtils.shareUserStats(context);
      
    } catch (e) {
      if (mounted) {
        showLexiflowToast(
          context,
          ToastType.error,
          'İstatistik paylaşımı başarısız. Lütfen tekrar deneyin.',
        );
      }
      debugPrint('Statistics sharing error: $e');
    }
  }

  void _showLoadingMessage() {
    showLexiflowToast(
      context,
      ToastType.info,
      'Lütfen bekleyin, istatistikler yükleniyor...',
    );
  }

  void _showOfflineMessage() {
    showLexiflowToast(
      context,
      ToastType.error,
      'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.',
    );
  }

  void _showGuestMessage() {
    showLexiflowToast(
      context,
      ToastType.info,
      'İstatistikleri paylaşmak için giriş yapın',
    );
  }
}
