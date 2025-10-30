import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/design_system.dart';
import '../services/session_service.dart';
import '../services/enhanced_session_service.dart';
import '../utils/logger.dart';
import 'loading_notification.dart';
import 'error_handler_widget.dart';

class EnhancedNameEditDialog extends StatefulWidget {
  const EnhancedNameEditDialog({super.key});

  @override
  State<EnhancedNameEditDialog> createState() => _EnhancedNameEditDialogState();
}

class _EnhancedNameEditDialogState extends State<EnhancedNameEditDialog>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasChanges = false;
  
  final EnhancedSessionService _enhancedSessionService = EnhancedSessionService();

  @override
  void initState() {
    super.initState();
    
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final currentName = sessionService.currentUser?.displayName ?? '';
    _controller = TextEditingController(text: currentName);
    
    // Setup animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    // Start animations
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
    
    // Listen for text changes
    _controller.addListener(() {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      final currentName = sessionService.currentUser?.displayName ?? '';
      setState(() {
        _hasChanges = _controller.text.trim() != currentName;
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Gelişmiş hata yönetimi ile kaydetme işlemini yönet
  Future<void> _handleSave() async {
    final newName = _controller.text.trim();
    
    if (newName.isEmpty) {
      setState(() {
        _errorMessage = 'İsim boş olamaz';
      });
      return;
    }
    
    if (newName.length < 2) {
      setState(() {
        _errorMessage = 'İsim en az 2 karakter olmalı';
      });
      return;
    }
    
    if (newName.length > 20) {
      setState(() {
        _errorMessage = 'İsim en fazla 20 karakter olabilir';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      LoadingNotificationOverlay.show(
        context,
        message: 'İsim güncelleniyor...',
      );
      
      // Use enhanced session service for better error handling and real-time sync
      final result = await _enhancedSessionService.updateDisplayNameEnhanced(newName);
      
      // Hide loading notification
      LoadingNotificationOverlay.hide();
      
      if (result['success'] == true) {
        // Success animation
        await _scaleController.reverse();
        await _slideController.reverse();
        
        if (mounted) {
          Navigator.of(context).pop({
            'success': true,
            'message': result['message'] ?? 'İsminiz başarıyla güncellendi!',
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(result['message'] ?? 'İsim başarıyla güncellendi!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: AppBorderRadius.medium,
              ),
            ),
          );
        }
      } else {
        // Handle different error types
        final errorMessage = result['error'] ?? 'Bilinmeyen bir hata oluştu';
        
        if (mounted) {
          // Show appropriate error based on error type
          if (errorMessage.contains('zaman aşımı')) {
            ErrorHandlerOverlay.showTimeoutError(context);
          } else if (errorMessage.contains('internet') || errorMessage.contains('bağlantı')) {
            ErrorHandlerOverlay.showNetworkError(context);
          } else {
            ErrorHandlerOverlay.showValidationError(
              context,
              errorMessage,
              details: 'Lütfen farklı bir isim deneyin veya daha sonra tekrar deneyin.',
            );
          }
          
          setState(() {
            _errorMessage = errorMessage;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Hide loading notification
      LoadingNotificationOverlay.hide();
      
      Logger.e('Error updating display name', e, null, 'EnhancedNameEditDialog');
      
      if (mounted) {
        // Show critical error
        ErrorHandlerOverlay.showError(
          context,
          ErrorData(
            type: ErrorType.unknown,
            severity: ErrorSeverity.critical,
            message: 'Kritik hata oluştu',
            details: e.toString(),
            actionLabel: 'Tekrar Dene',
            onAction: () {
              ErrorHandlerOverlay.hideError();
              _handleSave();
            },
          ),
        );
        
        setState(() {
          _errorMessage = 'Beklenmeyen bir hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCancel() async {
    await _scaleController.reverse();
    await _slideController.reverse();
    
    if (mounted) {
      Navigator.of(context).pop({'success': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive breakpoints
    final isSmallScreen = screenWidth <= 320;
    final isMediumScreen = screenWidth > 320 && screenWidth <= 768;
    final isLargeScreen = screenWidth > 768 && screenWidth <= 1024;
    
    // Responsive values
    final horizontalMargin = isSmallScreen 
        ? AppSpacing.sm 
        : isMediumScreen 
            ? AppSpacing.md 
            : AppSpacing.xl;
    
    final maxWidth = isSmallScreen 
        ? double.infinity 
        : isMediumScreen 
            ? 380.0 
            : isLargeScreen 
                ? 420.0 
                : 450.0;
    
    final contentPadding = isSmallScreen 
        ? AppSpacing.md 
        : isMediumScreen 
            ? AppSpacing.lg 
            : AppSpacing.xl;
    
    final headerPadding = isSmallScreen 
        ? AppSpacing.md 
        : AppSpacing.lg;
    
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    final titleStyle = isSmallScreen 
        ? theme.textTheme.titleLarge 
        : theme.textTheme.headlineSmall;
    
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: horizontalMargin,
                    vertical: screenHeight < 600 ? AppSpacing.sm : AppSpacing.md,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    minWidth: 280,
                    maxHeight: screenHeight * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppDarkColors.surface : AppColors.surface,
                    borderRadius: AppBorderRadius.xlarge,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(headerPadding),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? AppSpacing.xs : AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: AppBorderRadius.medium,
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? AppSpacing.sm : AppSpacing.md),
                            Expanded(
                              child: Text(
                                'İsminizi Düzenleyin',
                                style: titleStyle?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Padding(
                        padding: EdgeInsets.all(contentPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input Field
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: AppBorderRadius.medium,
                                border: Border.all(
                                  color: _errorMessage != null
                                      ? AppColors.error
                                      : _hasChanges
                                          ? theme.colorScheme.primary
                                          : (isDark ? AppDarkColors.border : AppColors.border),
                                  width: _hasChanges ? 2 : 1,
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                enabled: !_isLoading,
                                style: TextStyle(
                                  color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                cursorColor: isDark ? AppDarkColors.primary : AppColors.primary,
                                decoration: InputDecoration(
                                  labelText: 'Adınız',
                                  hintText: 'Yeni adınızı girin',
                                  labelStyle: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  hintStyle: TextStyle(
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    color: _errorMessage != null
                                        ? AppColors.error
                                        : theme.colorScheme.primary,
                                  ),
                                  suffixIcon: _hasChanges
                                      ? Icon(
                                          Icons.check_circle_outline,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: true,
                                  fillColor: isDark 
                                      ? AppDarkColors.surfaceVariant 
                                      : AppColors.surfaceVariant,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.md,
                                  ),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                ),
                                textCapitalization: TextCapitalization.words,
                                maxLength: 20,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                                    child: Text(
                                      '$currentLength/${maxLength ?? 20}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: currentLength > 15
                                            ? AppColors.warning
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            // Error Message
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: _errorMessage != null ? 40 : 0,
                              child: _errorMessage != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            color: AppColors.error,
                                            size: 16,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            
                            const SizedBox(height: AppSpacing.lg),
                            
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: _isLoading ? null : _handleCancel,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: isSmallScreen ? AppSpacing.sm : AppSpacing.md,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: AppBorderRadius.medium,
                                      ),
                                    ),
                                    child: Text(
                                      'İptal',
                                      style: (isSmallScreen ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? AppSpacing.sm : AppSpacing.md),
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      gradient: _hasChanges && !_isLoading
                                          ? LinearGradient(
                                              colors: [
                                                theme.colorScheme.primary,
                                                theme.colorScheme.secondary,
                                              ],
                                            )
                                          : null,
                                      borderRadius: AppBorderRadius.medium,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: (_hasChanges && !_isLoading) ? _handleSave : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _hasChanges && !_isLoading
                                            ? Colors.transparent
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                        foregroundColor: _hasChanges && !_isLoading
                                            ? Colors.white
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.symmetric(
                                          vertical: isSmallScreen ? AppSpacing.sm : AppSpacing.md,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppBorderRadius.medium,
                                        ),
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              width: isSmallScreen ? 16 : 20,
                                              height: isSmallScreen ? 16 : 20,
                                              child: const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              'Kaydet',
                                              style: (isSmallScreen ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}