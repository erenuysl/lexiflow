import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/user_stats_model.dart';
import '../utils/design_system.dart';
import '../widgets/lexiflow_toast.dart';

class SharePreviewScreen extends StatefulWidget {
  final UserStatsModel userStats;

  const SharePreviewScreen({
    super.key,
    required this.userStats,
  });

  @override
  State<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends State<SharePreviewScreen>
    with TickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isLoading = false;
  bool _isDataReady = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    // Simulate data loading and start animations
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isDataReady = true);
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _slideController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Save to device - requires permission
  Future<void> _saveToDevice() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Check and request storage permissions based on Android version
      bool granted = await _checkStoragePermission();

      if (!granted) {
        _showError("Depolama izni gerekli 📱");
        return;
      }

      // Add small delay for UI feedback
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Safely access RenderBox after layout completion
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary == null) {
            _showError("Görüntü oluşturulamadı ❌");
            return;
          }
          
          // Use higher pixel ratio for crisp screenshots
          final image = await boundary.toImage(pixelRatio: 4.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final pngBytes = byteData!.buffer.asUint8List();
          
          // Verify image bytes
          if (pngBytes.isEmpty) {
            _showError("Görüntü oluşturulamadı ❌");
            return;
          }
          
          debugPrint("Captured image successfully at ${DateTime.now()}");
          debugPrint("Image size: ${pngBytes.length} bytes");
          
          // Create a temporary file and save to gallery using gal
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/lexiflow_stats_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(pngBytes);

          // Save to gallery with album organization
          await Gal.putImage(file.path, album: "Lexiflow");

          // Clean up temporary file
          await file.delete();

          _showSuccess("Galeriye kaydedildi 🎉");
          await Future.delayed(const Duration(milliseconds: 1200));
          if (Navigator.canPop(context)) Navigator.pop(context);
        } catch (e) {
          _showError("Kaydetme hatası: $e");
          debugPrint("Save error: $e");
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      });
    } catch (e) {
      _showError("Kaydetme hatası: $e");
      debugPrint("Save error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Share stats - no permission required
  Future<void> _shareStats() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Add small delay for UI feedback
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Safely access RenderBox after layout completion
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          // Capture screenshot with enhanced quality
          final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary == null) {
            _showError('Ekran görüntüsü alınamadı');
            return;
          }

          // Use higher pixel ratio for crisp screenshots
          final image = await boundary.toImage(pixelRatio: 4.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final imageBytes = byteData?.buffer.asUint8List();
          
          if (imageBytes == null) {
            _showError('Görüntü işlenemedi');
            return;
          }

          // Create temporary file for sharing
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/lexiflow_stats_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(imageBytes);

          // Share with enhanced message
          await Share.shareXFiles(
            [XFile(file.path)],
            text: "📊 My Lexiflow Stats — lexiflow.app",
          );
          
          _showSuccess('Paylaşım hazırlandı 📤');
          
        } catch (e) {
          _showError('Paylaşım hatası: ${e.toString()}');
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      });
    } catch (e) {
      _showError('Paylaşım hatası: ${e.toString()}');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Check storage permissions based on Android version
  Future<bool> _checkStoragePermission() async {
    try {
      Permission permission;
      
      // Use appropriate permission based on Android version
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13+ uses granular media permissions
          permission = Permission.photos;
        } else {
          // Android 12 and below use storage permission
          permission = Permission.storage;
        }
      } else {
        // iOS uses photos permission
        permission = Permission.photos;
      }

      final status = await permission.status;
      
      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        final result = await permission.request();
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        // Show dialog to open app settings
        _showError('Ayarlardan depolama iznini etkinleştirin');
        await openAppSettings();
        return false;
      }
      
      return false;
    } catch (e) {
      _showError('İzin kontrolü hatası: ${e.toString()}');
      return false;
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    showLexiflowToast(context, ToastType.success, message);
  }

  void _showError(String message) {
    if (!mounted) return;
    showLexiflowToast(context, ToastType.error, message);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.primaryDark,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Loading state
              if (!_isDataReady)
                Container(
                  height: screenSize.height * 0.6,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "İstatistikler hazırlanıyor...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Main content
              if (_isDataReady)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                        child: Column(
                          children: [
                            _buildModernHeader(isSmallScreen),
                            SizedBox(height: screenSize.height * 0.03),
                            _buildDateAndTitle(isSmallScreen),
                            SizedBox(height: screenSize.height * 0.035),
                            _buildResponsiveStatsGrid(isSmallScreen),
                            SizedBox(height: screenSize.height * 0.04),
                            _buildBrandingFooter(),
                            SizedBox(height: screenSize.height * 0.02),
                            // Small watermark at bottom
                            const Align(
                              alignment: Alignment.bottomCenter,
                              child: Text(
                                "📱 via Lexiflow",
                                style: TextStyle(fontSize: 10, color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              SizedBox(height: screenSize.height * 0.03),
              
              // Action buttons
              if (!_isLoading && _isDataReady)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            onPressed: _saveToDevice,
                            icon: Icons.download_rounded,
                            label: "Cihaza Kaydet",
                            gradient: const LinearGradient(
                              colors: [Color(0xFF06D6A0), Color(0xFF4ECDC4)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            onPressed: _shareStats,
                            icon: Icons.share_rounded,
                            label: "Paylaş",
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Loading overlay
              if (_isLoading)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'İşleniyor...',
                        style: AppTextStyles.body1.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Lexiflow icon container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              color: Colors.white,
              size: isSmallScreen ? 24 : 28,
            ),
          ),
          const SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lexiflow - fontSize: 26, fontWeight: FontWeight.bold
                Text(
                  "Lexiflow",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle - fontSize: 18, fontWeight: FontWeight.w600, white color
                Text(
                  "Lexiflow İstatistiklerim",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndTitle(bool isSmallScreen) {
    final now = DateTime.now();
    final formattedDate = "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}";
    
    return Column(
      children: [
        // Date - smaller font, white70 color
        Text(
          formattedDate,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        // Title - specific font size and weight as per requirements
        Text(
          "Öğrenme Yolculuğum",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveStatsGrid(bool isSmallScreen) {
    final stats = [
      {
        'icon': Icons.military_tech_rounded,
        'label': 'Seviye',
        'value': widget.userStats.level.toString(),
        'gradient': const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'icon': Icons.flash_on_rounded,
        'label': 'XP',
        'value': widget.userStats.xp.toString(),
        'gradient': const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'label': 'En Uzun Seri',
        'value': '${widget.userStats.longestStreak} gün',
        'gradient': const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'icon': Icons.book_rounded,
        'label': 'Öğrenilen Kelime',
        'value': widget.userStats.learnedWords.toString(),
        'gradient': const LinearGradient(
          colors: [Color(0xFF06D6A0), Color(0xFF4ECDC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'icon': Icons.quiz_rounded,
        'label': 'Tamamlanan Quiz',
        'value': widget.userStats.quizzesCompleted.toString(),
        'gradient': const LinearGradient(
          colors: [Color(0xFF45B7D1), Color(0xFF96CEB4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'icon': Icons.trending_up_rounded,
        'label': 'Günlük Ortalama',
        'value': '${(widget.userStats.xp / (widget.userStats.level + 1)).toInt()} XP',
        'gradient': const LinearGradient(
          colors: [Color(0xFFFF9A9E), Color(0xFFFECAB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final cardWidth = (screenWidth - 32) / 2; // 2-column layout with spacing
        final cardHeight = cardWidth * 1.1; // slightly taller cards

        return Wrap(
          spacing: 16,
          runSpacing: 24, // adds vertical gap between rows to prevent label overlap
          alignment: WrapAlignment.center,
          children: stats.map((stat) {
            return Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: stat['gradient'] as LinearGradient,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: _buildStatCardContent(
                stat['icon'] as IconData,
                stat['label'] as String,
                stat['value'] as String,
                isSmallScreen,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatCardContent(IconData icon, String label, String value, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon at top center
          Icon(
            icon,
            color: Colors.white,
            size: isSmallScreen ? 24 : 28,
          ),
          const SizedBox(height: 8),
          // Value - centered and larger
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Label - bottom, smaller font with FittedBox to prevent overflow
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingFooter() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_graph_rounded, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              "Track your progress, expand your vocabulary.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required LinearGradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }


}