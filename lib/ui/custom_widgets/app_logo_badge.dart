// ==============================================================================
// 🏷️ APP LOGO BADGE COMPONENT
// ==============================================================================
// Renders the official Mahameek logo within an elevated, high-contrast pill container.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

/// Renders the official logo inside an eye-pleasing pill container with soft shadow.
class AppLogoBadge extends StatelessWidget {
  /// Unified standard height for all header AppBars across client, lawyer, and admin
  static const double defaultHeaderHeight = 26.0;

  final double height;
  final bool withPillBackground;
  final bool isGlass;

  const AppLogoBadge({
    super.key,
    this.height = defaultHeaderHeight,
    this.withPillBackground = true,
    this.isGlass = false,
  });

  /// Standardized constructor specifically for header AppBars
  const AppLogoBadge.header({
    super.key,
    this.isGlass = false,
  })  : height = defaultHeaderHeight,
        withPillBackground = true;

  @override
  Widget build(BuildContext context) {
    final Widget logoImage = Image.asset(
      AppAssets.logoMain,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        AppAssets.splashLogo,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          AppAssets.appLogo,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );

    if (!withPillBackground) {
      return logoImage;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGlass
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isGlass
              ? Colors.white.withValues(alpha: 0.55)
              : const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isGlass ? 0.05 : 0.08),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: logoImage,
    );
  }
}
