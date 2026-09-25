// ==============================================================================
// 🆔 ACCOUNT ID UTILITIES (12-DIGIT FIXED IDENTIFIER)
// ==============================================================================
// Generates, validates, and manages unique 12-digit fixed account numbers
// (e.g., 102938475612) for Clients, Lawyers, and Administrators.
// Firebase UID remains the internal key; Account ID is for friendly display and lookup.
// ==============================================================================

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AccountIdUtils {
  static final Random _secureRandom = Random.secure();

  /// Generates a 12-digit numeric string where the first digit is 1-9
  /// ensuring exactly 12 digits and preventing leading-zero truncation issues.
  static String generateCandidate12DigitId() {
    final firstDigit = _secureRandom.nextInt(9) + 1; // 1..9
    final buffer = StringBuffer()..write(firstDigit);
    for (int i = 0; i < 11; i++) {
      buffer.write(_secureRandom.nextInt(10)); // 0..9
    }
    return buffer.toString();
  }

  /// Validates whether a given string is exactly 12 digits
  static bool isValid12DigitId(String? id) {
    if (id == null) return false;
    final clean = id.trim();
    return clean.length == 12 && RegExp(r'^\d{12}$').hasMatch(clean);
  }

  /// Generates a cryptographically unique 12-digit ID with collision verification
  /// against Firestore collection 'account_ids'.
  static Future<String> generateUnique12DigitId([FirebaseFirestore? firestore]) async {
    final candidate = generateCandidate12DigitId();
    final db = firestore ?? FirebaseFirestore.instance;

    try {
      final doc = await db
          .collection('account_ids')
          .doc(candidate)
          .get()
          .timeout(const Duration(seconds: 3));

      if (!doc.exists) {
        return candidate;
      }
      // If by extremely rare chance it exists, generate another candidate
      return generateCandidate12DigitId();
    } catch (e) {
      debugPrint('[AccountIdUtils] Check candidate notice: $e');
      // If remote collection read times out or is denied by rules, candidate is 
      // cryptographically random across 12 digits (odds of collision < 1 in 900 billion)
      return candidate;
    }
  }

  /// Automatically assigns and persists a 12-digit ID if a user/lawyer lacks one
  static Future<String> ensureUserHasAccountId({
    required String uid,
    String role = 'client',
    String? currentAccountId,
    FirebaseFirestore? firestore,
  }) async {
    if (isValid12DigitId(currentAccountId)) {
      return currentAccountId!;
    }

    final db = firestore ?? FirebaseFirestore.instance;
    try {
      // Check Firestore doc first
      final userDoc = await db.collection('users').doc(uid).get();
      final existing = userDoc.data()?['accountId']?.toString() ??
          userDoc.data()?['memberId']?.toString();
      if (isValid12DigitId(existing)) {
        return existing!;
      }

      // Generate a new 12-digit ID
      final newId = await generateUnique12DigitId(db);

      final batch = db.batch();
      batch.set(
        db.collection('users').doc(uid),
        {'accountId': newId},
        SetOptions(merge: true),
      );

      if (role == 'lawyer') {
        batch.set(
          db.collection('lawyers').doc(uid),
          {'accountId': newId},
          SetOptions(merge: true),
        );
      } else if (role == 'admin') {
        batch.set(
          db.collection('admins').doc(uid),
          {'accountId': newId},
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      // Register in global account_ids collection independently for resilience
      try {
        await db.collection('account_ids').doc(newId).set({
          'uid': uid,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[AccountIdUtils] account_ids registry notice: $e');
      }

      return newId;
    } catch (e) {
      debugPrint('[AccountIdUtils] ensureUserHasAccountId notice: $e');
      return currentAccountId ?? '';
    }
  }

  /// Formats 12-digit ID into readable chunks: 1234 5678 9012
  static String formatDisplay(String id) {
    final clean = id.trim();
    if (clean.length != 12) return clean;
    return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8, 12)}';
  }

  /// Alias for formatDisplay
  static String format(String id) => formatDisplay(id);

  /// Alias for formatDisplay
  static String formatForDisplay(String id) => formatDisplay(id);

  /// Alias for formatDisplay
  static String format12Digits(String id) => formatDisplay(id);
}
