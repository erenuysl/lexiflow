class FeatureFlags {
  // Yeni Daily Coach deneyimini aç/kapat
  static const bool dailyCoachEnabled = true;

  // Gelecekteki FSRS motor dağıtımı için placeholder
  static const bool fsrsEnabled = true; // FSRS-Lite motorunu etkinleştir

  // Kullanıcıdan doğru cevapları derecelendirmesini iste (zor/iyi/kolay)
  static const bool fsrsQualityPromptEnabled = true;

  // Global log kontrolleri
  // Üretimde çoğu print/debugPrint gürültüsünü susturmak için false yap
  static const bool enableLogs = false;
  // true olduğunda, enableLogs true olsa bile verbose logları izin ver
  static const bool verboseLogs = false;
}
