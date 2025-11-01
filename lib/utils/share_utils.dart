// lib/utils/share_utils.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/user_stats_model.dart';
import '../screens/share_preview_screen.dart';
import '../services/session_service.dart';
import '../providers/profile_stats_provider.dart';
import '../widgets/lexiflow_toast.dart';
import 'package:provider/provider.dart';

class ShareUtils {
  static final GlobalKey _sharePreviewKey = GlobalKey();

  /// New method to share statistics using SharePreviewScreen
  static Future<void> shareUserStats(BuildContext context) async {
    try {
      final sessionService = SessionService();
      final profileStatsProvider = context.read<ProfileStatsProvider>();
      
      final userStats = UserStatsModel(
        level: sessionService.level,
        xp: sessionService.totalXp,
        longestStreak: profileStatsProvider.longestStreak,
        learnedWords: sessionService.learnedWordsCount,
        quizzesCompleted: sessionService.totalQuizzesTaken,
      );

      await _showShareOptionsBottomSheet(context, userStats);
      
    } catch (e) {
      if (context.mounted) {
        showLexiflowToast(context, ToastType.error, 'Paylaşım sırasında hata oluştu');
      }
    }
  }

  /// Show modern bottom sheet with share options
  static Future<void> _showShareOptionsBottomSheet(
    BuildContext context,
    UserStatsModel userStats,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                "İstatistikleri Paylaş",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                "İstatistiklerinizi nasıl paylaşmak istiyorsunuz?",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Share options
              _buildShareOption(
                context: context,
                icon: Icons.save_alt,
                title: "Cihaza Kaydet",
                subtitle: "Galeri'ye kaydet",
                onTap: () {
                  Navigator.pop(context);
                  _navigateAndCaptureStats(context, userStats, saveToDevice: true);
                },
              ),
              const SizedBox(height: 12),
              
              _buildShareOption(
                context: context,
                icon: Icons.share,
                title: "Paylaş",
                subtitle: "Sosyal medya ve uygulamalar",
                onTap: () {
                  Navigator.pop(context);
                  _navigateAndCaptureStats(context, userStats, saveToDevice: false);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Build share option tile
  static Widget _buildShareOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to SharePreviewScreen and capture it
  static Future<void> _navigateAndCaptureStats(
    BuildContext context,
    UserStatsModel userStats, {
    required bool saveToDevice,
  }) async {
    try {
      // Request permissions before showing SharePreviewScreen
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        if (!await Permission.photos.request().isGranted) {
          if (context.mounted) {
            showLexiflowToast(context, ToastType.error, 'Depolama izni gerekli 📱');
          }
          return;
        }
      } else {
        if (!await Permission.storage.request().isGranted) {
          if (context.mounted) {
            showLexiflowToast(context, ToastType.error, 'Depolama izni gerekli 📱');
          }
          return;
        }
      }

      // Navigate to SharePreviewScreen with arguments
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SharePreviewScreen(userStats: userStats),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showLexiflowToast(context, ToastType.error, 'Paylaşım sırasında hata oluştu');
      }
    }
  }

  /// Share image using share_plus
  static Future<void> _shareImage(Uint8List imageBytes, BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/lexiflow_stats_$timestamp.png');
      
      await file.writeAsBytes(imageBytes, flush: true);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Lexiflow ile öğrenme yolculuğumda elde ettiğim başarılar! 🚀📚',
        subject: 'Lexiflow İstatistiklerim',
      );

      // Cleanup after delay to ensure sharing is complete
      Future.delayed(const Duration(seconds: 10), () async {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paylaşım sırasında hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Checks if sharing is available (for offline handling)
  static Future<bool> isSharingAvailable() async {
    try {
      // Simple check - if we can access temp directory, sharing should work
      await getTemporaryDirectory();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save image to device gallery
  static Future<void> _saveToGallery(Uint8List imageBytes, BuildContext context) async {
    try {
      // Create a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/lexiflow_stats_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);

      // Save to gallery
      await Gal.putImage(file.path);

      if (context.mounted) {
        showLexiflowToast(context, ToastType.success, 'İstatistikler galeriye kaydedildi! 🎉');
      }

      // Clean up temporary file
      await file.delete();
    } catch (e) {
      if (context.mounted) {
        showLexiflowToast(context, ToastType.error, 'Kaydetme hatası oluştu');
      }
    }
  }

  static Future<void> captureAndShareFullStats(
    BuildContext context,
    String userId,
  ) async {
    // Redirect to new sharing method
    await shareUserStats(context);
  }
}