/// Tekrar aralıklarını planlama ve güncelleme için SRS utility fonksiyonları
library;

import '../models/word_model.dart';

/// Gün cinsinden SRS aralıkları (örn. 1, 3, 7, 15, 30, ...)
const List<int> srsIntervals = [1, 3, 7, 15, 30, 60, 120];

/// Streak/doğru cevap sayısına göre bir sonraki tekrar tarihini hesaplar.
DateTime calculateNextReviewDate(int currentStreak) {
  int idx = currentStreak.clamp(0, srsIntervals.length - 1);
  return DateTime.now().add(Duration(days: srsIntervals[idx]));
}

/// Quiz etkileşiminden sonra kelimenin SRS alanlarını günceller.
/// Doğruysa: streak artar, aralık artar. Yanlışsa: streak sıfırlanır, aralık 1 güne döner.
Word updateSRSOnAnswer(Word word, {required bool correct}) {
  if (correct) {
    int newStreak = word.correctStreak + 1;
    DateTime nextDate = calculateNextReviewDate(newStreak);
    return Word(
      word: word.word,
      meaning: word.meaning,
      example: word.example,
      isFavorite: word.isFavorite,
      nextReviewDate: nextDate,
      interval: srsIntervals[newStreak.clamp(0, srsIntervals.length - 1)],
      correctStreak: newStreak,
    );
  } else {
    DateTime nextDate = calculateNextReviewDate(0);
    return Word(
      word: word.word,
      meaning: word.meaning,
      example: word.example,
      isFavorite: word.isFavorite,
      nextReviewDate: nextDate,
      interval: srsIntervals[0],
      correctStreak: 0,
    );
  }
}
