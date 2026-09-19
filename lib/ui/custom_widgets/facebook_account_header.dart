// ==============================================================================
// 👤 FACEBOOK-STYLE ACCOUNT HEADER COMPONENT
// ==============================================================================
// Displays user profile picture, display name, verification badge, and details modal trigger.
// ==============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/lawyer.dart';
import '../../data/models/user_model.dart';
import '../../network/auth_service.dart';
import '../../core/utils/phone_utils.dart';
import 'profile_details_modal.dart';

/// Social header component rendering avatar, badges, and user info with modal tap handler.
class FacebookAccountHeader extends StatefulWidget {
  final String phone;
  final String? uid;
  final String? fallbackName;
  final String? fallbackPhotoUrl;
  final String? fallbackPhotoBase64;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onHeaderTap;
  final bool compact;

  const FacebookAccountHeader({
    super.key,
    required this.phone,
    this.uid,
    this.fallbackName,
    this.fallbackPhotoUrl,
    this.fallbackPhotoBase64,
    this.subtitle,
    this.trailing,
    this.onHeaderTap,
    this.compact = false,
  });

  static final Map<String, Map<String, dynamic>?> _accountCache = {};
  static final Map<String, Map<String, dynamic>?> _uidCache = {};

  @override
  State<FacebookAccountHeader> createState() => _FacebookAccountHeaderState();
}

class _FacebookAccountHeaderState extends State<FacebookAccountHeader> {
  Map<String, dynamic>? _accountData;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void didUpdateWidget(covariant FacebookAccountHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phone != widget.phone || oldWidget.uid != widget.uid) {
      _loadAccount();
    }
  }

  Future<void> _loadAccount() async {
    if (widget.uid != null && widget.uid!.trim().isNotEmpty) {
      final targetUid = widget.uid!.trim();
      if (FacebookAccountHeader._uidCache.containsKey(targetUid)) {
        final cached = FacebookAccountHeader._uidCache[targetUid];
        if (cached != null) {
          if (mounted) setState(() => _accountData = cached);
          return;
        }
      }

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final res = {
            'uid': targetUid,
            'role': userDoc.data()?['role']?.toString() ?? 'client',
            'data': userDoc.data()!,
          };
          FacebookAccountHeader._uidCache[targetUid] = res;
          if (mounted) setState(() => _accountData = res);
          return;
        }

        final lawyerDoc = await FirebaseFirestore.instance
            .collection('lawyers')
            .doc(targetUid)
            .get();
        if (lawyerDoc.exists && lawyerDoc.data() != null) {
          final res = {
            'uid': targetUid,
            'role': 'lawyer',
            'data': lawyerDoc.data()!,
          };
          FacebookAccountHeader._uidCache[targetUid] = res;
          if (mounted) setState(() => _accountData = res);
          return;
        }
      } catch (_) {}
    }

    final clean = widget.phone.trim();
    if (clean.isEmpty) return;

    if (FacebookAccountHeader._accountCache.containsKey(clean)) {
      if (mounted) {
        setState(() {
          _accountData = FacebookAccountHeader._accountCache[clean];
        });
      }
      return;
    }

    try {
      final res = await AuthService().checkPhoneRegistration(clean);
      FacebookAccountHeader._accountCache[clean] = res;
      if (res != null && res['uid'] != null) {
        FacebookAccountHeader._uidCache[res['uid'].toString()] = res;
      }
      if (mounted) {
        setState(() {
          _accountData = res;
        });
      }
    } catch (_) {}
  }

  void _openUserProfile(BuildContext context) {
    if (widget.onHeaderTap != null) {
      widget.onHeaderTap!();
      return;
    }

    if (_accountData != null) {
      final role = _accountData!['role']?.toString();
      final data = _accountData!['data'] as Map<String, dynamic>? ?? {};
      final uid = _accountData!['uid']?.toString() ?? '';

      if (role == 'lawyer') {
        final lawyer = LawyerModel.fromMap(data, uid);
        ProfileDetailsModal.showLawyerModal(
          context,
          lawyer: lawyer,
          isAdmin: true,
        );
        return;
      } else {
        final client = UserModel.fromMap(data, uid);
        ProfileDetailsModal.showClientModal(
          context,
          client: client,
          isAdmin: true,
        );
        return;
      }
    }

    final fallbackClient = UserModel(
      uid: widget.uid ??
          'guest_${widget.phone.replaceAll(RegExp(r'[^0-9]'), '')}',
      name: (widget.fallbackName?.trim().isNotEmpty == true)
          ? widget.fallbackName!.trim()
          : 'مستخدم المنصة',
      phone: widget.phone.trim(),
      photoUrl: widget.fallbackPhotoUrl,
      photoBase64: widget.fallbackPhotoBase64,
      role: 'client',
      createdAt: DateTime.now(),
    );

    ProfileDetailsModal.showClientModal(
      context,
      client: fallbackClient,
      isAdmin: true,
    );
  }

  Widget _buildAvatar(
      String? photoBase64, String? photoUrl, String name, double size) {
    if (photoBase64 != null && photoBase64.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64.trim());
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallbackInitial(name, size),
          ),
        );
      } catch (_) {}
    }

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl.trim(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackInitial(name, size),
        ),
      );
    }

    return _buildFallbackInitial(name, size);
  }

  Widget _buildFallbackInitial(String name, double size) {
    final initial =
        name.trim().isNotEmpty ? name.trim().characters.first : 'م';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0B2A5B), Color(0xFF1E2E60)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.cairo(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFBBF24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLawyer = _accountData?['role'] == 'lawyer';
    final bool isClient = _accountData != null && !isLawyer;
    final data = _accountData?['data'] as Map<String, dynamic>?;

    final displayName = (data?['name']?.toString().trim().isNotEmpty == true)
        ? data!['name'].toString().trim()
        : (widget.fallbackName?.trim().isNotEmpty == true
            ? widget.fallbackName!.trim()
            : (isLawyer
                ? 'محامي مسجل'
                : (isClient ? 'عميل مسجل' : 'حساب: ${widget.phone}')));

    final photoBase64 =
        data?['photoBase64']?.toString() ?? widget.fallbackPhotoBase64;
    final photoUrl = data?['photoUrl']?.toString() ?? widget.fallbackPhotoUrl;

    String sub = widget.subtitle ?? '';
    if (sub.isEmpty) {
      if (isLawyer) {
        final spec = data?['specialization']?.toString() ?? 'محامي ومستشار';
        final city = data?['city']?.toString() ?? '';
        sub = city.isNotEmpty ? '$spec • $city' : spec;
      } else if (isClient) {
        sub = 'عميل مسجل بالمنصة';
      }
    }

    final double avatarSize = widget.compact ? 38.0 : 46.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUserProfile(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              GestureDetector(
                // Normal tap → open user profile
                onTap: () => _openUserProfile(context),
                // Long press → view full-screen photo
                onLongPress: () {
                  if ((photoBase64 != null && photoBase64.isNotEmpty) ||
                      (photoUrl != null && photoUrl.isNotEmpty)) {
                    ProfileDetailsModal.openPhotoViewer(
                      context,
                      name: displayName,
                      photoBase64: photoBase64,
                      photoUrl: photoUrl,
                      subtitle: sub.isNotEmpty ? sub : 'صورة الحساب الشخصية',
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0B2A5B),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildAvatar(
                      photoBase64, photoUrl, displayName, avatarSize),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: GoogleFonts.cairo(
                              fontSize: widget.compact ? 13.5 : 14.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLawyer) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              'محامي',
                              style: GoogleFonts.cairo(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        sub,
                        style: GoogleFonts.cairo(
                          fontSize: widget.compact ? 11 : 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (widget.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            PhoneUtils.formatForDisplay(widget.phone.trim()),
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
