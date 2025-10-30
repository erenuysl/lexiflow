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
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).cardColor,
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF232526)
                      : const Color(0xFFF7FAFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(widget.word.word,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                      GestureDetector(
                        onTap: _toggleFavorite,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey(isFavorite),
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(widget.word.meaning, style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey[700])),
                  const SizedBox(height: 10),
                  Text(widget.word.example, style: GoogleFonts.nunito(fontSize: 14, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
