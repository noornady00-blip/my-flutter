// ==============================================================================
// 🗄️ FIRESTORE DATABASE SERVICE
// ==============================================================================
// Implements DatabaseContract with cloud synchronization, multi-tier caching,
// and atomic write operations for Mahameek data models.
// ==============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/lawyer.dart';
import '../data/models/user_model.dart';
import '../data/models/password_reset_model.dart';
import '../core/utils/phone_utils.dart';
import 'database_contract.dart';
import 'auth_service.dart';

/// Database service managing all Firestore collections and queries.
class FirestoreService implements DatabaseContract {
  final FirebaseFirestore? _dbInstance;
  FirebaseFirestore get _db => _dbInstance ?? FirebaseFirestore.instance;

  FirestoreService({FirebaseFirestore? firestore}) : _dbInstance = firestore;

  static const String _cachedApprovedLawyersKey = 'cached_approved_lawyers_v1';
  static List<LawyerModel>? inMemoryApprovedLawyers;

  // ===========================================================================
  // ⚡ OFFLINE CACHE MANAGEMENT
  // ===========================================================================

  /// Save approved lawyers to local cache. If list is empty, clears cache to invalidate deleted/rejected lawyers.
  @override
  Future<void> cacheApprovedLawyersLocally(List<LawyerModel> lawyers) async {
    inMemoryApprovedLawyers = lawyers;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (lawyers.isEmpty) {
        await prefs.remove(_cachedApprovedLawyersKey);
      } else {
        final listJson =
            lawyers.map((l) => jsonEncode(l.toJsonMap())).toList();
        await prefs.setStringList(_cachedApprovedLawyersKey, listJson);
      }
    } catch (e) {
      debugPrint('cacheApprovedLawyersLocally error: $e');
    }
  }

  /// Clears local cache explicitly
  @override
  Future<void> clearLocalLawyerCache() async {
    inMemoryApprovedLawyers = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedApprovedLawyersKey);
    } catch (e) {
      debugPrint('clearLocalLawyerCache error: $e');
    }
  }

  /// Get locally cached approved lawyers (works 100% offline with in-memory speed)
  @override
  Future<List<LawyerModel>> getCachedApprovedLawyers() async {
    if (inMemoryApprovedLawyers != null &&
        inMemoryApprovedLawyers!.isNotEmpty) {
      return inMemoryApprovedLawyers!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_cachedApprovedLawyersKey) ?? [];
      final result = listJson.map((item) {
        final map = jsonDecode(item) as Map<String, dynamic>;
        return LawyerModel.fromJsonMap(map);
      }).toList();
      if (result.isNotEmpty) {
        inMemoryApprovedLawyers = result;
      }
      return result;
    } catch (e) {
      debugPrint('getCachedApprovedLawyers error: $e');
      return [];
    }
  }

  // ===========================================================================
  // ⚖️ LAWYERS QUERIES & STREAMS
  // ===========================================================================

  /// Get approved lawyers by city with server-side query and immediate offline cache fallback
  @override
  Stream<List<LawyerModel>> getLawyersByCity(String city) async* {
    // 1. Instantly yield cached lawyers for 0ms offline display
    final cached = await getCachedApprovedLawyers();
    final filteredCached = cached
        .where((l) => city == 'جميع المدن' || l.city == city)
        .toList();
    if (filteredCached.isNotEmpty) {
      yield filteredCached;
    }

    // 2. Server-side indexed Firestore Query
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('lawyers')
          .where('status', isEqualTo: 'approved');

      if (city != 'جميع المدن') {
        query = query.where('city', isEqualTo: city);
      }

      await for (final snapshot in query.snapshots()) {
        final list = snapshot.docs
            .map((doc) => LawyerModel.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (city == 'جميع المدن') {
          // Sync whole cache
          await cacheApprovedLawyersLocally(list);
        }

        // Critical: If live result is empty (e.g. all lawyers in this city removed),
        // yield empty list directly and do NOT show stale cache!
        yield list;
      }
    } catch (e) {
      debugPrint('getLawyersByCity query error: $e');
      // If network fails, maintain offline cache if available
      if (filteredCached.isNotEmpty) {
        yield filteredCached;
      } else {
        yield [];
      }
    }
  }

  /// Get all approved lawyers with server-side query
  @override
  Stream<List<LawyerModel>> getApprovedLawyers() async* {
    final cached = await getCachedApprovedLawyers();
    if (cached.isNotEmpty) {
      yield cached;
    }

    try {
      final query = _db
          .collection('lawyers')
          .where('status', isEqualTo: 'approved');

      await for (final snapshot in query.snapshots()) {
        final list = snapshot.docs
            .map((doc) => LawyerModel.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        await cacheApprovedLawyersLocally(list);

        // If live list is empty, yield empty list directly
        yield list;
      }
    } catch (e) {
      debugPrint('getApprovedLawyers query error: $e');
      if (cached.isNotEmpty) {
        yield cached;
      } else {
        yield [];
      }
    }
  }

  /// Get recently approved lawyers (for admin dashboard)
  @override
  Stream<List<LawyerModel>> getRecentApprovedLawyers({int limit = 5}) {
    return _db
        .collection('lawyers')
        .where('status', isEqualTo: 'approved')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LawyerModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Get pending lawyer requests (for admin)
  @override
  Stream<List<LawyerModel>> getPendingLawyers() {
    return _db
        .collection('lawyers')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LawyerModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Get all lawyers (for admin) — excludes rejected/deleted
  @override
  Stream<List<LawyerModel>> getAllLawyers() {
    return _db.collection('lawyers').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LawyerModel.fromMap(doc.data(), doc.id))
          .where((l) => l.status != 'rejected')
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Approve / Activate a lawyer
  @override
  Future<void> approveLawyer(String uid) async {
    await _db.collection('lawyers').doc(uid).update({'status': 'approved'});
    await _db
        .collection('users')
        .doc(uid)
        .set({'status': 'approved'}, SetOptions(merge: true));
  }

  /// Suspend / Deactivate a lawyer
  @override
  Future<void> suspendLawyer(String uid) async {
    await _db.collection('lawyers').doc(uid).update({'status': 'suspended'});
    await _db
        .collection('users')
        .doc(uid)
        .set({'status': 'suspended'}, SetOptions(merge: true));
  }

  /// Activate a suspended lawyer back to approved
  @override
  Future<void> activateLawyer(String uid) async {
    await approveLawyer(uid);
  }

  /// Reject a lawyer — deletes lawyer and user documents completely from Firestore,
  /// and clears phone_directory lock so the lawyer can immediately register again.
  @override
  Future<void> rejectLawyer(String uid, [String? reason]) async {
    try {
      final lawyerDoc = await _db.collection('lawyers').doc(uid).get();
      final phone = lawyerDoc.data()?['phone']?.toString();
      final userDoc = await _db.collection('users').doc(uid).get();
      final userPhone = userDoc.data()?['phone']?.toString();
      final effectivePhone = phone ?? userPhone;

      final batch = _db.batch();

      // 1. Delete completely from lawyers, users, and lawyer_requests
      batch.delete(_db.collection('lawyers').doc(uid));
      batch.delete(_db.collection('users').doc(uid));
      batch.delete(_db.collection('lawyer_requests').doc(uid));

      // 2. Free up phone_directory
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        final unified = PhoneUtils.toUnifiedPhone(effectivePhone);
        batch.delete(_db.collection('phone_directory').doc(unified));
        final candidates = PhoneUtils.generatePhoneCandidates(effectivePhone);
        for (final cand in candidates) {
          batch.delete(_db.collection('phone_directory').doc(cand));
        }
      }

      await batch.commit();

      try {
        final dirSnap = await _db
            .collection('phone_directory')
            .where('uid', isEqualTo: uid)
            .get();
        for (final doc in dirSnap.docs) {
          await doc.reference.delete().catchError((_) {});
        }
      } catch (_) {}

      // Invalidate memory/local caches
      inMemoryApprovedLawyers = null;
    } catch (e) {
      debugPrint('[FirestoreService] rejectLawyer error: $e');
      rethrow;
    }
  }

  /// Delete lawyer (admin operation)
  @override
  Future<void> deleteLawyer(String uid) async {
    try {
      final lawyerDoc = await _db.collection('lawyers').doc(uid).get();
      final phone = lawyerDoc.data()?['phone']?.toString();
      final userDoc = await _db.collection('users').doc(uid).get();
      final userPhone = userDoc.data()?['phone']?.toString();
      final effectivePhone = phone ?? userPhone;

      final batch = _db.batch();
      batch.delete(_db.collection('lawyers').doc(uid));
      batch.delete(_db.collection('users').doc(uid));
      batch.delete(_db.collection('lawyer_requests').doc(uid));

      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        final unified = PhoneUtils.toUnifiedPhone(effectivePhone);
        batch.delete(_db.collection('phone_directory').doc(unified));
        final candidates = PhoneUtils.generatePhoneCandidates(effectivePhone);
        for (final cand in candidates) {
          batch.delete(_db.collection('phone_directory').doc(cand));
        }
      }

      await batch.commit();

      try {
        final dirSnap = await _db
            .collection('phone_directory')
            .where('uid', isEqualTo: uid)
            .get();
        for (final doc in dirSnap.docs) {
          await doc.reference.delete().catchError((_) {});
        }
      } catch (_) {}

      // Delete user account permanently from Firebase Authentication
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        try {
          await AuthService().deleteUserAuthAccount(
            phone: effectivePhone,
            role: 'lawyer',
            uid: uid,
          );
        } catch (authErr) {
          debugPrint('[FirestoreService] deleteUserAuthAccount notice: $authErr');
        }
      }

      inMemoryApprovedLawyers = null;
    } catch (e) {
      debugPrint('[FirestoreService] deleteLawyer error: $e');
      rethrow;
    }
  }

  /// Get a single lawyer
  @override
  Future<LawyerModel?> getLawyer(String uid) async {
    final doc = await _db.collection('lawyers').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return LawyerModel.fromMap(doc.data()!, doc.id);
  }

  /// Stream single lawyer live from Firestore
  @override
  Stream<LawyerModel?> streamLawyer(String uid) {
    return _db.collection('lawyers').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return LawyerModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Update lawyer profile details with atomic WriteBatch synchronization
  @override
  Future<bool> updateLawyerProfile({
    required String uid,
    String? name,
    String? phone,
    String? whatsapp,
    String? city,
    String? specialization,
    String? photoUrl,
    String? photoBase64,
  }) async {
    try {
      final Map<String, dynamic> lawyerUpdates = {};
      final Map<String, dynamic> userUpdates = {};

      if (name != null && name.trim().isNotEmpty) {
        lawyerUpdates['name'] = name.trim();
        userUpdates['name'] = name.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        lawyerUpdates['phone'] = phone.trim();
        userUpdates['phone'] = phone.trim();
      }
      if (whatsapp != null) lawyerUpdates['whatsapp'] = whatsapp.trim();
      if (city != null) lawyerUpdates['city'] = city.trim();
      if (specialization != null) {
        lawyerUpdates['specialization'] = specialization.trim();
      }

      if (photoUrl != null) {
        if (photoUrl.isEmpty) {
          lawyerUpdates['photoUrl'] = FieldValue.delete();
          userUpdates['photoUrl'] = FieldValue.delete();
        } else {
          lawyerUpdates['photoUrl'] = photoUrl;
          userUpdates['photoUrl'] = photoUrl;
        }
      }

      // Backward compatibility for base64
      if (photoBase64 != null) {
        if (photoBase64.isEmpty) {
          lawyerUpdates['photoBase64'] = FieldValue.delete();
          userUpdates['photoBase64'] = FieldValue.delete();
        } else {
          lawyerUpdates['photoBase64'] = photoBase64;
          userUpdates['photoBase64'] = photoBase64;
        }
      }

      if (lawyerUpdates.isEmpty && userUpdates.isEmpty) return true;

      // Atomically write both documents
      final batch = _db.batch();
      if (lawyerUpdates.isNotEmpty) {
        batch.set(_db.collection('lawyers').doc(uid), lawyerUpdates,
            SetOptions(merge: true));
      }
      if (userUpdates.isNotEmpty) {
        batch.set(_db.collection('users').doc(uid), userUpdates,
            SetOptions(merge: true));
      }
      await batch.commit();

      // Update local memory cache if present
      if (inMemoryApprovedLawyers != null) {
        final updatedList = inMemoryApprovedLawyers!.map((l) {
          if (l.uid == uid) {
            return l.copyWith(
              name: name ?? l.name,
              phone: phone ?? l.phone,
              whatsapp: whatsapp ?? l.whatsapp,
              city: city ?? l.city,
              specialization: specialization ?? l.specialization,
              photoUrl: (photoUrl != null && photoUrl.isEmpty)
                  ? null
                  : (photoUrl ?? l.photoUrl),
              photoBase64: (photoBase64 != null && photoBase64.isEmpty)
                  ? null
                  : (photoBase64 ?? l.photoBase64),
            );
          }
          return l;
        }).toList();
        await cacheApprovedLawyersLocally(updatedList);
      }

      return true;
    } catch (e) {
      debugPrint('updateLawyerProfile error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 👥 USERS & CLIENTS MANAGEMENT
  // ===========================================================================

  @override
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<List<UserModel>> getAllClients() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'client')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<void> suspendClient(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'suspended'});
  }

  @override
  Future<void> activateClient(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'active'});
  }

  @override
  Future<void> deleteClient(String uid) async {
    await deleteUser(uid);
  }

  @override
  Future<void> deleteUser(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final phone = userDoc.data()?['phone']?.toString();
      final lawyerDoc = await _db.collection('lawyers').doc(uid).get();
      final lawyerPhone = lawyerDoc.data()?['phone']?.toString();
      final effectivePhone = phone ?? lawyerPhone;

      final batch = _db.batch();
      batch.delete(_db.collection('users').doc(uid));
      batch.delete(_db.collection('lawyers').doc(uid));
      batch.delete(_db.collection('lawyer_requests').doc(uid));

      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        final unified = PhoneUtils.toUnifiedPhone(effectivePhone);
        batch.delete(_db.collection('phone_directory').doc(unified));
        final candidates = PhoneUtils.generatePhoneCandidates(effectivePhone);
        for (final cand in candidates) {
          batch.delete(_db.collection('phone_directory').doc(cand));
        }
      }

      await batch.commit();

      try {
        final dirSnap = await _db
            .collection('phone_directory')
            .where('uid', isEqualTo: uid)
            .get();
        for (final doc in dirSnap.docs) {
          await doc.reference.delete().catchError((_) {});
        }
      } catch (_) {}

      // Delete user account permanently from Firebase Authentication
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        try {
          await AuthService().deleteUserAuthAccount(
            phone: effectivePhone,
            role: 'client',
            uid: uid,
          );
        } catch (authErr) {
          debugPrint('[FirestoreService] deleteUserAuthAccount notice: $authErr');
        }
      }

      inMemoryApprovedLawyers = null;
    } catch (e) {
      debugPrint('[FirestoreService] deleteUser error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 🛡️ ADMIN MANAGEMENT
  // ===========================================================================

  @override
  Stream<List<UserModel>> getAllAdmins() {
    // Proactively ensure both primary admins are seeded in Firestore
    unawaited(ensurePrimaryAdminsSeeded());

    return _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .snapshots()
        .map((snapshot) {
      UserModel? primary1;
      UserModel? primary2;
      final List<UserModel> secondaryAdmins = [];
      final Set<String> seenSecondaryPhones = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final admin = UserModel.fromMap(data, doc.id);
        final rawPhone = admin.phone;

        if (PhoneUtils.isPrimaryAdmin1(rawPhone)) {
          // Keep only one primary 1 - prefer the standard doc or the one with complete data
          if (primary1 == null || doc.id == 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2') {
            primary1 = admin.copyWith(
              name: 'المشرف الأساسي (01146979833)',
              phone: '01146979833',
              accountId: admin.accountId.isNotEmpty ? admin.accountId : '5642 1902 3114',
              isPrimary: true,
              status: 'active',
            );
          }
        } else if (PhoneUtils.isPrimaryAdmin2(rawPhone)) {
          // Keep only one primary 2
          if (primary2 == null || doc.id == 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2') {
            primary2 = admin.copyWith(
              name: 'صاحب التطبيق',
              phone: '+249912209596',
              accountId: admin.accountId.isNotEmpty ? admin.accountId : '5642 1902 3115',
              isPrimary: true,
              status: 'active',
            );
          }
        } else {
          final cleanDigits = PhoneUtils.extractLocalSudanDigits(rawPhone);
          final key = cleanDigits.isNotEmpty ? cleanDigits : rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
          if (key.isNotEmpty && !seenSecondaryPhones.contains(key)) {
            seenSecondaryPhones.add(key);
            secondaryAdmins.add(admin);
          }
        }
      }

      // Ensure Admin 1: 01146979833 is always present
      primary1 ??= UserModel(
        uid: 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2',
        name: 'المشرف الأساسي (01146979833)',
        phone: '01146979833',
        role: 'admin',
        status: 'active',
        accountId: '5642 1902 3114',
        isPrimary: true,
        createdAt: DateTime(2026, 1, 1),
      );

      // Ensure Admin 2: 91 220 9596 (+249912209596) is always present
      primary2 ??= UserModel(
        uid: 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2',
        name: 'صاحب التطبيق',
        phone: '+249912209596',
        role: 'admin',
        status: 'active',
        accountId: '5642 1902 3115',
        isPrimary: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final List<UserModel> list = [primary1, primary2];
      list.addAll(secondaryAdmins);
      return list;
    });
  }

  static bool _adminsSeeded = false;

  @override
  Future<void> ensurePrimaryAdminsSeeded() async {
    if (_adminsSeeded) return;
    _adminsSeeded = true;
    try {
      // 1. Admin 1: 01146979833
      const admin1Uid = 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2';
      final admin1Data = {
        'uid': admin1Uid,
        'name': 'المشرف الأساسي (01146979833)',
        'phone': '01146979833',
        'role': 'admin',
        'status': 'active',
        'accountId': '5642 1902 3114',
        'email': 'admin_01146979833@mahameek.admin.com',
        'isPrimary': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('users').doc(admin1Uid).set(admin1Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('admins').doc(admin1Uid).set(admin1Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('phone_directory').doc('01146979833').set(admin1Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('phone_directory').doc('1146979833').set(admin1Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('phone_directory').doc('+2491146979833').set(admin1Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('account_ids').doc('564219023114').set({
        'uid': admin1Uid,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});

      // 2. Admin 2: 91 220 9596 (+249912209596 / 0912209596)
      const admin2Uid = 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2';
      final admin2Data = {
        'uid': admin2Uid,
        'name': 'صاحب التطبيق',
        'phone': '+249912209596',
        'role': 'admin',
        'status': 'active',
        'accountId': '5642 1902 3115',
        'email': 'admin_912209596@mahameek.admin.com',
        'isPrimary': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('users').doc(admin2Uid).set(admin2Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('admins').doc(admin2Uid).set(admin2Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('phone_directory').doc('0912209596').set(admin2Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('phone_directory').doc('912209596').set(admin2Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('phone_directory').doc('+249912209596').set(admin2Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('phone_directory').doc('249912209596').set(admin2Data, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('account_ids').doc('564219023115').set({
        'uid': admin2Uid,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});

      // 3. Clean up any duplicate orphaned admin documents in Firestore
      try {
        final existingAdminsSnap = await _db
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        for (final doc in existingAdminsSnap.docs) {
          final phone = doc.data()['phone']?.toString() ?? '';
          if (PhoneUtils.isPrimaryAdmin1(phone) && doc.id != admin1Uid) {
            await _db.collection('users').doc(doc.id).delete().catchError((_) {});
            await _db.collection('admins').doc(doc.id).delete().catchError((_) {});
          }
          if (PhoneUtils.isPrimaryAdmin2(phone) && doc.id != admin2Uid) {
            await _db.collection('users').doc(doc.id).delete().catchError((_) {});
            await _db.collection('admins').doc(doc.id).delete().catchError((_) {});
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('ensurePrimaryAdminsSeeded notice: $e');
    }
  }

  @override
  Future<void> suspendAdmin(String uid) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {'status': 'suspended'});
    batch.update(_db.collection('admins').doc(uid), {'status': 'suspended'});
    await batch.commit();
  }

  @override
  Future<void> activateAdmin(String uid) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {'status': 'active'});
    batch.update(_db.collection('admins').doc(uid), {'status': 'active'});
    await batch.commit();
  }

  @override
  Future<void> deleteAdmin(String uid) async {
    try {
      // 1. Fetch admin data from both admins and users collections BEFORE deleting
      DocumentSnapshot<Map<String, dynamic>>? adminDoc;
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      try {
        adminDoc = await _db.collection('admins').doc(uid).get();
      } catch (_) {}
      try {
        userDoc = await _db.collection('users').doc(uid).get();
      } catch (_) {}

      final data = <String, dynamic>{
        ...?adminDoc?.data(),
        ...?userDoc?.data(),
      };

      final phone = data['phone']?.toString() ?? data['rawPhone']?.toString() ?? '';
      final email = data['email']?.toString() ?? '';
      final accountId = data['accountId']?.toString() ?? '';
      final resetPw = data['adminResetPassword']?.toString();

      // 2. PURGE FROM FIREBASE AUTHENTICATION (Using isolated secondary session)
      try {
        await AuthService().deleteUserAuthAccount(
          phone: phone,
          role: 'admin',
          uid: uid,
          password: resetPw,
          userEmail: email.isNotEmpty ? email : null,
        );
      } catch (authErr) {
        debugPrint('[FirestoreService] deleteAdmin auth purge notice: $authErr');
      }

      // 3. PURGE FROM FIRESTORE
      final batch = _db.batch();
      batch.delete(_db.collection('users').doc(uid));
      batch.delete(_db.collection('admins').doc(uid));
      batch.delete(_db.collection('admin_fcm_tokens').doc(uid));

      if (accountId.isNotEmpty) {
        batch.delete(_db.collection('account_ids').doc(accountId));
        batch.delete(_db.collection('account_ids').doc(accountId.replaceAll(' ', '')));
      }

      final phoneCandidates = <String>{};
      if (phone.isNotEmpty) {
        phoneCandidates.addAll(PhoneUtils.generatePhoneCandidates(phone));
        final unified = PhoneUtils.toUnifiedPhone(phone);
        phoneCandidates.add(unified);
        final cleanDigits = PhoneUtils.extractLocalSudanDigits(phone);
        if (cleanDigits.isNotEmpty) phoneCandidates.add(cleanDigits);
        final rawDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (rawDigits.isNotEmpty) phoneCandidates.add(rawDigits);
      }

      for (final cand in phoneCandidates) {
        if (cand.isNotEmpty) {
          batch.delete(_db.collection('phone_directory').doc(cand));
        }
      }

      // Also clean up any phone_directory docs referencing this uid
      try {
        final dirSnap = await _db
            .collection('phone_directory')
            .where('uid', isEqualTo: uid)
            .get();
        for (final doc in dirSnap.docs) {
          batch.delete(doc.reference);
        }
      } catch (_) {}

      await batch.commit();
      debugPrint('✅ [FirestoreService] Successfully deleted admin $uid from Firestore and Firebase Auth');
    } catch (e) {
      debugPrint('[FirestoreService] deleteAdmin error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 🔑 PASSWORD RESET TICKETS
  // ===========================================================================

  /// Submit a password reset ticket to Firestore
  @override
  Future<String> submitPasswordResetTicket({
    required String phone,
    required String source, // 'whatsapp' | 'in_app'
    String? notes,
  }) async {
    try {
      final res = await AuthService().submitPasswordResetTicket(
        phone: phone,
        source: source,
        notes: notes,
      );
      if (res['success'] == true) {
        return res['ticketId']?.toString() ?? '';
      } else {
        throw Exception(res['error'] ?? 'تعذر إرسال الطلب');
      }
    } catch (e) {
      debugPrint('submitPasswordResetTicket error: $e');
      rethrow;
    }
  }

  /// Stream all pending password reset requests for admin dashboard
  @override
  Stream<List<PasswordResetModel>> getPasswordResetsStream() {
    return _db
        .collection('password_resets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) {
              final status = doc.data()['status']?.toString();
              return status == null ||
                  (status != 'resolved' && status != 'rejected');
            })
            .map((doc) => PasswordResetModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Delete a password reset ticket permanently from Firestore
  @override
  Future<void> deletePasswordResetTicket(String ticketId) async {
    try {
      await _db.collection('password_resets').doc(ticketId).delete();
    } catch (e) {
      debugPrint('deletePasswordResetTicket error: $e');
    }
  }

  /// Resolve a password reset ticket by deleting it from pending requests
  @override
  Future<void> resolvePasswordResetTicket({
    required String ticketId,
    required String tempPassword,
  }) async {
    await deletePasswordResetTicket(ticketId);
  }

  /// Reject or dismiss a password reset ticket by deleting it permanently
  @override
  Future<void> rejectPasswordResetTicket(String ticketId) async {
    await deletePasswordResetTicket(ticketId);
  }

  // ===========================================================================
  // 📊 STATS VIA CLOUD AGGREGATION
  // ===========================================================================

  /// Uses Firestore Aggregate count() queries to compute stats with 0 document downloads
  @override
  Future<Map<String, int>> getStats() async {
    try {
      final results = await Future.wait([
        _db.collection('lawyers').count().get(),
        _db.collection('lawyers').where('status', isEqualTo: 'approved').count().get(),
        _db.collection('lawyers').where('status', isEqualTo: 'pending').count().get(),
        _db.collection('users').where('role', isEqualTo: 'client').count().get(),
      ]);

      return {
        'totalLawyers': results[0].count ?? 0,
        'approvedLawyers': results[1].count ?? 0,
        'pendingLawyers': results[2].count ?? 0,
        'totalClients': results[3].count ?? 0,
      };
    } catch (e) {
      debugPrint('getStats aggregate error: $e');
      return {
        'totalLawyers': 0,
        'approvedLawyers': 0,
        'pendingLawyers': 0,
        'totalClients': 0,
      };
    }
  }
}
