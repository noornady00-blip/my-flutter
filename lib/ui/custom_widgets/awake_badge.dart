// ==============================================================================
// 🔋 AWAKE 24/7 BADGE WIDGET (يقظ 24/7)
// ==============================================================================
// Note: Visually hidden as requested by user while real-time keep-alive 24/7
// background synchronization continues working seamlessly behind the scenes.
// ==============================================================================

import 'package:flutter/material.dart';

class Awake247Badge extends StatelessWidget {
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final double dotSize;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool showInfoOnTap;

  const Awake247Badge({
    super.key,
    this.textColor = const Color(0xFF0B2A5B),
    this.backgroundColor = const Color(0x40FFFFFF),
    this.borderColor = const Color(0x80FFFFFF),
    this.dotSize = 6.5,
    this.fontSize = 10.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    this.showInfoOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    // Visually hidden everywhere while 24/7 background keep-alive continues running
    return const SizedBox.shrink();
  }
}
