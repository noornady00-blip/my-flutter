// ==============================================================================
// 🏷️ APP LOGO BADGE COMPONENT
// ==============================================================================
// Renders the official Mahameek logo within an elevated, high-contrast pill container.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

/// Renders the official logo inside an eye-pleasing pill container with soft shadow.
class AppLogoBadge extends StatelessWidget {
  final double height;
  final bool withPillBackground;

  const AppLogoBadge({
    super.key,
    this.height = 30,
    this.withPillBackground = true,
  });

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
