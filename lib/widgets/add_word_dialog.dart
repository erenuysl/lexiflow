import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/word_service.dart';
import '../widgets/lexiflow_toast.dart';
import '../utils/input_security.dart';

class AddWordDialog extends StatefulWidget {
  final WordService wordService;
  final String userId;
  final String deckId;

  const AddWordDialog({
    super.key,
    required this.wordService,
    required this.userId,
    required this.deckId,
  });

  @override
  State<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<AddWordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final SecureTextEditingController _wordController;
  late final SecureTextEditingController _meaningController;
  late final SecureTextEditingController _exampleController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    _wordController = SecureTextEditingController(
      validator: InputSecurity.validateWord,
      sanitizer: InputSecurity.sanitizeInput,
    );
    
    _meaningController = SecureTextEditingController(
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
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      // Additional security validation before saving
      final wordText = _wordController.text.trim();
      final meaningText = _meaningController.text.trim();
      final exampleText = _exampleController.text.trim();
      
      // Validate all inputs
      final wordValidation = InputSecurity.validateWord(wordText);
      final meaningValidation = InputSecurity.validateMeaning(meaningText);
      final exampleValidation = InputSecurity.validateExample(exampleText);
      
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
      
      await widget.wordService.addCustomWordToFirestore(
        userId: widget.userId,
        word: InputSecurity.sanitizeInput(wordText),
        meaning: InputSecurity.sanitizeInput(meaningText),
        example: InputSecurity.sanitizeInput(exampleText),
        deckId: widget.deckId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showLexiflowToast(context, ToastType.success, 'Kelime eklendi! ✅');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showLexiflowToast(context, ToastType.error, 'Kelime eklenirken hata oluştu');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceVariant = theme.colorScheme.surfaceContainerHighest;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Yeni Kelime Ekle'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('İngilizce Kelime',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            TextFormField(
              controller: _wordController,
              decoration: InputDecoration(
                hintText: 'Örn: beautiful',
                prefixIcon: const Icon(Icons.abc),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: surfaceVariant.withOpacity(0.6),
                hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
              ),
              style: TextStyle(color: onSurface),
              cursorColor: theme.colorScheme.primary,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen bir kelime girin' : null,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text('Türkçe Anlamı',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            TextFormField(
              controller: _meaningController,
              decoration: InputDecoration(
                hintText: 'Örn: güzel',
                prefixIcon: const Icon(Icons.translate),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: surfaceVariant.withOpacity(0.6),
                hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
              ),
              style: TextStyle(color: onSurface),
              cursorColor: theme.colorScheme.primary,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen Türkçe anlamı girin' : null,
            ),
            const SizedBox(height: 16),
            Text('Örnek Cümle (opsiyonel)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            TextFormField(
              controller: _exampleController,
              decoration: InputDecoration(
                hintText: 'Örn: She is beautiful',
                prefixIcon: const Icon(Icons.format_quote),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: surfaceVariant.withOpacity(0.6),
                hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
              ),
              style: TextStyle(color: onSurface),
              cursorColor: theme.colorScheme.primary,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveWord,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.save),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _isLoading ? 'Kaydediliyor...' : 'Kaydet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ),
      ],
    );
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
}
