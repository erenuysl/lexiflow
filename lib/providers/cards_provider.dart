import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/flashcard_models.dart';
import '../services/cards_service.dart';

class CardsProvider extends ChangeNotifier {
  CardsProvider({CardsService? service, FirebaseAuth? auth})
    : _service = service ?? CardsService(),
      _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen((_) {
      _hasLoaded = false;
      loadSets();
    });
  }

  final CardsService _service;
  final FirebaseAuth _auth;

  final List<FlashcardSet> _sets = [];

  StreamSubscription<User?>? _authSub;
  bool _isLoading = false;
  bool _isOffline = false;
  bool _hasLoaded = false;

  List<FlashcardSet> get sets => List.unmodifiable(_sets);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  Future<void> loadSets() async {
    if (_isLoading) return;
    if (_hasLoaded && _auth.currentUser != null) return;

    _isLoading = true;
    notifyListeners();
    try {
      final response = await _service.fetchSets();
      _sets
        ..clear()
        ..addAll(response.sets);
      _sortSets();
      _isOffline = response.offline;
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSets() async {
    _isOffline = false;
    _hasLoaded = false;
    await loadSets();
  }

  FlashcardSet? findById(String id) {
    try {
      return _sets.firstWhere((set) => set.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<FlashcardSet?> createSet(String title) async {
    final ownerId = _auth.currentUser?.uid ?? 'local';
    final newSet = FlashcardSet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      cards: const [],
      ownerId: ownerId,
      updatedAt: DateTime.now(),
    );

    _sets.insert(0, newSet);
    _sortSets();
    notifyListeners();
    await _service.saveSet(newSet);
    return newSet;
  }

  Future<void> addCards(String setId, List<Flashcard> newCards) async {
    final index = _sets.indexWhere((set) => set.id == setId);
    if (index == -1 || newCards.isEmpty) return;

    final target = _sets[index];
    final updated = target.copyWith(
      cards: [...target.cards, ...newCards],
      updatedAt: DateTime.now(),
    );
    _sets[index] = updated;
    _sortSets();
    notifyListeners();
    await _service.saveSet(updated);
  }

  Future<void> updateSet(FlashcardSet updatedSet) async {
    final index = _sets.indexWhere((set) => set.id == updatedSet.id);
    if (index == -1) return;
    _sets[index] = updatedSet.copyWith(updatedAt: DateTime.now());
    _sortSets();
    notifyListeners();
    await _service.saveSet(_sets[index]);
  }

  Future<void> deleteSet(String id) async {
    _sets.removeWhere((set) => set.id == id);
    notifyListeners();
    await _service.deleteSet(id);
  }

  Future<void> toggleFavorite({
    required String setId,
    required int cardIndex,
  }) async {
    final index = _sets.indexWhere((set) => set.id == setId);
    if (index == -1) return;

    final target = _sets[index];
    if (cardIndex < 0 || cardIndex >= target.cards.length) return;

    final cards = List<Flashcard>.from(target.cards);
    final card = cards[cardIndex];
    cards[cardIndex] = card.copyWith(isFavorite: !card.isFavorite);

    final updated = target.copyWith(cards: cards, updatedAt: DateTime.now());
    _sets[index] = updated;
    _sortSets();
    notifyListeners();
    await _service.saveSet(updated);
  }

  void _sortSets() {
    _sets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
