import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/flashcard_models.dart';
import '../utils/hive_boxes.dart';

class CardsFetchResponse {
  const CardsFetchResponse({required this.sets, required this.offline});

  final List<FlashcardSet> sets;
  final bool offline;
}

class CardsService {
  CardsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Box<dynamic>? _cacheBox;

  Future<Box<dynamic>> _box() async {
    _cacheBox ??= await ensureFlashcardsCacheBox();
    return _cacheBox!;
  }

  String? get _uid => _auth.currentUser?.uid;

  Future<CardsFetchResponse> fetchSets() async {
    final box = await _box();
    if (_uid == null || _uid!.isEmpty) {
      final cachedSets = _readFromCache(box);
      return CardsFetchResponse(sets: cachedSets, offline: true);
    }

    try {
      final query =
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('flashcard_sets')
              .orderBy('updatedAt', descending: true)
              .get();

      final sets =
          query.docs
              .map(
                (doc) => FlashcardSet.fromMap(
                  doc.data()..putIfAbsent('id', () => doc.id),
                ),
              )
              .toList();

      await _syncCache(box, sets);
      return CardsFetchResponse(sets: sets, offline: false);
    } on FirebaseException {
      final cachedSets = _readFromCache(box);
      return CardsFetchResponse(sets: cachedSets, offline: true);
    }
  }

  Future<void> saveSet(FlashcardSet set) async {
    final updatedSet = set.copyWith(updatedAt: DateTime.now());
    final box = await _box();

    await box.put(updatedSet.id, updatedSet.toMap());

    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('flashcard_sets')
        .doc(updatedSet.id)
        .set(updatedSet.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteSet(String id) async {
    final box = await _box();
    await box.delete(id);

    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('flashcard_sets')
        .doc(id)
        .delete();
  }

  Future<void> _syncCache(Box<dynamic> box, List<FlashcardSet> sets) async {
    final existingKeys = box.keys.map((key) => key.toString()).toSet();
    final incomingKeys = <String>{};

    for (final set in sets) {
      incomingKeys.add(set.id);
      await box.put(set.id, set.toMap());
    }

    for (final key in existingKeys.difference(incomingKeys)) {
      await box.delete(key);
    }
  }

  List<FlashcardSet> _readFromCache(Box<dynamic> box) {
    return box.values
        .map(
          (dynamic value) =>
              FlashcardSet.fromMap(Map<String, dynamic>.from(value as Map)),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
