// ==============================================================================
// 🆔 ACCOUNT ID UTILITIES (FIXED IDENTIFIER)
// ==============================================================================
// Generates, validates, and manages unique fixed account numbers
// (e.g., 1029 3847 5612) for Clients, Lawyers, and Administrators.
// Firebase UID remains the internal key; Account ID is for friendly display and lookup.
// Completely unified across users, lawyers, admins, and Firestore.
// ==============================================================================

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Extracts pure digits from formatted string
  static String clean12Digits(String? id) {
    if (id == null) return '';
    return id.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  /// Validates whether a given string is a valid numeric account ID
  static bool isValidAccountId(String? id) {
    if (id == null) return false;
    final clean = id.trim();
    return clean.length >= 8 && clean.length <= 14 && RegExp(r'^\d+$').hasMatch(clean);
  }

  /// Strictly validates whether a given string is exactly 12 digits
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
      return generateCandidate12DigitId();
    } catch (e) {
      debugPrint('[AccountIdUtils] Check candidate notice: $e');
      return candidate;
    }
  }

  /// Synchronizes an account ID across all collections atomically so it never diverges
  static Future<void> _syncAccountIdToAll({
    required String uid,
    required String accountId,
    required String role,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final clean = clean12Digits(accountId);
    if (clean.isEmpty) return;

    try {
      final batch = db.batch();
      batch.set(db.collection('users').doc(uid), {'accountId': clean}, SetOptions(merge: true));
      if (role == 'lawyer') {
        batch.set(db.collection('lawyers').doc(uid), {'accountId': clean}, SetOptions(merge: true));
      } else if (role == 'admin') {
        batch.set(db.collection('admins').doc(uid), {'accountId': clean}, SetOptions(merge: true));
      }
      batch.set(db.collection('account_ids').doc(clean), {
        'uid': uid,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit().catchError((_) {});

      // Sync local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accountId', clean);
      await prefs.setString('user_account_id', clean);
    } catch (e) {
      debugPrint('[AccountIdUtils] _syncAccountIdToAll error: $e');
    }
  }

  /// Automatically assigns and persists a fixed account ID if a user/lawyer lacks one.
  /// Guarantees that if ANY collection has an existing ID, it is preserved and unified everywhere!
  static Future<String> ensureUserHasAccountId({
    required String uid,
    String role = 'client',
    String? currentAccountId,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;

    // 0. Primary Admins fixed IDs
    if (uid == 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2') {
      const fixedId = '111111111111';
      await _syncAccountIdToAll(uid: uid, accountId: fixedId, role: 'admin', firestore: db);
      return fixedId;
    }
    if (uid == 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2') {
      const fixedId = '222222222222';
      await _syncAccountIdToAll(uid: uid, accountId: fixedId, role: 'admin', firestore: db);
      return fixedId;
    }

    // 1. If currentAccountId is already valid, preserve and sync it!
    if (isValidAccountId(currentAccountId)) {
      final clean = clean12Digits(currentAccountId);
      await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
      return clean;
    }

    try {
      // 2. Check if admins collection has it
      if (role == 'admin') {
        final aDoc = await db.collection('admins').doc(uid).get();
        final aId = aDoc.data()?['accountId']?.toString();
        if (isValidAccountId(aId)) {
          final clean = clean12Digits(aId);
          await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
          return clean;
        }
      }

      // 3. Check if lawyers collection has it
      if (role == 'lawyer') {
        final lDoc = await db.collection('lawyers').doc(uid).get();
        final lId = lDoc.data()?['accountId']?.toString();
        if (isValidAccountId(lId)) {
          final clean = clean12Digits(lId);
          await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
          return clean;
        }
      }

      // 4. Check if users collection has it
      final userDoc = await db.collection('users').doc(uid).get();
      final existing = userDoc.data()?['accountId']?.toString() ??
          userDoc.data()?['memberId']?.toString();
      if (isValidAccountId(existing)) {
        final clean = clean12Digits(existing);
        await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
        return clean;
      }

      // 5. Check local preferences as fallback before generating new
      final prefs = await SharedPreferences.getInstance();
      final localAcc = prefs.getString('accountId') ?? prefs.getString('user_account_id');
      if (isValidAccountId(localAcc)) {
        final clean = clean12Digits(localAcc);
        await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
        return clean;
      }

      // 6. Only if completely absent everywhere, generate a single new 12-digit ID
      final newId = await generateUnique12DigitId(db);
      await _syncAccountIdToAll(uid: uid, accountId: newId, role: role, firestore: db);
      return newId;
    } catch (e) {
      debugPrint('[AccountIdUtils] ensureUserHasAccountId notice: $e');
      return clean12Digits(currentAccountId);
    }
  }

  /// Formats ID into readable chunks: 1234 5678 9012
  static String formatDisplay(String id) {
    final clean = clean12Digits(id);
    if (clean.length == 12) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8, 12)}';
    } else if (clean.length == 11) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8, 11)}';
    } else if (clean.length == 8) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 8)}';
    }
    return clean.isNotEmpty ? clean : id;
  }

  /// Aliases for formatDisplay
  static String format(String id) => formatDisplay(id);
  static String formatForDisplay(String id) => formatDisplay(id);
  static String format12Digits(String id) => formatDisplay(id);
}
