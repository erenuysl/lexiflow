import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/flashcard_models.dart';
import '../../providers/cards_provider.dart';
import '../../utils/lexiflow_colors.dart';
import 'card_set_screen.dart';

class CardsHomeScreen extends StatefulWidget {
  const CardsHomeScreen({super.key});

  @override
  State<CardsHomeScreen> createState() => _CardsHomeScreenState();
}

class _CardsHomeScreenState extends State<CardsHomeScreen> {
  bool _isSubmitting = false;

  Future<void> _createSet(BuildContext context) async {
    final palette = context.cardsPalette;
    final typography = context.cardsTypography;
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadowColor,
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yeni Kart Seti', style: typography.headline),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Örn. İş İngilizcesi',
                      hintStyle: typography.body.copyWith(
                        color: palette.textSecondary.withOpacityFraction(0.6),
                      ),
                      filled: true,
                      fillColor: palette.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: palette.primary.withOpacityFraction(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: palette.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (controller.text.trim().isEmpty) return;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.surface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: Text('Kaydet', style: typography.button),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    final title = controller.text.trim();
    if (title.isEmpty) return;

    final provider = context.read<CardsProvider>();
    setState(() => _isSubmitting = true);
    final createdSet = await provider.createSet(title);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (createdSet == null || !mounted) return;

    await Navigator.of(
      context,
    ).push(_CardsRoute(builder: (_) => CardSetScreen(setId: createdSet.id)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardsProvider>();
    final palette = context.cardsPalette;
    final typography = context.cardsTypography;

    final sets = provider.sets;
    final showSkeleton = provider.isLoading && sets.isEmpty;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text('Kart Setleri', style: typography.title),
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.textPrimary,
        actions: [
          IconButton(
            onPressed: provider.isLoading ? null : () => provider.refreshSets(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : () => _createSet(context),
        heroTag: 'create-set-fab',
        backgroundColor: palette.primary,
        foregroundColor: palette.surface,
        icon:
            _isSubmitting
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Icon(Icons.add_rounded),
        label: const Text('Yeni Set'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.isOffline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: palette.accent.withOpacityFraction(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: palette.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Çevrimdışı mod: Değişiklikler tekrar çevrimiçi olduğunda senkronize edilecek.',
                      style: typography.body.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child:
                  showSkeleton
                      ? const _CardsLoadingView()
                      : sets.isEmpty
                      ? _EmptyState(onCreate: () => _createSet(context))
                      : RefreshIndicator(
                        onRefresh: provider.refreshSets,
                        color: palette.primary,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                          itemCount: sets.length,
                          itemBuilder: (context, index) {
                            final set = sets[index];
                            return _CardSetTile(
                              set: set,
                              typography: typography,
                              palette: palette,
                              onTap: () {
                                Navigator.of(context).push(
                                  _CardsRoute(
                                    builder:
                                        (_) => CardSetScreen(setId: set.id),
                                  ),
                                );
                              },
                              onDelete:
                                  () => context.read<CardsProvider>().deleteSet(
                                    set.id,
                                  ),
                            );
                          },
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 16),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.cardsPalette;
    final typography = context.cardsTypography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 72,
              color: palette.textSecondary.withOpacityFraction(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz set oluşturmadın',
              style: typography.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Kelime listelerini oluştur, organize et ve çalışmaya başla.',
              style: typography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('+ Yeni Set Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardSetTile extends StatelessWidget {
  const _CardSetTile({
    required this.set,
    required this.typography,
    required this.palette,
    required this.onTap,
    this.onDelete,
  });

  final FlashcardSet set;
  final LexiFlowCardsTypography typography;
  final LexiFlowCardsPalette palette;
  final VoidCallback onTap;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.96 + (0.04 * value),
                child: child,
              ),
            ),
          );
        },
        child: Hero(
          tag: 'card-set-${set.id}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadowColor,
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -32,
                    top: -24,
                    child: Transform.rotate(
                      angle: -pi / 20,
                      child: Opacity(
                        opacity: 0.15,
                        child: Container(
                          width: 120,
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: palette.gradient,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
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
                                  color: palette.textSecondary.withOpacityFraction(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.folder_rounded, size: 32, color: palette.primary),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: palette.textSecondary.withOpacityFraction(0.6),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IconButton(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: palette.textSecondary.withOpacityFraction(0.6),
                      ),
                      onPressed: () async {
                        final selected = await showMenu<String>(
                          context: context,
                          position: const RelativeRect.fromLTRB(1000, 0, 16, 0),
                          items: const [
                            PopupMenuItem(value: 'delete', child: Text('Seti Sil')),
                          ],
                        );
                        if (selected == 'delete' && onDelete != null) {
                          await onDelete!();
                        }
                      },
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

  String _formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'az önce';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inHours < 24) return '${difference.inHours} sa önce';
    return '${difference.inDays} gün önce';
  }
}

class _CardsLoadingView extends StatelessWidget {
  const _CardsLoadingView();

  @override
  Widget build(BuildContext context) {
    final palette = context.cardsPalette;

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 16),
          child: Shimmer(
            baseColor: palette.surface,
            highlightColor: palette.surface.withOpacityFraction(0.6),
          ),
        );
      },
    );
  }
}

class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.baseColor,
    required this.highlightColor,
  });

  final Color baseColor;
  final Color highlightColor;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment(-1 + (2 * _controller.value), -1),
              end: Alignment(1 + (2 * _controller.value), 1),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardsRoute<T> extends PageRouteBuilder<T> {
  _CardsRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, animation, __) => builder(context),
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
      );
}
