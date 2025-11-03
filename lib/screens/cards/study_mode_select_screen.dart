import 'package:flutter/material.dart';
import '../../models/flashcard_models.dart';
import '../../utils/lexiflow_colors.dart';

class StudyModeSelectSheet extends StatefulWidget {
  const StudyModeSelectSheet({super.key, required this.setTitle});

  final String setTitle;

  @override
  State<StudyModeSelectSheet> createState() => _StudyModeSelectSheetState();
}

class _StudyModeSelectSheetState extends State<StudyModeSelectSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 320),
    vsync: this,
  );
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  StudyDirection _direction = StudyDirection.enToTr;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(StudyDirection direction) {
    setState(() {
      _direction = direction;
    });
  }

  void _start() {
    Navigator.of(context).pop(_direction);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.cardsPalette;
    final typography = context.cardsTypography;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowColor,
                  blurRadius: 30,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withOpacityFraction(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('📘 Çalışma Yönünü Seç', style: typography.headline),
                  const SizedBox(height: 8),
                  Text(
                    'Oturuma başlamadan önce yönü belirle:',
                    style: typography.body,
                  ),
                  const SizedBox(height: 24),
                  _StudyDirectionTile(
                    title: '🇬🇧 İngilizce → Türkçe',
                    description:
                        'Ön yüzde İngilizce kelime, arka yüzde Türkçe anlamı gör.',
                    isSelected: _direction == StudyDirection.enToTr,
                    onTap: () => _select(StudyDirection.enToTr),
                    palette: palette,
                    typography: typography,
                  ),
                  const SizedBox(height: 12),
                  _StudyDirectionTile(
                    title: '🇹🇷 Türkçe → İngilizce',
                    description:
                        'Ön yüzde Türkçe anlam, arka yüzde İngilizce kelime gör.',
                    isSelected: _direction == StudyDirection.trToEn,
                    onTap: () => _select(StudyDirection.trToEn),
                    palette: palette,
                    typography: typography,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Başla'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyDirectionTile extends StatelessWidget {
  const _StudyDirectionTile({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    required this.palette,
    required this.typography,
  });

  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final LexiFlowCardsPalette palette;
  final LexiFlowCardsTypography typography;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? palette.primary.withOpacityFraction(0.12)
                  : palette.background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isSelected
                    ? palette.primary
                    : palette.primary.withOpacityFraction(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: palette.primary.withOpacityFraction(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      spreadRadius: -12,
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? palette.primary : palette.textSecondary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.title.copyWith(
                      color:
                          isSelected
                              ? palette.textPrimary
                              : palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(description, style: typography.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
