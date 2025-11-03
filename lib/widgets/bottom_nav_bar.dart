import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    final bottomInset = viewPadding.bottom;
    final effectiveBottom = bottomInset > 0 ? bottomInset : 6.0;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.only(bottom: effectiveBottom),
        height: 70 + (bottomInset > 0 ? bottomInset : 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF203A43).withOpacity(0.85),
              const Color(0xFF2C5364).withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F1F2A).withOpacity(0.7),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  icon: Icons.home_rounded,
                  label: 'Ana Sayfa',
                ),
                _NavItem(
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  icon: Icons.psychology_alt_rounded,
                  label: 'Quiz',
                ),
                const SizedBox(width: 64),
                _NavItem(
                  index: 3,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  icon: Icons.favorite_border_rounded,
                  selectedIcon: Icons.favorite_rounded,
                  label: 'Favoriler',
                ),
                _NavItem(
                  index: 4,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  icon: Icons.person_rounded,
                  label: 'Profil',
                ),
              ],
            ),
            Positioned(
              top: -10,
              child: _CenterButton(
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  bool get _isSelected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    const activeColor = Colors.white;
    final inactiveColor = Colors.white.withOpacity(0.65);

    return SizedBox(
      width: 72,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: _isSelected ? 1.0 : 0.92,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                _isSelected && selectedIcon != null ? selectedIcon : icon,
                size: 26,
                color: _isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: _isSelected ? FontWeight.w700 : FontWeight.w500,
                color: _isSelected ? activeColor : inactiveColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
      color: Colors.white.withOpacity(isSelected ? 1.0 : 0.75),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: isSelected ? 1.0 : 0.94,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF33C4B3), Color(0xFF2DD4BF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF33C4B3).withOpacity(0.6),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(isSelected ? 0.95 : 0.6),
                  width: isSelected ? 4 : 2,
                ),
              ),
              child: const Icon(
                Icons.style_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isSelected ? 1.0 : 0.8,
          child: Text('Kartlar', style: labelStyle),
        ),
      ],
    );
  }
}
