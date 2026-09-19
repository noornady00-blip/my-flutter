// ==============================================================================
// 🧊 GLASSMORPHISM UI ATOMS & BUTTONS
// ==============================================================================
// Provides frosted glass containers and buttons with translucent backdrops.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Translucent container widget featuring smooth frosted glass aesthetics.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final dynamic borderRadius; // Accepts double or BorderRadiusGeometry
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;
  final Color? shadowColor;
  final double? shadowBlur;
  final Offset? shadowOffset;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.blur = 0.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.shadows,
    this.shadowColor,
    this.shadowBlur,
    this.shadowOffset,
    this.gradient,
  });

  BorderRadiusGeometry get _resolvedRadius {
    if (borderRadius is BorderRadiusGeometry) {
      return borderRadius as BorderRadiusGeometry;
    } else if (borderRadius is num) {
      return BorderRadius.circular((borderRadius as num).toDouble());
    }
    return BorderRadius.circular(18.0);
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white.withValues(alpha: 0.72);
    final borderCol = borderColor ?? Colors.white.withValues(alpha: 0.5);
    final radius = _resolvedRadius;

    List<BoxShadow> effectiveShadows;
    if (shadows != null) {
      effectiveShadows = shadows!;
    } else if (shadowColor != null ||
        shadowBlur != null ||
        shadowOffset != null) {
      effectiveShadows = [
        BoxShadow(
          color: shadowColor ?? const Color(0xFF0B2A5B).withValues(alpha: 0.04),
          blurRadius: shadowBlur ?? 16,
          offset: shadowOffset ?? const Offset(0, 4),
        ),
      ];
    } else {
      effectiveShadows = [
        BoxShadow(
          color: const Color(0xFF0B2A5B).withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
    }

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderCol, width: borderWidth),
        boxShadow: effectiveShadows,
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

/// Frosted translucent button widget.
class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final String? label;
  final String? text;
  final Color? tintColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final dynamic borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final bool isSelected;
  final bool isLoading;
  final String? tooltip;
  final double? height;
  final double? width;

  const GlassButton({
    super.key,
    required this.onPressed,
    this.child = const SizedBox.shrink(),
    this.icon,
    this.label,
    this.text,
    this.tooltip,
    this.tintColor,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.blur = 8.0,
    this.isSelected = false,
    this.isLoading = false,
    this.height,
    this.width,
  });

  BorderRadiusGeometry get _resolvedRadius {
    if (borderRadius is BorderRadiusGeometry) {
      return borderRadius as BorderRadiusGeometry;
    } else if (borderRadius is num) {
      return BorderRadius.circular((borderRadius as num).toDouble());
    }
    return BorderRadius.circular(12.0);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = text ?? label;
    final primaryTint =
        tintColor ?? backgroundColor ?? const Color(0xFF0B2A5B);
    final radius = _resolvedRadius;

    final Color effectiveBg;
    if (backgroundColor != null) {
      effectiveBg = backgroundColor!;
    } else if (isSelected) {
      effectiveBg = primaryTint.withValues(alpha: 0.14);
    } else if (tintColor != null && textColor == Colors.white) {
      effectiveBg = tintColor!;
    } else {
      effectiveBg = Colors.white.withValues(alpha: 0.65);
    }

    final Color effectiveBorder;
    if (borderColor != null) {
      effectiveBorder = borderColor!;
    } else if (backgroundColor != null) {
      effectiveBorder = backgroundColor!.withValues(alpha: 0.3);
    } else if (tintColor != null && textColor == Colors.white) {
      effectiveBorder = tintColor!.withValues(alpha: 0.3);
    } else if (isSelected) {
      effectiveBorder = primaryTint.withValues(alpha: 0.35);
    } else {
      effectiveBorder = Colors.white.withValues(alpha: 0.8);
    }

    final effectiveText = textColor ??
        (isSelected
            ? primaryTint
            : (effectiveBg.computeLuminance() < 0.45
                ? Colors.white
                : const Color(0xFF334155)));

    Widget inner;
    if (isLoading) {
      inner = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: effectiveText,
          strokeWidth: 2,
        ),
      );
    } else if (effectiveLabel != null) {
      inner = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: effectiveText),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              effectiveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: effectiveText,
              ),
            ),
          ),
        ],
      );
    } else if (icon != null) {
      inner = Icon(icon, size: 18, color: effectiveText);
    } else {
      inner = child;
    }

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: radius is BorderRadius
            ? radius
            : BorderRadius.circular(12),
        child: blur > 0
            ? ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: height,
                    width: width,
                    alignment: Alignment.center,
                    padding: padding,
                    decoration: BoxDecoration(
                      color: effectiveBg,
                      borderRadius: radius,
                      border: Border.all(
                          color: effectiveBorder,
                          width: isSelected ? 1.4 : 1.0),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryTint.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ],
                    ),
                    child: inner,
                  ),
                ),
              )
            : AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: height,
                width: width,
                alignment: Alignment.center,
                padding: padding,
                decoration: BoxDecoration(
                  color: effectiveBg,
                  borderRadius: radius,
                  border: Border.all(
                      color: effectiveBorder,
                      width: isSelected ? 1.4 : 1.0),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryTint.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ],
                ),
                child: inner,
              ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
