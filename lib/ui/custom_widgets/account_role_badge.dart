// ==============================================================================
// 🏷️ ACCOUNT ROLE BADGE COMPONENT
// ==============================================================================
// Displays standardized visual badges for Admins (🛡️ مشرف), Lawyers (⚖️ محامٍ),
// and Clients (👤 عميل) with clear iconography and premium color palette.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountRoleBadge extends StatelessWidget {
  final String role; // 'admin' | 'lawyer' | 'client'
  final bool isSmall;

  const AccountRoleBadge({
    super.key,
    required this.role,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    if (role == 'admin') {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8,
          vertical: isSmall ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_rounded,
              color: const Color(0xFF7C3AED),
              size: isSmall ? 11 : 13,
            ),
            const SizedBox(width: 4),
            Text(
              'مشرف',
              style: GoogleFonts.cairo(
                fontSize: isSmall ? 10.5 : 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      );
    }

    if (role == 'lawyer') {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8,
          vertical: isSmall ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFD49B1A).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD49B1A).withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gavel_rounded,
              color: const Color(0xFF0B2A5B),
              size: isSmall ? 11 : 13,
            ),
            const SizedBox(width: 4),
            Text(
              'محامٍ',
              style: GoogleFonts.cairo(
                fontSize: isSmall ? 10.5 : 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
            ),
          ],
        ),
      );
    }

    // Client
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline_rounded,
            color: const Color(0xFF0284C7),
            size: isSmall ? 11 : 13,
          ),
          const SizedBox(width: 4),
          Text(
            'عميل',
            style: GoogleFonts.cairo(
              fontSize: isSmall ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }
}
