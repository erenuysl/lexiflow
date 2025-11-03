import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/word_model.dart';

class WordCard extends StatefulWidget {
  final Word word;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;
  final bool isFavorite;
  final Animation<double>? animation;

  const WordCard({
    super.key,
    required this.word,
    this.onFavoriteToggle,
    this.onTap,
    this.isFavorite = false,
    this.animation,
  });

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> with SingleTickerProviderStateMixin {
  late bool isFavorite;
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    isFavorite = widget.isFavorite;
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    setState(() => isFavorite = !isFavorite);
    if (widget.onFavoriteToggle != null) widget.onFavoriteToggle!();
  }

  @override
  Widget build(BuildContext context) {
    final scale = 1 - _pressController.value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accentColor = Color(0xFF33C4B3);
    final cardColor = isDark ? const Color(0xFF151A1E) : Colors.white;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(0.12);
    final secondaryTextColor =
        isDark ? Colors.white.withOpacity(0.72) : const Color(0xFF5C6C7C);
    return Dismissible(
      key: ValueKey(widget.word.word),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _toggleFavorite(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isFavorite ? Colors.redAccent : Colors.green,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: Colors.white,
          size: 32,
        ),
      ),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey.shade500)
                      .withOpacity(isDark ? 0.35 : 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.style_rounded,
                        color: accentColor.withOpacity(0.6),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.word.word,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111518),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleFavorite,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey(isFavorite),
                            color: isFavorite ? accentColor : secondaryTextColor.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.word.meaning,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.word.example,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: secondaryTextColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
