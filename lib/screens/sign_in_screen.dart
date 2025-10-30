import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/session_service.dart';
import '../services/sync_manager.dart';
import '../widgets/lexiflow_toast.dart';

/// SignInScreen provides Google Sign-In and Guest mode options
/// No constructor parameters - uses Provider to access SessionService
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isLoading = false;
  bool _hasCheckedOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _checkOfflineModeAndAutoLogin();
  }

  Future<void> _checkOfflineModeAndAutoLogin() async {
    if (_hasCheckedOfflineMode) return;
    _hasCheckedOfflineMode = true;

    // Kısa bir gecikme ile bağlantı durumunu kontrol et
    await Future.delayed(const Duration(milliseconds: 500));
    
    final syncManager = SyncManager();
    if (!syncManager.isOnline) {
      // İnternet yoksa otomatik olarak misafir moduna geç
      await _handleAutoGuestSignIn();
    }
  }

  Future<void> _handleAutoGuestSignIn() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final user = await sessionService.signInAsGuest();
    
    if (mounted && user != null) {
      // Otomatik misafir girişi başarılı olduğunda bildirim göster
      showLexiflowToast(context, ToastType.info, 'İnternet bağlantısı yok. Misafir modunda devam ediyorsunuz.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final sessionService = Provider.of<SessionService>(context, listen: false);
    final syncManager = SyncManager();
    
    // İnternet bağlantısını kontrol et
    if (!syncManager.isOnline) {
      setState(() => _isLoading = false);
      _showOfflineErrorDialog();
      return;
    }

    final user = await sessionService.signInWithGoogle();
    final success = user != null;

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        // Başarılı giriş sonrası ana sayfaya yönlendir
        // AuthWrapper otomatik olarak MainNavigation'ı gösterecek
        Navigator.of(context).pushReplacementNamed('/');
      } else {
        _showGoogleSignInErrorDialog();
      }
    }
  }

  /// Improved offline error dialog with Material 3 design and better UX
  void _showOfflineErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.red.shade600,
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Bağlantı Yok',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Message
              Text(
                'İnternete bağlanamadık.\nLütfen kontrol edin.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'İptal',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _retryConnectivity();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Tekrar Dene',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Divider
              Divider(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                thickness: 1,
              ),
              const SizedBox(height: 12),
              
              // Guest mode button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleGuestLogin();
                  },
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(
                    'Misafir Modunda Devam Et',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                    side: BorderSide(
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Retry connectivity check with proper feedback
  Future<void> _retryConnectivity() async {
    setState(() => _isLoading = true);
    
    try {
      // Force connectivity recheck
      final result = await Connectivity().checkConnectivity();
      final isOnline = result != ConnectivityResult.none;
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (isOnline) {
          // Connection restored, proceed with Google Sign-In
          _handleGoogleSignIn();
        } else {
          // Still offline, show dialog again
          _showOfflineErrorDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showOfflineErrorDialog();
      }
    }
  }

  /// Improved guest login with proper connectivity checks and error handling
  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);

    try {
      // Always attempt guest login regardless of connectivity
      final sessionService = Provider.of<SessionService>(context, listen: false);
      final user = await sessionService.signInAsGuest();
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (sessionService.isAuthenticated) {
          // Navigate to home screen
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          showLexiflowToast(
            context,
            ToastType.error,
            'Misafir girişi başarısız oldu. Lütfen tekrar deneyin.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showLexiflowToast(context, ToastType.error, 'Giriş sırasında bir hata oluştu. Lütfen tekrar deneyin.');
      }
    }
  }

  void _showGoogleSignInErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Giriş Başarısız'),
          ],
        ),
        content: const Text(
          'Google ile giriş yapılamadı. Bu durum şu nedenlerden kaynaklanabilir:\n\n• İnternet bağlantısı sorunu\n• Google hesap ayarları\n• Geçici sunucu sorunu\n\nLütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleGuestLogin();
            },
            child: const Text('Misafir Modu'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleGoogleSignIn();
            },
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleGuestSignIn() async {
    setState(() => _isLoading = true);

    final sessionService = Provider.of<SessionService>(context, listen: false);
    final user = await sessionService.signInAsGuest();
    final success = user != null;

    if (mounted) {
      setState(() => _isLoading = false);

      if (!success) {
        showLexiflowToast(context, ToastType.error, 'Misafir girişi yapılamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                  ]
                : [
                    const Color(0xFF43E8D8), // Teal
                    const Color(0xFF5AB2FF), // Blue
                    const Color(0xFF4A90E2), // Deep Blue
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon/Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/logo/lexiflow_logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.book_rounded,
                            size: 64,
                            color: Color(0xFF5AB2FF),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App Title
                  Text(
                    'LexiFlow',
                    style: GoogleFonts.inter(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Kelime öğrenmenin en kolay yolu',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 64),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF5AB2FF),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
      Icons.g_mobiledata, // veya Icons.language, Icons.account_circle
  color: Colors.redAccent,
  size: 24,
    ),
                                const SizedBox(width: 12),
                                Text(
                                  'Google ile Giriş Yap',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Guest Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleGuestLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_outline, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Misafir Olarak Devam Et',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Info Text
                  Text(
                    'Misafir modunda ilerlemeniz kaydedilmez',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}