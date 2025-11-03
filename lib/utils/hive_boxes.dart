import 'package:hive_flutter/hive_flutter.dart';

const String flashcardsCacheBox = 'flashcards_cache';

Future<Box<dynamic>> ensureFlashcardsCacheBox() async {
  if (Hive.isBoxOpen(flashcardsCacheBox)) {
    return Hive.box<dynamic>(flashcardsCacheBox);
  }
  return Hive.openBox<dynamic>(flashcardsCacheBox);
}
