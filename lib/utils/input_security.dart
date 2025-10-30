import 'package:flutter/widgets.dart';

/// Input güvenliği ve validasyon için utility sınıfı
class InputSecurity {
  // SQL Injection ve XSS koruması için tehlikeli karakterler
  static const List<String> _dangerousPatterns = [
    // SQL Injection patterns
    'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER',
    'UNION', 'OR', 'AND', '--', ';', '/*', '*/', 'xp_', 'sp_',
    
    // XSS patterns
    '<script', '</script>', 'javascript:', 'onload=', 'onerror=',
    'onclick=', 'onmouseover=', 'onfocus=', 'onblur=',
    
    // Command injection
    '&&', '||', '|', ';', '`', '\$(',
    
    // Path traversal
    '../', '..\\', '/etc/', '/bin/', 'C:\\',
  ];

  static const List<String> _spamKeywords = [
    'buy', 'sell', 'cheap', 'free', 'money', 'cash', 'prize', 'winner',
    'click here', 'visit', 'download', 'install', 'viagra', 'casino',
    'lottery', 'inheritance', 'prince', 'million', 'bitcoin', 'crypto'
  ];

  /// Metni güvenli hale getirir (sanitize eder)
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;
    
    String sanitized = input.trim();
    
    // HTML encode
    sanitized = _htmlEncode(sanitized);
    
    // Tehlikeli karakterleri temizle
    sanitized = _removeDangerousChars(sanitized);
    
    // Fazla boşlukları temizle
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    return sanitized;
  }

  /// Input'un güvenli olup olmadığını kontrol eder
  static ValidationResult validateInput(String input, {
    int minLength = 1,
    int maxLength = 1000,
    bool allowSpecialChars = true,
    bool checkForSpam = false,
  }) {
    if (input.isEmpty) {
      return ValidationResult(false, 'Input boş olamaz');
    }

    if (input.length < minLength) {
      return ValidationResult(false, 'En az $minLength karakter olmalıdır');
    }

    if (input.length > maxLength) {
      return ValidationResult(false, 'En fazla $maxLength karakter olabilir');
    }

    // Tehlikeli pattern kontrolü
    if (_containsDangerousPattern(input)) {
      return ValidationResult(false, 'Güvenlik nedeniyle bu içerik kabul edilemez');
    }

    // Spam kontrolü
    if (checkForSpam && _isSpamContent(input)) {
      return ValidationResult(false, 'İçerik spam olarak algılandı');
    }

    // Özel karakter kontrolü
    if (!allowSpecialChars && _containsSpecialChars(input)) {
      return ValidationResult(false, 'Özel karakterler kullanılamaz');
    }

    // Tekrarlanan karakter kontrolü
    if (_hasExcessiveRepetition(input)) {
      return ValidationResult(false, 'Çok fazla tekrarlanan karakter');
    }

    return ValidationResult(true, 'Geçerli');
  }

  /// Word/kelime validasyonu (özel kurallar)
  static ValidationResult validateWord(String word) {
    if (word.isEmpty) {
      return ValidationResult(false, 'Kelime boş olamaz');
    }

    if (word.length < 2) {
      return ValidationResult(false, 'Kelime en az 2 karakter olmalıdır');
    }

    if (word.length > 50) {
      return ValidationResult(false, 'Kelime en fazla 50 karakter olabilir');
    }

    // Sadece harf, rakam, tire ve apostrof kabul et
    if (!RegExp(r"^[a-zA-ZğüşıöçĞÜŞİÖÇ0-9\-'.\s]+$").hasMatch(word)) {
      return ValidationResult(false, 'Kelime geçersiz karakterler içeriyor');
    }

    return ValidationResult(true, 'Geçerli');
  }

  /// Anlam/meaning validasyonu
  static ValidationResult validateMeaning(String meaning) {
    return validateInput(
      meaning,
      minLength: 2,
      maxLength: 500,
      allowSpecialChars: true,
      checkForSpam: false,
    );
  }

  /// Örnek cümle validasyonu
  static ValidationResult validateExample(String example) {
    return validateInput(
      example,
      minLength: 5,
      maxLength: 1000,
      allowSpecialChars: true,
      checkForSpam: false,
    );
  }

  /// Deck ismi validasyonu
  static ValidationResult validateDeckName(String name) {
    return validateInput(
      name,
      minLength: 2,
      maxLength: 50,
      allowSpecialChars: false,
      checkForSpam: false,
    );
  }

  /// Arama sorgusu validasyonu
  static ValidationResult validateSearchQuery(String query) {
    return validateInput(
      query,
      minLength: 1,
      maxLength: 100,
      allowSpecialChars: false,
      checkForSpam: false,
    );
  }

  // Private helper methods
  static String _htmlEncode(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  static String _removeDangerousChars(String input) {
    // Null bytes ve control karakterleri temizle
    return input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
  }

  static bool _containsDangerousPattern(String input) {
    final lowerInput = input.toLowerCase();
    
    for (final pattern in _dangerousPatterns) {
      if (lowerInput.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }

  static bool _isSpamContent(String input) {
    final lowerInput = input.toLowerCase();
    
    // Spam kelime kontrolü
    int spamScore = 0;
    for (final keyword in _spamKeywords) {
      if (lowerInput.contains(keyword)) {
        spamScore++;
      }
    }
    
    // 2 veya daha fazla spam kelimesi varsa spam kabul et
    if (spamScore >= 2) return true;
    
    // URL kontrolü
    if (RegExp(r'http[s]?://|www\.').hasMatch(lowerInput)) return true;
    
    // Telefon numarası kontrolü
    if (RegExp(r'\b\d{10,}\b').hasMatch(input)) return true;
    
    return false;
  }

  static bool _containsSpecialChars(String input) {
    return RegExp(r'[<>{}[\]\\|`~!@#$%^&*()+=;:"\/?]').hasMatch(input);
  }

  static bool _hasExcessiveRepetition(String input) {
    // Aynı karakterin 5'ten fazla tekrarı
    if (RegExp(r'(.)\1{5,}').hasMatch(input)) return true;
    
    // Aynı kelimenin 3'ten fazla tekrarı
    final words = input.toLowerCase().split(' ');
    final wordCount = <String, int>{};
    
    for (final word in words) {
      if (word.length > 2) {
        wordCount[word] = (wordCount[word] ?? 0) + 1;
        if (wordCount[word]! > 3) return true;
      }
    }
    
    return false;
  }
}

/// Validasyon sonucu sınıfı
class ValidationResult {
  final bool isValid;
  final String message;

  const ValidationResult(this.isValid, this.message);
  
  /// Hata mesajı getter'ı - geriye uyumluluk için
  String? get errorMessage => isValid ? null : message;
}

/// Güvenli TextEditingController wrapper
class SecureTextEditingController extends TextEditingController {
  final ValidationResult Function(String)? validator;
  final String Function(String)? sanitizer;

  SecureTextEditingController({
    super.text,
    this.validator,
    this.sanitizer,
  });

  @override
  set text(String newText) {
    String processedText = newText;
    
    // Sanitize if sanitizer provided
    if (sanitizer != null) {
      processedText = sanitizer!(processedText);
    }
    
    super.text = processedText;
  }

  /// Validate current text
  ValidationResult validate() {
    if (validator != null) {
      return validator!(super.text);
    }
    return const ValidationResult(true, 'No validation');
  }
}