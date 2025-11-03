import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/flashcard_models.dart';
import '../../providers/cards_provider.dart';
import '../../utils/lexiflow_colors.dart';
import 'flashcard_view.dart';
import 'study_mode_select_screen.dart';

class CardSetScreen extends StatefulWidget {
  const CardSetScreen({super.key, required this.setId});

  final String setId;

  @override
  State<CardSetScreen> createState() => _CardSetScreenState();
}

class _CardSetScreenState extends State<CardSetScreen> {
  bool _isSaving = false;

  Future<void> _showAddWordsModal() async {
    final typography = context.cardsTypography;
    final palette = context.cardsPalette;

    final newCards = await showModalBottomSheet<List<Flashcard>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddWordsSheet(typography: typography, palette: palette),
    );

    if (newCards == null || newCards.isEmpty) return;

    setState(() => _isSaving = true);
    await context.read<CardsProvider>().addCards(widget.setId, newCards);
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _startStudy(FlashcardSet set) async {
    final direction = await showModalBottomSheet<StudyDirection>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudyModeSelectSheet(setTitle: set.title),
    );
    if (!mounted || direction == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => FlashcardView(set: set, direction: direction),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.cardsPalette;
    final typography = context.cardsTypography;

    final set = context.select<CardsProvider, FlashcardSet?>(
      (provider) => provider.findById(widget.setId),
    );

    if (set == null) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          foregroundColor: palette.textPrimary,
          elevation: 0,
          title: Text('Kart Seti', style: typography.title),
        ),
        body: Center(
          child: Text('Kart seti bulunamadı.', style: typography.body),
        ),
      );
    }

    final cards = set.cards;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        title: Text(set.title, style: typography.title),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _showAddWordsModal,
            style: TextButton.styleFrom(foregroundColor: palette.primary),
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.add_circle_rounded),
            label: const Text('+ Kelime Ekle'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Hero(
                tag: 'card-set-${set.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadowColor,
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                          spreadRadius: -14,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.primary.withOpacityFraction(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '${set.cards.length} kart',
                                  style: typography.label.copyWith(
                                    color: palette.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                set.title,
                                style: typography.headline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Son güncelleme: ${_formatRelative(set.updatedAt)}',
                                style: typography.body.copyWith(
                                  color: palette.textSecondary.withOpacityFraction(
                                    0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.folder_special_rounded,
                          size: 36,
                          color: palette.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child:
                  cards.isEmpty
                      ? _EmptySetState(palette: palette, typography: typography)
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                        itemCount: cards.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return _WordTile(
                            index: index,
                            card: card,
                            palette: palette,
                            typography: typography,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SizedBox(
            height: 64,
            child: ElevatedButton.icon(
              onPressed: cards.isEmpty ? null : () => _startStudy(set),
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text('Kartları Gör'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.surface,
                textStyle: typography.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                disabledBackgroundColor: palette.primary.withOpacityFraction(
                  0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'az önce';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inHours < 24) return '${difference.inHours} sa önce';
    return '${difference.inDays} gün önce';
  }
}

class _EmptySetState extends StatelessWidget {
  const _EmptySetState({required this.palette, required this.typography});

  final LexiFlowCardsPalette palette;
  final LexiFlowCardsTypography typography;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 72,
              color: palette.textSecondary.withOpacityFraction(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu set henüz boş',
              style: typography.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '“+ Kelime Ekle” butonuna dokunarak kelimeleri eklemeye başla.',
              style: typography.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.index,
    required this.card,
    required this.palette,
    required this.typography,
  });

  final int index;
  final Flashcard card;
  final LexiFlowCardsPalette palette;
  final LexiFlowCardsTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: palette.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.wordEn, style: typography.title),
                const SizedBox(height: 6),
                Text(
                  card.wordTr,
                  style: typography.body.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.language_rounded,
            color: palette.textSecondary.withOpacityFraction(0.5),
          ),
        ],
      ),
    );
  }
}

class AddWordsSheet extends StatefulWidget {
  const AddWordsSheet({
    super.key,
    required this.typography,
    required this.palette,
  });

  final LexiFlowCardsTypography typography;
  final LexiFlowCardsPalette palette;

  @override
  State<AddWordsSheet> createState() => _AddWordsSheetState();
}

class _AddWordsSheetState extends State<AddWordsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final TextEditingController _bulkController = TextEditingController(
    text:
        'apple - elma\n'
        'tree - ağaç\n'
        'water - su',
  );
  final List<_WordRowData> _rows = [_WordRowData()];

  bool _isSaving = false;

  @override
  void dispose() {
    _tabController.dispose();
    _bulkController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_WordRowData());
    });
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    final removed = _rows.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _submit() {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final tabIndex = _tabController.index;
    final cards = tabIndex == 0 ? _parseBulk() : _parseRows();
    setState(() => _isSaving = false);
    Navigator.of(context).pop(cards);
  }

  List<Flashcard> _parseBulk() {
    final lines = _bulkController.text.split('\n');
    final List<Flashcard> cards = [];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split('-');
      if (parts.length < 2) continue;
      cards.add(
        Flashcard(
          wordEn: parts.first.trim(),
          wordTr: parts.sublist(1).join('-').trim(),
        ),
      );
    }
    return cards;
  }

  List<Flashcard> _parseRows() {
    final List<Flashcard> cards = [];
    for (final row in _rows) {
      final en = row.wordEn.text.trim();
      final tr = row.wordTr.text.trim();
      if (en.isEmpty || tr.isEmpty) continue;
      cards.add(Flashcard(wordEn: en, wordTr: tr));
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final typography = widget.typography;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: palette.shadowColor,
                blurRadius: 30,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 12),
                alignment: Alignment.center,
                child: Container(
                  width: 56,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.textSecondary.withOpacityFraction(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kelimeleri Gir', style: typography.headline),
                      const SizedBox(height: 8),
                      Text(
                        'Her satıra bir kelime ve anlam yaz:',
                        style: typography.body,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: palette.primary.withOpacityFraction(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Örnek:',
                              style: typography.label.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: palette.primary.withOpacityFraction(
                                    0.05,
                                  ),
                                ),
                              ),
                              child: SelectableText(
                                'apple - elma\n'
                                'tree - ağaç\n'
                                'water - su',
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 14,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TabBar(
                        controller: _tabController,
                        indicatorColor: palette.primary,
                        labelColor: palette.primary,
                        unselectedLabelColor: palette.textSecondary,
                        tabs: const [
                          Tab(text: 'Toplu Giriş'),
                          Tab(text: 'Satır Satır'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 360,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _BulkInput(
                              controller: _bulkController,
                              palette: palette,
                              typography: typography,
                            ),
                            _DynamicRows(
                              rows: _rows,
                              palette: palette,
                              typography: typography,
                              onAddRow: _addRow,
                              onRemoveRow: _removeRow,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.done_rounded),
                      label: const Text('Kaydet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.surface,
                        textStyle: typography.button,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkInput extends StatelessWidget {
  const _BulkInput({
    required this.controller,
    required this.palette,
    required this.typography,
  });

  final TextEditingController controller;
  final LexiFlowCardsPalette palette;
  final LexiFlowCardsTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 15,
          color: palette.textPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: palette.primary.withOpacityFraction(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: palette.primary, width: 2),
          ),
          hintText: 'Kelime - anlam',
          hintStyle: typography.body.copyWith(
            color: palette.textSecondary.withOpacityFraction(0.4),
          ),
        ),
      ),
    );
  }
}

class _DynamicRows extends StatelessWidget {
  const _DynamicRows({
    required this.rows,
    required this.palette,
    required this.typography,
    required this.onAddRow,
    required this.onRemoveRow,
  });

  final List<_WordRowData> rows;
  final LexiFlowCardsPalette palette;
  final LexiFlowCardsTypography typography;
  final VoidCallback onAddRow;
  final void Function(int) onRemoveRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: palette.primary.withOpacityFraction(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelime ${index + 1}',
                      style: typography.label.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RowField(
                            controller: row.wordEn,
                            label: 'Kelime (İngilizce)',
                            palette: palette,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RowField(
                            controller: row.wordTr,
                            label: 'Anlamı (Türkçe)',
                            palette: palette,
                          ),
                        ),
                      ],
                    ),
                    if (rows.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => onRemoveRow(index),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.accent,
                          ),
                          child: const Text('Satırı Sil'),
                        ),
                      ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddRow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Satır Ekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.primary,
              side: BorderSide(color: palette.primary.withOpacityFraction(0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowField extends StatelessWidget {
  const _RowField({
    required this.controller,
    required this.label,
    required this.palette,
  });

  final TextEditingController controller;
  final String label;
  final LexiFlowCardsPalette palette;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: palette.textSecondary,
        ),
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: palette.primary.withOpacityFraction(0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
      ),
    );
  }
}

class _WordRowData {
  _WordRowData()
    : wordEn = TextEditingController(),
      wordTr = TextEditingController();

  final TextEditingController wordEn;
  final TextEditingController wordTr;

  void dispose() {
    wordEn.dispose();
    wordTr.dispose();
  }
}
