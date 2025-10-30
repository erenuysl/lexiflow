// lib/screens/migration_screen.dart
// Migration Screen with Progress Bar and Error Handling

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/migration_service.dart';
import '../utils/design_system.dart';

/// Migration Screen for migrating from Hive to Firestore
/// Shows progress, handles errors, and provides retry functionality
class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  final MigrationService _migrationService = MigrationService();
  MigrationProgress? _currentProgress;
  bool _isMigrating = false;
  bool _migrationCompleted = false;
  bool _migrationFailed = false;
  String? _errorMessage;
  String? _estimatedTimeRemaining;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startMigration();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  Future<void> _startMigration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User not authenticated');
      return;
    }

    setState(() {
      _isMigrating = true;
      _migrationFailed = false;
      _errorMessage = null;
    });

    // Set up progress callback
    _migrationService.onProgress = (progress) {
      setState(() {
        _currentProgress = progress;
        _estimatedTimeRemaining = _calculateEstimatedTime(progress);
      });

      // Animate progress bar
      _progressController.animateTo(progress.percentage ?? 0.0);
    };

    // Start migration
    final success = await _migrationService.migrateHiveToFirestore(user.uid);

    if (success) {
      setState(() {
        _migrationCompleted = true;
        _isMigrating = false;
      });

      // Complete progress animation
      _progressController.animateTo(1.0);

      // Wait a moment then navigate
      await Future.delayed(const Duration(seconds: 2));
      _navigateToDashboard();
    } else {
      setState(() {
        _migrationFailed = true;
        _isMigrating = false;
        _errorMessage = 'Migration failed. Please try again.';
      });
    }
  }

  Future<void> _retryMigration() async {
    setState(() {
      _migrationFailed = false;
      _errorMessage = null;
    });

    await _startMigration();
  }

  String _calculateEstimatedTime(MigrationProgress progress) {
    if (progress.percentage == 0) return 'Calculating...';

    final remaining = 1.0 - progress.percentage;
    final estimatedSeconds = (remaining * 60).round(); // Rough estimate

    if (estimatedSeconds < 60) {
      return 'Less than 1 minute';
    } else {
      final minutes = (estimatedSeconds / 60).round();
      return 'About $minutes minute${minutes == 1 ? '' : 's'}';
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _migrationFailed = true;
      _isMigrating = false;
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              _buildHeader(),

              const SizedBox(height: AppSpacing.xl),

              // Progress Section
              _buildProgressSection(),

              const SizedBox(height: AppSpacing.xl),

              // Status Section
              _buildStatusSection(),

              const SizedBox(height: AppSpacing.xl),

              // Action Buttons
              if (_migrationFailed) _buildRetryButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App Icon with Pulse Animation
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.lg),

        Text(
          'Updating Your Data',
          style: AppTextStyles.headline1.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.sm),

        Text(
          'We\'re migrating your learning progress to our new system. This will only take a moment.',
          style: AppTextStyles.body1.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return ModernCard(
      child: Column(
        children: [
          // Progress Bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: AppTextStyles.title3.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${(_progressAnimation.value * 100).round()}%',
                        style: AppTextStyles.title3.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 8,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  if (_estimatedTimeRemaining != null)
                    Text(
                      'Estimated time remaining: $_estimatedTimeRemaining',
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                ],
              );
            },
          ),

          if (_currentProgress != null) ...[
            const SizedBox(height: AppSpacing.lg),

            // Detailed Progress
            _buildDetailedProgress(),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedProgress() {
    return Column(
      children: [
        _buildProgressItem(
          'Words',
          _currentProgress!.migratedWords,
          _currentProgress!.totalWords,
          Icons.book_rounded,
        ),

        const SizedBox(height: AppSpacing.sm),

        _buildProgressItem(
          'Progress',
          _currentProgress!.migratedProgress,
          _currentProgress!.totalProgress,
          Icons.trending_up_rounded,
        ),

        const SizedBox(height: AppSpacing.sm),

        _buildProgressItem(
          'Activities',
          _currentProgress!.migratedActivities,
          _currentProgress!.totalActivities,
          Icons.history_rounded,
        ),
      ],
    );
  }

  Widget _buildProgressItem(
    String label,
    int current,
    int total,
    IconData icon,
  ) {
    final percentage = total > 0 ? current / total : 0.0;

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary.withOpacity(0.7)),

        const SizedBox(width: AppSpacing.sm),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body2.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '$current / $total',
                    style: AppTextStyles.body2.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xs),

              LinearProgressIndicator(
                value: percentage,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withOpacity(0.7),
                ),
                minHeight: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (_migrationCompleted) {
      return _buildSuccessStatus();
    } else if (_migrationFailed) {
      return _buildErrorStatus();
    } else {
      return _buildLoadingStatus();
    }
  }

  Widget _buildLoadingStatus() {
    return ModernCard(
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentProgress?.currentStep ?? 'Preparing migration...',
                  style: AppTextStyles.body1.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Please don\'t close the app during this process.',
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStatus() {
    return ModernCard(
      backgroundColor: AppColors.success.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Migration Completed!',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Your data has been successfully migrated. Redirecting to dashboard...',
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStatus() {
    return ModernCard(
      backgroundColor: AppColors.error.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_rounded, color: AppColors.error, size: 24),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Migration Failed',
                      style: AppTextStyles.body1.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Text(
                      _errorMessage ?? 'An unexpected error occurred.',
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'Don\'t worry! Your data is safe. You can retry the migration or continue using the app.',
            style: AppTextStyles.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _retryMigration,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.medium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded),
            const SizedBox(width: AppSpacing.sm),
            Text('Retry Migration', style: AppTextStyles.button),
          ],
        ),
      ),
    );
  }
}
