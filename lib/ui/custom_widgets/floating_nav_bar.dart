// ==============================================================================
// 🧭 FLOATING BOTTOM NAVIGATION BAR
// ==============================================================================
// Custom curved navigation bar with smooth sliding pill indicator and tactile feedback.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Data class holding icons and label for a floating navigation tab item.
class FloatingNavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  const FloatingNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// Floating navigation bar with sliding animated indicator pill.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItemData> items;
  final Color activeColor;
  final Color inactiveColor;
  final Color activeBgColor;
  final Color barBackgroundColor;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor = const Color(0xFF0B2A5B),
    this.inactiveColor = const Color(0xAA0F1B3E),
    this.activeBgColor = Colors.white,
    this.barBackgroundColor = const Color(0xFFD49B1A),
  });

  @override
  Widget build(BuildContext context) {
    final clampedIndex =
        currentIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    final double alignX = items.length > 1
        ? -1.0 + (clampedIndex * 2.0 / (items.length - 1))
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: barBackgroundColor.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.16),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: barBackgroundColor.withValues(alpha: 0.30),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabWidth = items.isNotEmpty
                        ? constraints.maxWidth / items.length
                        : constraints.maxWidth;

                    return Stack(
                      children: [
                        // 1. Sliding Indicator Pill
                        Positioned.fill(
                          child: AnimatedAlign(
                            alignment: AlignmentDirectional(alignX, 0.0),
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            child: SizedBox(
                              width: tabWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2.5, vertical: 1),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.90),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0B2A5B).withValues(alpha: 0.12),
                                            blurRadius: 10,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 3),
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                            spreadRadius: 0,
                                            offset: const Offset(0, -1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 2. Interactive Navigation Tabs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            final isSelected = clampedIndex == index;

                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onTap(index);
                                },
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 5.5),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isSelected ? 1.10 : 1.0,
                                        duration: const Duration(milliseconds: 220),
                                        curve: Curves.easeOutBack,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 200),
                                              transitionBuilder: (child, anim) =>
                                                  FadeTransition(
                                                opacity: anim,
                                                child: ScaleTransition(
                                                    scale: anim, child: child),
                                              ),
                                              child: Icon(
                                                isSelected ? item.activeIcon : item.icon,
                                                key: ValueKey<bool>(isSelected),
                                                color: isSelected ? activeColor : inactiveColor,
                                                size: 20.5,
                                              ),
                                            ),
                                            if (item.badgeCount > 0)
                                              Positioned(
                                                top: -6,
                                                right: -10,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 4.5, vertical: 1),
                                                  constraints: const BoxConstraints(
                                                      minWidth: 16, minHeight: 16),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEF4444),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    border: Border.all(
                                                        color: Colors.white, width: 1.5),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFFEF4444)
                                                            .withValues(alpha: 0.45),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 1.5),
                                                      ),
                                                    ],
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    item.badgeCount > 9
                                                        ? '+9'
                                                        : '${item.badgeCount}',
                                                    style: GoogleFonts.cairo(
                                                      color: Colors.white,
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w900,
                                                      height: 1.1,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 200),
                                        style: GoogleFonts.cairo(
                                          fontSize: 10.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isSelected ? activeColor : inactiveColor,
                                          height: 1.15,
                                        ),
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
