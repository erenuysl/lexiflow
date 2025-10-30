// lib/screens/daily_word_screen.dart
// Daily Words Screen with 10 free + 5 ad bonus words

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/word_model.dart';
import '../services/daily_word_service.dart';
import '../services/session_service.dart';
import '../screens/word_detail_screen.dart';

class DailyWordScreen extends StatefulWidget {
  const DailyWordScreen({super.key});

  @override
  State<DailyWordScreen> createState() => _DailyWordScreenState();
}

class _DailyWordScreenState extends State<DailyWordScreen> {
  final DailyWordService _dailyWordService = DailyWordService();

  Map<String, dynamic>? _dailyWordsData;
  List<Word> _words = [];
  bool _isLoading = true;
  bool _isLoadingAd = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeDailyWords();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _dailyWordService.dispose();
    super.dispose();
  }

  Future<void> _initializeDailyWords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionService = Provider.of<SessionService>(
        context,
        listen: false,
      );
      final userId = sessionService.currentUser?.uid;

      if (userId == null) {
        setState(() {
          _errorMessage = 'Kullanıcı oturumu bulunamadı';
          _isLoading = false;
        });
        return;
      }

      await _dailyWordService.initializeAdService();

      final data = await _dailyWordService.getTodaysWords(userId);

      final allWordIds = <String>[
        ...List<String>.from(data['dailyWords'] ?? []),
        ...List<String>.from(data['extraWords'] ?? []),
      ];

      // Fetch word details
      final words = await _dailyWordService.getWordsByIds(allWordIds);

      setState(() {
        _dailyWordsData = data;
        _words = words;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error initializing daily words: $e');
      setState(() {
        _errorMessage = 'Günlük kelimeler yüklenirken hata oluştu';
        _isLoading = false;
      });
    }
  }

  void _startCountdownTimer() {
    _updateTimeUntilReset();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeUntilReset();
    });
  }

  void _updateTimeUntilReset() {
    setState(() {
      _timeUntilReset = _dailyWordService.getTimeUntilReset();
    });
  }

  Future<void> _watchAdForExtraWords() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null) return;

    setState(() => _isLoadingAd = true);

    try {
      final success = await _dailyWordService.addExtraWordsAfterAd(userId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 +5 kelime eklendi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Refresh daily words
        await _initializeDailyWords();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Reklam yüklenemedi'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error watching ad: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAd = false);
      }
    }
  }

  Future<void> _markWordAsCompleted(String wordId) async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null) return;

    try {
      await _dailyWordService.markWordAsCompleted(userId, wordId);

      // Update local state
      setState(() {
        _dailyWordsData!['completedWords'] = [
          ...List<String>.from(_dailyWordsData!['completedWords'] ?? []),
          wordId,
        ];
      });
    } catch (e) {
      debugPrint('❌ Error marking word as completed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        const Icon(
                          Icons.calendar_today,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bugünün Kelimeleri',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCountdownTimer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _initializeDailyWords,
                      icon: const Icon(Icons.refresh),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Tekrar Dene',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Progress Card
                  _buildProgressCard(),
                  const SizedBox(height: 16),

                  // Ad Button
                  if (_dailyWordsData != null &&
                      !_dailyWordsData!['hasWatchedAd'])
                    _buildAdButton(),
                  if (_dailyWordsData != null &&
                      !_dailyWordsData!['hasWatchedAd'])
                    const SizedBox(height: 24),

                  // Words List Header
                  Text(
                    'Kelimeler',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Words List
                  ..._words.map((word) => _buildWordCard(word)),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownTimer() {
    final hours = _timeUntilReset.inHours;
    final minutes = _timeUntilReset.inMinutes % 60;
    final seconds = _timeUntilReset.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            'Yenilenme: ${hours}s ${minutes}d ${seconds}sn',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    if (_dailyWordsData == null) return const SizedBox.shrink();

    final totalWords =
        List<String>.from(_dailyWordsData!['dailyWords'] ?? []).length +
        List<String>.from(_dailyWordsData!['extraWords'] ?? []).length;
    final completedWords =
        List<String>.from(_dailyWordsData!['completedWords'] ?? []).length;
    final progress = totalWords > 0 ? completedWords / totalWords : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Günlük İlerleme',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedWords / $totalWords',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            completedWords == totalWords
                ? '🎉 Tebrikler! Bugünün tüm kelimelerini tamamladın!'
                : '${totalWords - completedWords} kelime kaldı',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAdButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.deepPurple[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoadingAd ? null : _watchAdForExtraWords,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reklam İzle +5 Kelime Kazan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Günde bir kez kullanılabilir',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingAd)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordCard(Word word) {
    if (_dailyWordsData == null) return const SizedBox.shrink();

    final completedWords = List<String>.from(
      _dailyWordsData!['completedWords'] ?? [],
    );
    final isCompleted = completedWords.contains(word.word);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCompleted ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isCompleted
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Navigate to word detail
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WordDetailScreen(word: word),
            ),
          );

          // Mark as completed after viewing
          if (!isCompleted) {
            await _markWordAsCompleted(word.word);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isCompleted
                          ? Colors.green.withOpacity(0.1)
                          : Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.book,
                  color:
                      isCompleted
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Word Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.tr.isNotEmpty ? word.tr : word.meaning,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
