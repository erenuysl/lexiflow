import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// LexiFlow uygulaması için birleşik loglama utility'si
/// 
/// Kullanım:
/// - Logger.i('Kullanıcı başarıyla giriş yaptı')
/// - Logger.w('Kelime için cache miss: $wordId')
/// - Logger.e('Veri yüklenemedi', error, stackTrace)
/// - Logger.d('Verbose debug bilgisi')
class Logger {
  static void d(String message, [String? tag]) {
    _log('DEBUG', message, tag);
  }

  static void i(String message, [String? tag]) {
    _log('INFO', message, tag);
  }

  static void w(String message, [String? tag]) {
    _log('WARNING', message, tag);
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    _log('ERROR', message, tag);
    if (error != null) {
      if (kDebugMode) {
        print('ERROR DETAILS: $error');
      }
    }
    if (stackTrace != null) {
      if (kDebugMode) {
        print('STACK TRACE: $stackTrace');
      }
    }
  }

  static void _log(String level, String message, [String? tag]) {
    if (kDebugMode) {
      final now = DateTime.now();
      final formattedDate = '${now.hour}:${now.minute}:${now.second}.${now.millisecond}';
      final tagStr = tag != null ? '[$tag]' : '';
      print('$formattedDate [$level]$tagStr $message');
    }
  }
  
  /// Başarı seviyesi - önemli başarılı işlemleri vurgular
  /// Kullanım alanı: önemli başarılı tamamlamalar
  /// Örnek: Logger.success('Kullanıcı profili başarıyla senkronize edildi')
  static void success(String message, [String? tag]) {
    _log('SUCCESS', message, tag);
  }
  
  /// Bellek kullanımını logla
  static void logMemoryUsage(String operation, [String? tag]) {
    if (!kDebugMode) return;
    
    try {
      final tagStr = tag != null ? '[$tag]' : '';
      if (kDebugMode) {
        print('🧠 MEMORY $tagStr [$operation]');
      }
      
      // Timeline'a bellek kullanım bilgisini ekle
      developer.Timeline.instantSync(
        'Memory Usage - $operation',
        arguments: {'operation': operation, 'tag': tag ?? 'App'},
      );
      
      // Garbage collection call removed to prevent MissingPluginException
      // _requestGC();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Memory logging error: $e');
      }
    }
  }
  
  /// Performans ölçümü için TimelineTask başlatır
  static developer.TimelineTask startPerformanceTask(String name, [String? tag]) {
    final task = developer.TimelineTask();
    
    if (kDebugMode) {
      try {
        task.start(name);
        print('⏱️ PERFORMANCE START [$tag] $name');
      } catch (e) {
        print('⚠️ Timeline task start failed: $e');
      }
    }
    
    return task;
  }
  
  /// Performans ölçümünü güvenli şekilde bitirir
  static void finishPerformanceTask(developer.TimelineTask task, [String? tag, String? name]) {
    if (kDebugMode) {
      try {
        task.finish();
        print('⏱️ PERFORMANCE END [$tag] $name');
      } catch (e) {
        print('⚠️ Timeline task finish failed: $e');
      }
    }
  }
  
  // Removed _requestGC method to prevent MissingPluginException
  // The gc method on flutter/system channel is not available in all environments
}

