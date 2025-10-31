import 'dart:math' as math;
import '../models/word_model.dart';
import '../utils/logger.dart';

/// Centralized quiz generation service
/// Handles question creation with proper distractors and validation
class QuizGenerator {
  static const int _defaultQuestionCount = 10;
  static const int _minWordsRequired = 4;
  static const int _distractorCount = 3;

  /// Generate a quiz from a list of words
  /// Returns null if insufficient words available
  static QuizData? generateQuiz({
    required List<Word> sourceWords,
    int questionCount = _defaultQuestionCount,
    String quizType = 'general',
  }) {
    try {
      if (sourceWords.length < _minWordsRequired) {
        Logger.w('Insufficient words for quiz: ${sourceWords.length} < $_minWordsRequired', 'QuizGenerator');
        return null;
      }

      // kelime listesini karıştır ve soru sayısına göre sınırla
      final shuffledWords = List<Word>.from(sourceWords);
      shuffledWords.shuffle();
      
      final actualQuestionCount = math.min(questionCount, sourceWords.length);
      final quizWords = shuffledWords.take(actualQuestionCount).toList();

      // her soru için seçenekler oluştur
      final questions = <QuizQuestion>[];
      
      for (int i = 0; i < quizWords.length; i++) {
        final correctWord = quizWords[i];
        final question = _generateQuestion(correctWord, sourceWords, i + 1);
        
        if (question != null) {
          questions.add(question);
        } else {
          Logger.w('Failed to generate question for word: ${correctWord.word}', 'QuizGenerator');
        }
      }

      if (questions.isEmpty) {
        Logger.e('No questions generated for quiz', 'QuizGenerator');
        return null;
      }

      return QuizData(
        questions: questions,
        quizType: quizType,
        totalWords: sourceWords.length,
      );
    } catch (e) {
      Logger.e('Quiz generation failed: $e', 'QuizGenerator');
      return null;
    }
  }

  /// Generate a single question with distractors
  static QuizQuestion? _generateQuestion(
    Word correctWord, 
    List<Word> allWords, 
    int questionNumber
  ) {
    try {
      // doğru cevap dışındaki kelimeleri al
      final wrongWords = allWords
          .where((w) => w.word != correctWord.word)
          .toList();

      if (wrongWords.length < _distractorCount) {
        Logger.w('Not enough distractors for ${correctWord.word}: ${wrongWords.length}', 'QuizGenerator');
        return null;
      }

      // rastgele dikkat dağıtıcılar seç
      wrongWords.shuffle();
      final distractors = wrongWords.take(_distractorCount).toList();

      // tüm seçenekleri karıştır
      final options = [correctWord, ...distractors];
      options.shuffle();

      return QuizQuestion(
        questionNumber: questionNumber,
        correctWord: correctWord,
        options: options,
        correctAnswerIndex: options.indexOf(correctWord),
      );
    } catch (e) {
      Logger.e('Question generation failed for ${correctWord.word}: $e', 'QuizGenerator');
      return null;
    }
  }

  /// Validate if words are sufficient for quiz
  static bool canGenerateQuiz(List<Word> words, {int questionCount = _defaultQuestionCount}) {
    return words.length >= _minWordsRequired;
  }

  /// Get minimum words required message
  static String getInsufficientWordsMessage(int availableWords) {
    return 'Quiz için en az $_minWordsRequired kelime gerekli. Mevcut: $availableWords';
  }
}

/// Quiz data container
class QuizData {
  final List<QuizQuestion> questions;
  final String quizType;
  final int totalWords;

  const QuizData({
    required this.questions,
    required this.quizType,
    required this.totalWords,
  });

  int get questionCount => questions.length;
}

/// Individual quiz question
class QuizQuestion {
  final int questionNumber;
  final Word correctWord;
  final List<Word> options;
  final int correctAnswerIndex;

  const QuizQuestion({
    required this.questionNumber,
    required this.correctWord,
    required this.options,
    required this.correctAnswerIndex,
  });

  bool isCorrectAnswer(Word selectedWord) {
    return selectedWord.word == correctWord.word;
  }
}