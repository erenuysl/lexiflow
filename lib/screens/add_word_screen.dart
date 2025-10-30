import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/session_service.dart';
import '../widgets/lexiflow_toast.dart';
import '../utils/input_security.dart';

class AddWordScreen extends StatefulWidget {
  final WordService wordService;

  const AddWordScreen({
    super.key,
    required this.wordService,
  });

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final SecureTextEditingController _wordController;
  late final SecureTextEditingController _meaningController;
  late final SecureTextEditingController _trController;
  late final SecureTextEditingController _exampleController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Doğrulama ile güvenli kontrolcüleri başlat
    _wordController = SecureTextEditingController(
      validator: InputSecurity.validateWord,
      sanitizer: InputSecurity.sanitizeInput,
    );
    
    _meaningController = SecureTextEditingController(
      validator: InputSecurity.validateMeaning,
      sanitizer: InputSecurity.sanitizeInput,
    );
    
    _trController = SecureTextEditingController(
      validator: InputSecurity.validateMeaning,
      sanitizer: InputSecurity.sanitizeInput,
    );
    
    _exampleController = SecureTextEditingController(
      validator: InputSecurity.validateExample,
      sanitizer: InputSecurity.sanitizeInput,
    );
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _trController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Kaydetmeden önce ek güvenlik doğrulaması
      final wordText = _wordController.text.trim();
      final meaningText = _meaningController.text.trim();
      final exampleText = _exampleController.text.trim();
      final trText = _trController.text.trim();
      
      // Tüm girdileri doğrula
      final wordValidation = InputSecurity.validateWord(wordText);
      final meaningValidation = InputSecurity.validateMeaning(meaningText);
      final exampleValidation = InputSecurity.validateExample(exampleText);
      final trValidation = InputSecurity.validateMeaning(trText);
      
      if (!wordValidation.isValid) {
        _showErrorDialog('Kelime hatası', wordValidation.errorMessage!);
        setState(() => _isLoading = false);
        return;
      }
      
      if (!meaningValidation.isValid) {
        _showErrorDialog('Anlam hatası', meaningValidation.errorMessage!);
        setState(() => _isLoading = false);
        return;
      }
      
      if (!exampleValidation.isValid) {
        _showErrorDialog('Örnek hatası', exampleValidation.errorMessage!);
        setState(() => _isLoading = false);
        return;
      }
      
      if (!trValidation.isValid) {
        _showErrorDialog('Türkçe anlam hatası', trValidation.errorMessage!);
        setState(() => _isLoading = false);
        return;
      }

      final newWord = Word(
        word: InputSecurity.sanitizeInput(wordText),
        meaning: InputSecurity.sanitizeInput(meaningText),
        example: InputSecurity.sanitizeInput(exampleText),
        tr: InputSecurity.sanitizeInput(trText),
        exampleSentence: InputSecurity.sanitizeInput(exampleText),
        isCustom: true,
      );

      // Yerel olarak kaydet (mevcut mimariyle tutarlılığı korur)
      await widget.wordService.addCustomWord(newWord);
      
      // Ayrıca mevcut kullanıcı için Firestore favorilerine ekle
      final session = Provider.of<SessionService>(context, listen: false);
      if (!session.isGuest && !session.isAnonymous && session.currentUser != null) {
        try {
          await widget.wordService.toggleFavoriteFirestore(
            newWord,
            session.currentUser!.uid,
          );
        } catch (firestoreError) {
          print('⚠️ Firestore sync failed: $firestoreError');
          if (mounted) {
            showLexiflowToast(
              context,
              ToastType.info,
              'Kelime yerel olarak kaydedildi, ancak senkronizasyon başarısız oldu',
            );
          }
        }
      }

      if (mounted) {
        showLexiflowToast(
          context,
          ToastType.success,
          'Kelime favorilere eklendi!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Kelime eklenirken hata oluştu';
        
        if (e.toString().contains('network')) {
          errorMessage = 'İnternet bağlantısı hatası. Lütfen bağlantınızı kontrol edin.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Kelime ekleme izni yok. Lütfen giriş yapın.';
        } else if (e.toString().contains('duplicate')) {
          errorMessage = 'Bu kelime zaten mevcut.';
        } else if (e.toString().contains('validation')) {
          errorMessage = 'Kelime bilgileri geçersiz. Lütfen kontrol edin.';
        } else {
          errorMessage = 'Kelime eklenirken hata oluştu: ${e.toString()}';
        }
        
        showLexiflowToast(
          context,
          ToastType.error,
          '❌ $errorMessage',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Kelime Ekle'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Kelime Alanı (Zorunlu)
                Text(
                  'Kelime (İngilizce) *',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _wordController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'örn: serendipity',
                    prefixIcon: const Icon(Icons.text_fields),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kelime boş bırakılamaz';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.none,
                ),
                const SizedBox(height: 24),

                // Anlam Alanı (Zorunlu)
                Text(
                  'Anlamı (İngilizce) *',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _meaningController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'örn: finding something good without looking for it',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Anlam boş bırakılamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Turkish Translation Field (Optional)
                Text(
                  'Türkçe Karşılığı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _trController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'örn: tesadüfen güzel bir şey bulmak',
                    prefixIcon: const Icon(Icons.translate),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 24),

                // Örnek Cümle Alanı (İsteğe Bağlı)
                Text(
                  'Örnek Cümle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _exampleController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'örn: It was pure serendipity that I met her.',
                    prefixIcon: const Icon(Icons.format_quote),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // Eylem Düğmeleri
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveWord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Kaydet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Yardım Metni
                Text(
                  '* işaretli alanlar zorunludur',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
