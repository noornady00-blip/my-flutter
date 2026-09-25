// ==============================================================================
// 🔋 AWAKE 24/7 BADGE WIDGET (يقظ 24/7)
// ==============================================================================
// Displays a luxurious glowing live status badge for Admin, Lawyers, and Clients
// indicating real-time active synchronization and keep-alive 24/7 connectivity.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Awake247Badge extends StatefulWidget {
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
  State<Awake247Badge> createState() => _Awake247BadgeState();
}

class _Awake247BadgeState extends State<Awake247Badge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF10B981),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'نظام الاتصال المباشر 24/7',
                style: GoogleFonts.cairo(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B2A5B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'حسابك متصل بشكل حي ومباشر على مدار الساعة (24/7). يضمن هذا النظام استلام الرسائل الجديدة، التنبيهات، والإشعارات الفورية دون أي تأخير.',
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    'حسناً، فهمت',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.showInfoOnTap ? () => _showInfoDialog(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(
                    alpha: 0.15 * _pulseAnim.value,
                  ),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFF059669),
                      const Color(0xFF34D399),
                      _pulseAnim.value,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(
                          alpha: 0.8 * _pulseAnim.value,
                        ),
                        blurRadius: 4 * _pulseAnim.value,
                        spreadRadius: 1 * _pulseAnim.value,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'يقظ 24/7',
                  style: GoogleFonts.cairo(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w800,
                    color: widget.textColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
