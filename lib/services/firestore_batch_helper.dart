// lib/services/firestore_batch_helper.dart
// Firestore batch işlemlerini optimize etmek için yardımcı sınıf

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

/// Firestore batch işlemlerini optimize eden yardımcı sınıf
class FirestoreBatchHelper {
  final FirebaseFirestore _firestore;
  WriteBatch? _currentBatch;
  int _operationCount = 0;
  
  // Firestore'un batch başına izin verdiği maksimum işlem sayısı
  static const int _maxBatchSize = 500;
  
  // Varsayılan batch boyutu (güvenli bir değer)
  static const int defaultBatchSize = 450;
  
  // Retry mekanizması için maksimum deneme sayısı
  static const int _maxRetries = 3;
  
  // Retry arasındaki bekleme süresi (ms)
  static const int _retryDelayMs = 1000;
  
  FirestoreBatchHelper(this._firestore);
  
  /// Yeni bir batch başlatır veya mevcut batch'i döndürür
  WriteBatch _getBatch() {
    if (_currentBatch == null) {
      _currentBatch = _firestore.batch();
      _operationCount = 0;
    }
    return _currentBatch!;
  }
  
  /// Batch'e bir set işlemi ekler
  void set(DocumentReference docRef, Map<String, dynamic> data, [SetOptions? options]) {
    final batch = _getBatch();
    
    if (options != null) {
      batch.set(docRef, data, options);
    } else {
      batch.set(docRef, data);
    }
    
    _operationCount++;
    _checkBatchSize();
  }
  
  /// Batch'e bir update işlemi ekler
  void update(DocumentReference docRef, Map<String, dynamic> data) {
    final batch = _getBatch();
    batch.update(docRef, data);
    _operationCount++;
    _checkBatchSize();
  }
  
  /// Batch'e bir delete işlemi ekler
  void delete(DocumentReference docRef) {
    final batch = _getBatch();
    batch.delete(docRef);
    _operationCount++;
    _checkBatchSize();
  }
  
  /// Batch boyutunu kontrol eder ve gerekirse otomatik commit yapar
  void _checkBatchSize() {
    if (_operationCount >= defaultBatchSize) {
      commit();
    }
  }
  
  /// Mevcut batch'i commit eder ve retry mekanizması uygular
  Future<void> commit() async {
    if (_currentBatch == null || _operationCount == 0) {
      return;
    }
    
    final batch = _currentBatch!;
    final operationCount = _operationCount;
    
    _currentBatch = null;
    _operationCount = 0;
    
    int retries = 0;
    while (true) {
      try {
        final perfTask = Logger.startPerformanceTask('BatchCommit', 'FirestoreBatchHelper');
        await batch.commit();
        perfTask.finish();
        
        Logger.i('✅ Batch commit başarılı: $operationCount işlem', 'FirestoreBatchHelper');
        break;
      } catch (e) {
        retries++;
        if (retries >= _maxRetries) {
          Logger.e('❌ Batch commit başarısız (son deneme): $e', e, null, 'FirestoreBatchHelper');
          rethrow;
        }
        
        Logger.w('⚠️ Batch commit başarısız (deneme $retries/$_maxRetries): $e', 'FirestoreBatchHelper');
        await Future.delayed(Duration(milliseconds: _retryDelayMs * retries));
      }
    }
  }
  
  /// Tüm bekleyen işlemleri commit eder
  Future<void> commitAll() async {
    await commit();
  }
}