import 'package:flutter/material.dart';

/// CategoryTheme model that defines visual and textual properties for quiz categories
class CategoryTheme {
  final String emoji;
  final Color color;
  final String title;
  final String description;

  const CategoryTheme({
    required this.emoji,
    required this.color,
    required this.title,
    required this.description,
  });
}

/// Predefined themes for different quiz categories
final Map<String, CategoryTheme> categoryThemes = {
  'history': const CategoryTheme(
    emoji: '📜',
    color: Colors.brown,
    title: 'Tarih',
    description: 'Tarihi olaylar ve kahramanları test et!',
  ),
  'biology': const CategoryTheme(
    emoji: '🧬',
    color: Colors.green,
    title: 'Biyoloji',
    description: 'Canlılar dünyası hakkında bilgin ne kadar iyi?',
  ),
  'technology': const CategoryTheme(
    emoji: '💻',
    color: Colors.blueAccent,
    title: 'Teknoloji',
    description: 'Bilim ve teknoloji konularında kendini dene!',
  ),
  'communication': const CategoryTheme(
    emoji: '💬',
    color: Colors.purpleAccent,
    title: 'İletişim',
    description: 'İletişim becerileri ve dil kullanımını geliştir!',
  ),
  'favorites': const CategoryTheme(
    emoji: '❤️',
    color: Colors.pinkAccent,
    title: 'Favoriler',
    description: 'Favori kelimelerinle pratik yap!',
  ),
  'geography': const CategoryTheme(
    emoji: '🌍',
    color: Colors.teal,
    title: 'Coğrafya',
    description: 'Dünya hakkındaki bilgilerini test et!',
  ),
  'business': const CategoryTheme(
    emoji: '💼',
    color: Colors.indigo,
    title: 'İş Dünyası',
    description: 'İş hayatı ve ekonomi terimleri ile pratik yap!',
  ),
  'psychology': const CategoryTheme(
    emoji: '🧠',
    color: Colors.deepPurple,
    title: 'Psikoloji',
    description: 'İnsan davranışları ve zihin dünyasını keşfet!',
  ),
  'everyday_english': const CategoryTheme(
    emoji: '🗣️',
    color: Colors.orange,
    title: 'Günlük İngilizce',
    description: 'Günlük hayatta kullanılan İngilizce kelimeler!',
  ),
  'learnedWords': const CategoryTheme(
    emoji: '✅',
    color: Colors.greenAccent,
    title: 'Öğrenilenler',
    description: 'Öğrendiğin kelimelerle bilgini test et!',
  ),
  'common_1k': const CategoryTheme(
    emoji: '🎯',
    color: Colors.deepOrange,
    title: '1K Kelime',
    description: 'En yaygın 1000 İngilizce kelime ile pratik yap!',
  ),
};