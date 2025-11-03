import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/flashcard_models.dart';
import '../../providers/cards_provider.dart';
import '../../utils/lexiflow_colors.dart';

class FlashcardView extends StatefulWidget {
  const FlashcardView({super.key, required this.set, required this.direction});

  final FlashcardSet set;
  final StudyDirection direction;

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> {
  late final PageController _pageController = PageController();
  late final List<Flashcard> _cards = List.of(widget.set.cards);
  int _currentIndex = 0;

  Flashcard get _currentCard => _cards[_currentIndex];

  void _shuffleCards() {
    setState(() {
      _cards.shuffle();
      _currentIndex = 0;
    });
    _pageController.jumpToPage(0);
  }

  void _toggleFavorite() {
    final provider = context.read<CardsProvider>();
    final updatedCard = _cards[_currentIndex].copyWith(
      isFavorite: !_cards[_currentIndex].isFavorite,
    );
    setState(() {
      _cards[_currentIndex] = updatedCard;
    });
    provider.toggleFavorite(setId: widget.set.id, cardIndex: _currentIndex);
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.cardsPalette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: palette.gradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.set.title,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_currentIndex + 1} / ${_cards.length}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacityFraction(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacityFraction(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sync_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.direction == StudyDirection.enToTr
                                ? 'EN → TR'
                                : 'TR → EN',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: _cards.length,
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FlashcardFlip(
                        key: ValueKey(
                          '${card.wordEn}-${card.wordTr}-${widget.direction}-$index',
                        ),
                        card: card,
                        direction: widget.direction,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacityFraction(
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.08
                          : 0.15,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ToolbarAction(
                        icon: Icons.shuffle_rounded,
                        label: 'Karıştır',
                        onTap: _shuffleCards,
                      ),
                      _ToolbarAction(
                        icon:
                            _currentCard.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                        label: 'Favori',
                        isActive: _currentCard.isFavorite,
                        onTap: _toggleFavorite,
                      ),
                      _ToolbarAction(
                        icon: Icons.restart_alt_rounded,
                        label: 'Başa Dön',
                        onTap: _restart,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class FlashcardFlip extends StatefulWidget {
  const FlashcardFlip({super.key, required this.card, required this.direction});

  final Flashcard card;
  final StudyDirection direction;

  @override
  State<FlashcardFlip> createState() => _FlashcardFlipState();
}

class _FlashcardFlipState extends State<FlashcardFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 450),
    vsync: this,
  );

  late final Animation<double> _rotation = Tween<double>(
    begin: 0,
    end: pi,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack));

  bool _showFront = true;

  void _toggleCard() {
    if (_showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  @override
  void didUpdateWidget(covariant FlashcardFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card != widget.card ||
        oldWidget.direction != widget.direction) {
      _controller.reset();
      _showFront = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.cardsPalette;
    final typography = context.cardsTypography;
    final frontText =
        widget.direction == StudyDirection.enToTr
            ? widget.card.wordEn
            : widget.card.wordTr;
    final backText =
        widget.direction == StudyDirection.enToTr
            ? widget.card.wordTr
            : widget.card.wordEn;

    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (context, child) {
          final value = _rotation.value;
          final isFront = value < pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(value),
            child:
                isFront
                    ? _FlashcardSide(
                      palette: palette,
                      typography: typography,
                      word: frontText,
                      subtitle:
                          widget.direction == StudyDirection.enToTr
                              ? 'İngilizce'
                              : 'Türkçe',
                      flipHint: 'Dokun ve çevir',
                      icon: Icons.keyboard_double_arrow_right_rounded,
                    )
                    : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _FlashcardSide(
                        palette: palette,
                        typography: typography,
                        word: backText,
                        subtitle:
                            widget.direction == StudyDirection.enToTr
                                ? 'Türkçe'
                                : 'İngilizce',
                        flipHint: 'Tekrar çevir',
                        icon: Icons.keyboard_double_arrow_left_rounded,
                      ),
                    ),
          );
        },
      ),
    );
  }
}

class _FlashcardSide extends StatelessWidget {
  const _FlashcardSide({
    required this.palette,
    required this.typography,
    required this.word,
    required this.subtitle,
    required this.flipHint,
    required this.icon,
  });

  final LexiFlowCardsPalette palette;
  final LexiFlowCardsTypography typography;
  final String word;
  final String subtitle;
  final String flipHint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 28,
            offset: const Offset(0, 18),
            spreadRadius: -12,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: palette.primary.withOpacityFraction(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              subtitle,
              style: typography.label.copyWith(
                color: palette.primary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            word,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Opacity(
            opacity: 0.7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: palette.textSecondary),
                const SizedBox(width: 8),
                Text(flipHint, style: typography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatefulWidget {
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  State<_ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<_ToolbarAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 120),
    vsync: this,
    lowerBound: 0.95,
    upperBound: 1.0,
    value: 1.0,
  );

  void _handleTap() async {
    await _controller.reverse();
    await _controller.forward();
    widget.onTap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: GestureDetector(
        onTap: _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color:
                  widget.isActive
                      ? Colors.white
                      : Colors.white.withOpacityFraction(0.85),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    widget.isActive
                        ? Colors.white
                        : Colors.white.withOpacityFraction(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
