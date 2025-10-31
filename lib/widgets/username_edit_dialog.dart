import 'package:flutter/material.dart';
import '../utils/design_system.dart';

class UsernameEditDialog extends StatefulWidget {
  final String currentUsername;
  final Function(String) onSave;

  const UsernameEditDialog({
    super.key,
    required this.currentUsername,
    required this.onSave,
  });

  @override
  State<UsernameEditDialog> createState() => _UsernameEditDialogState();
}

class _UsernameEditDialogState extends State<UsernameEditDialog>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _hasChanges = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _controller = TextEditingController(text: widget.currentUsername);
    
    // animasyon kontrolcüleri
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
    
    // animasyonları başlat
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
    
    // text değişikliklerini dinle
    _controller.addListener(() {
      setState(() {
        _hasChanges = _controller.text.trim() != widget.currentUsername;
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

  void _handleSave() {
    final newUsername = _controller.text.trim();
    
    if (newUsername.isEmpty) {
      setState(() {
        _errorMessage = 'Kullanıcı adı boş olamaz';
      });
      return;
    }
    
    if (newUsername.length > 20) {
      setState(() {
        _errorMessage = 'Kullanıcı adı 20 karakterden uzun olamaz';
      });
      return;
    }
    
    widget.onSave(newUsername);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // başlık
                    Text(
                      'Kullanıcı Adını Düzenle',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // text field
                    TextField(
                      controller: _controller,
                      maxLength: 20,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Yeni kullanıcı adı',
                        labelStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        hintText: 'Kullanıcı adınızı girin',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.error,
                            width: 2,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.error,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                        errorText: _errorMessage,
                      ),
                      autofocus: true,
                      onSubmitted: (_) => _handleSave(),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // butonlar
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'İptal',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: AppSpacing.md),
                        
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _hasChanges ? _handleSave : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Kaydet',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}