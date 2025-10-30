import 'package:hive/hive.dart';
import '../models/word_model.dart';

class WordStorage {
  static const String boxName = 'wordsBox';

  Future<List<Word>> loadWords() async {
    final box = await Hive.openBox<Word>(boxName);
    return box.values.toList();
  }

  Future<void> saveWords(List<Word> words) async {
    final box = await Hive.openBox<Word>(boxName);
    await box.clear();
    await box.addAll(words);
  }

  Future<void> addWord(Word word) async {
    final box = await Hive.openBox<Word>(boxName);
    await box.add(word);
  }

  Future<void> updateWord(int index, Word word) async {
    final box = await Hive.openBox<Word>(boxName);
    await box.putAt(index, word);
  }

  Future<void> deleteWord(int index) async {
    final box = await Hive.openBox<Word>(boxName);
    await box.deleteAt(index);
  }
}
