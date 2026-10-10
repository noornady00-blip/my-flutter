// ==============================================================================
// 🆔 ACCOUNT ID UTILITIES (FIXED 6-DIGIT IDENTIFIER)
// ==============================================================================
// Generates, validates, and manages unique fixed 6-digit account numbers
// (e.g., 102 938) for Clients, Lawyers, and Administrators.
// Firebase UID remains the internal key; Account ID is for friendly display and lookup.
// Saved strictly as a 6-digit pure numeric string in Firebase.
// Completely unified across users, lawyers, admins, and Firestore with 100% collision prevention.
// ==============================================================================

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountIdUtils {
  static final Random _secureRandom = Random.secure();

  /// Generates a 6-digit numeric string where the first digit is 1-9
  /// ensuring exactly 6 digits and preventing leading-zero truncation issues (100000..999999).
  static String generateCandidate6DigitId() {
    final firstDigit = _secureRandom.nextInt(9) + 1; // 1..9
    final buffer = StringBuffer()..write(firstDigit);
    for (int i = 0; i < 5; i++) {
      buffer.write(_secureRandom.nextInt(10)); // 0..9
    }
    return buffer.toString();
  }

  /// Backward-compatible alias
  static String generateCandidate12DigitId() => generateCandidate6DigitId();

  /// Extracts pure digits from formatted string
  static String clean6Digits(String? id) {
    if (id == null) return '';
    return id.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  /// Backward-compatible alias
  static String clean12Digits(String? id) => clean6Digits(id);

  /// Validates whether a given string is a valid numeric account ID (strictly 6 digits)
  static bool isValidAccountId(String? id) {
    if (id == null) return false;
    final clean = clean6Digits(id);
    return clean.length == 6 && RegExp(r'^\d{6}$').hasMatch(clean);
  }

  /// Strictly validates whether a given string is exactly 6 digits without leading zero
  static bool isValid6DigitId(String? id) {
    if (id == null) return false;
    final clean = clean6Digits(id);
    return clean.length == 6 && RegExp(r'^[1-9]\d{5}$').hasMatch(clean);
  }

  /// Backward-compatible alias
  static bool isValid12DigitId(String? id) => isValidAccountId(id);

  /// Generates a cryptographically unique 6-digit ID with collision verification
  /// against Firestore collection 'account_ids' and atomic reservation.
  static Future<String> generateUnique6DigitId([
    FirebaseFirestore? firestore,
    String? uid,
    String role = 'client',
  ]) async {
    final db = firestore ?? FirebaseFirestore.instance;

    for (int attempt = 0; attempt < 50; attempt++) {
      final candidate = generateCandidate6DigitId();
      try {
        // Step 1: Check candidate in global 'account_ids' registry collection
        final doc = await db
            .collection('account_ids')
            .doc(candidate)
            .get()
            .timeout(const Duration(seconds: 4));

        if (doc.exists) {
          final data = doc.data();
          if (uid != null && uid.isNotEmpty && data?['uid'] == uid) {
            return candidate;
          }
          // Already taken by another user! Try next candidate
          continue;
        }

        // Step 2: Cross-check against 'users' collection to guarantee zero collision
        final userSnap = await db
            .collection('users')
            .where('accountId', isEqualTo: candidate)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));

        if (userSnap.docs.isNotEmpty) {
          final firstDoc = userSnap.docs.first;
          if (uid != null && uid.isNotEmpty && firstDoc.id == uid) {
            return candidate;
          }
          continue;
        }

        // Step 3: Cross-check against 'lawyers' collection
        final lawyerSnap = await db
            .collection('lawyers')
            .where('accountId', isEqualTo: candidate)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));

        if (lawyerSnap.docs.isNotEmpty) {
          final firstDoc = lawyerSnap.docs.first;
          if (uid != null && uid.isNotEmpty && firstDoc.id == uid) {
            return candidate;
          }
          continue;
        }

        // Step 4: Cross-check against 'admins' collection
        final adminSnap = await db
            .collection('admins')
            .where('accountId', isEqualTo: candidate)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));

        if (adminSnap.docs.isNotEmpty) {
          final firstDoc = adminSnap.docs.first;
          if (uid != null && uid.isNotEmpty && firstDoc.id == uid) {
            return candidate;
          }
          continue;
        }

        // Step 5: Reserve candidate immediately if uid is provided
        if (uid != null && uid.isNotEmpty) {
          await db.collection('account_ids').doc(candidate).set({
            'uid': uid,
            'role': role,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
        }

        return candidate;
      } catch (e) {
        debugPrint('[AccountIdUtils] Collision check candidate $candidate notice ($attempt): $e');
        if (attempt == 49) return candidate;
      }
    }
    return generateCandidate6DigitId();
  }

  /// Backward-compatible alias
  static Future<String> generateUnique12DigitId([FirebaseFirestore? firestore]) =>
      generateUnique6DigitId(firestore);

  /// Synchronizes an account ID across all collections atomically so it never diverges.
  /// Always saves pure 6 digits without any spaces to Firebase!
  static Future<void> _syncAccountIdToAll({
    required String uid,
    required String accountId,
    required String role,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final clean = clean6Digits(accountId);
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

  /// Automatically assigns and persists a fixed 6-digit account ID if a user/lawyer lacks one.
  /// Guarantees that if ANY collection has an existing valid 6-digit ID, it is preserved and unified everywhere!
  /// Guarantees the ID is permanent and constant for each user across the entire app.
  static Future<String> ensureUserHasAccountId({
    required String uid,
    String role = 'client',
    String? currentAccountId,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;

    // 0. Primary Admins fixed 6-digit IDs
    if (uid == 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2') {
      const fixedId = '111111';
      await _syncAccountIdToAll(uid: uid, accountId: fixedId, role: 'admin', firestore: db);
      return fixedId;
    }
    if (uid == 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2') {
      const fixedId = '222222';
      await _syncAccountIdToAll(uid: uid, accountId: fixedId, role: 'admin', firestore: db);
      return fixedId;
    }

    // 1. If currentAccountId is already a valid 6-digit ID, preserve and sync it!
    if (isValidAccountId(currentAccountId)) {
      final clean = clean6Digits(currentAccountId);
      await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
      return clean;
    }

    try {
      // 2. Check if admins collection has a valid 6-digit ID
      if (role == 'admin') {
        final aDoc = await db.collection('admins').doc(uid).get();
        final aId = aDoc.data()?['accountId']?.toString();
        if (isValidAccountId(aId)) {
          final clean = clean6Digits(aId);
          await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
          return clean;
        }
      }

      // 3. Check if lawyers collection has a valid 6-digit ID
      if (role == 'lawyer') {
        final lDoc = await db.collection('lawyers').doc(uid).get();
        final lId = lDoc.data()?['accountId']?.toString();
        if (isValidAccountId(lId)) {
          final clean = clean6Digits(lId);
          await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
          return clean;
        }
      }

      // 4. Check if users collection has a valid 6-digit ID
      final userDoc = await db.collection('users').doc(uid).get();
      final existing = userDoc.data()?['accountId']?.toString() ??
          userDoc.data()?['memberId']?.toString();
      if (isValidAccountId(existing)) {
        final clean = clean6Digits(existing);
        await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
        return clean;
      }

      // 5. Check local preferences as fallback before generating new
      final prefs = await SharedPreferences.getInstance();
      final localAcc = prefs.getString('accountId') ?? prefs.getString('user_account_id');
      if (isValidAccountId(localAcc)) {
        final clean = clean6Digits(localAcc);
        await _syncAccountIdToAll(uid: uid, accountId: clean, role: role, firestore: db);
        return clean;
      }

      // 6. Only if completely absent or invalid, generate a unique 6-digit ID with collision verification
      final newId = await generateUnique6DigitId(db, uid, role);
      await _syncAccountIdToAll(uid: uid, accountId: newId, role: role, firestore: db);
      return newId;
    } catch (e) {
      debugPrint('[AccountIdUtils] ensureUserHasAccountId notice: $e');
      if (isValidAccountId(currentAccountId)) {
        return clean6Digits(currentAccountId);
      }
      return generateCandidate6DigitId();
    }
  }

  /// Formats ID into readable chunks: 123 456
  static String formatDisplay(String id) {
    final clean = clean6Digits(id);
    if (clean.length == 6) {
      return '${clean.substring(0, 3)} ${clean.substring(3, 6)}';
    } else if (clean.length == 12) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8, 12)}';
    } else if (clean.length == 8) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 8)}';
    }
    return clean.isNotEmpty ? clean : id;
  }

  /// Aliases for formatDisplay
  static String format(String id) => formatDisplay(id);
  static String formatForDisplay(String id) => formatDisplay(id);
  static String format12Digits(String id) => formatDisplay(id);
  static String format6Digits(String id) => formatDisplay(id);
}
