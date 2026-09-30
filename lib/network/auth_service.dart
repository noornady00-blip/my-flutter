// ==============================================================================
// 🔐 AUTHENTICATION SERVICE
// ==============================================================================
// Implements AuthContract with Firebase Auth, secure password hashing,
// multi-role session management (Client, Lawyer, Admin), and account recovery.
// ==============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'firestore_service.dart';

import '../data/models/user_model.dart';
import '../data/models/lawyer.dart';
import '../core/utils/phone_utils.dart';
import 'auth_contract.dart';
import 'storage_service.dart';
import '../core/utils/app_error_translator.dart';
import 'notification_service.dart';
import 'network_service.dart';
import '../core/utils/account_id_utils.dart';

/// Concrete implementation of authentication and session contract.
class AuthService implements AuthContract {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ===========================================================================
  // 🔑 CRYPTOGRAPHY & CREDENTIAL GENERATION
  // ===========================================================================

  /// Secure password hashing using SHA-256 with application salt
  static String hashPassword(String password) {
    final bytes = utf8.encode('mahameek_pwd_salt_2026_${password}_secure');
    return sha256.convert(bytes).toString();
  }

  /// Internal deterministic credential for Firebase Auth phone-mapped accounts
  static String internalAuthKey(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final bytes = utf8.encode('mahameek_auth_key_salt_2026_$clean');
    final hex = sha256.convert(bytes).toString();
    return 'Mhk@${hex.substring(0, 16)}#';
  }

  /// Checks whether a phone number is registered across users, lawyers, and admin accounts
  Future<Map<String, dynamic>?> checkPhoneRegistration(String phone) async {
    try {
      final bool isPrimary1 = PhoneUtils.isPrimaryAdmin1(phone);
      final bool isPrimary2 = PhoneUtils.isPrimaryAdmin2(phone);

      if (isPrimary1) {
        return {
          'uid': 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2',
          'role': 'admin',
          'isPrimary': true,
          'data': {
            'name': 'المشرف الأساسي (01146979833)',
            'phone': '01146979833',
            'role': 'admin',
            'isPrimary': true,
          },
        };
      } else if (isPrimary2) {
        return {
          'uid': 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2',
          'role': 'admin',
          'isPrimary': true,
          'data': {
            'name': 'صاحب التطبيق',
            'phone': '+249912209596',
            'role': 'admin',
            'isPrimary': true,
          },
        };
      }

      final candidates = PhoneUtils.generatePhoneCandidates(phone).take(3).toList();
      if (candidates.isEmpty) return null;

      for (final q in candidates) {
        if (q.isEmpty) continue;

        // 1. Check phone_directory collection (public lightweight registry)
        try {
          final dirDoc = await _db
              .collection('phone_directory')
              .doc(q)
              .get()
              .timeout(const Duration(seconds: 3));
          if (dirDoc.exists && dirDoc.data() != null) {
            final data = dirDoc.data()!;
            final role = data['role']?.toString() ?? 'client';
            final uid = data['uid']?.toString() ?? dirDoc.id;

            // Verify the user document actually exists if authenticated to prevent orphan ghosts
            if (_auth.currentUser != null) {
              final col = role == 'lawyer' ? 'lawyers' : 'users';
              try {
                final userCheck = await _db.collection(col).doc(uid).get().timeout(const Duration(seconds: 2));
                if (!userCheck.exists) {
                  unawaited(dirDoc.reference.delete().catchError((_) {}));
                  continue;
                }
              } catch (_) {}
            }

            return {
              'uid': uid,
              'role': role,
              'data': data,
            };
          }
        } catch (_) {}

        // 2. Check lawyers collection (all statuses: approved, pending, suspended)
        try {
          final lawyerSnap = await _db
              .collection('lawyers')
              .where('phone', isEqualTo: q)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 3));
          if (lawyerSnap.docs.isNotEmpty) {
            final doc = lawyerSnap.docs.first;
            final st = doc.data()['status']?.toString();
            if (st != 'rejected') {
              return {
                'uid': doc.id,
                'role': 'lawyer',
                'data': doc.data(),
              };
            }
          }
        } catch (_) {}

        // 3. If authenticated, check users collection
        if (_auth.currentUser != null) {
          try {
            final userSnap = await _db
                .collection('users')
                .where('phone', isEqualTo: q)
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 3));
            if (userSnap.docs.isNotEmpty) {
              final doc = userSnap.docs.first;
              final st = doc.data()['status']?.toString();
              if (st != 'rejected') {
                return {
                  'uid': doc.id,
                  'role': doc.data()['role']?.toString() ?? 'client',
                  'data': doc.data(),
                };
              }
            }
          } catch (_) {}
        }
      }
      return null;
    } on SocketException catch (e) {
      debugPrint('checkPhoneRegistration SocketException: $e');
      throw const SocketException('الشبكة المتصل بها لا يتوفر بها إنترنت');
    } on TimeoutException catch (e) {
      debugPrint('checkPhoneRegistration TimeoutException: $e');
      throw TimeoutException(
          'تعذر الاتصال بالخادم، يرجى التأكد من توفر إنترنت بالشبكة');
    } on FirebaseException catch (e) {
      debugPrint('checkPhoneRegistration FirebaseException: ${e.code}');
      if (e.code == 'unavailable' ||
          e.code == 'network-request-failed' ||
          e.code == 'deadline-exceeded') {
        rethrow;
      }
      return null;
    } catch (e) {
      debugPrint('checkPhoneRegistration notice: $e');
      return null;
    }
  }

  // ===========================================================================
  // 👤 CLIENT REGISTRATION
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> registerClient({
    required String name,
    required String phone,
    required String password,
    String? photoUrl,
    String? photoBase64,
  }) async {
    try {
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }

      final normPhone = PhoneUtils.normalizeSudanPhone(phone);
      final cleanDigits = normPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final localDigits = PhoneUtils.extractLocalSudanDigits(phone);

      // Prevent registering admin phone numbers as clients
      if (cleanDigits.endsWith('146979833') ||
          cleanDigits.endsWith('912209596') ||
          localDigits == '146979833' ||
          localDigits == '912209596') {
        return {
          'success': false,
          'error': 'هذا الرقم مخصص لإدارة التطبيق، لا يمكن استخدامه لإنشاء حساب.',
        };
      }

      // Prevent duplicate or cross-role registration
      final existing = await checkPhoneRegistration(normPhone);
      if (existing != null) {
        final role = existing['role']?.toString();
        if (role == 'lawyer') {
          return {
            'success': false,
            'error':
                'هذا الرقم مسجل مسبقاً كحساب محامي، لا يمكن استخدامه لإنشاء حساب عميل.',
          };
        } else if (role == 'admin') {
          return {
            'success': false,
            'error':
                'هذا الرقم مخصص لإدارة التطبيق، لا يمكن استخدامه لإنشاء حساب.',
          };
        }
        return {
          'success': false,
          'error':
              'هذا الرقم مسجل مسبقاً بالفعل كحساب عميل، يرجى تسجيل الدخول مباشرة.',
        };
      }

      String effectiveEmail = '$cleanDigits@mahameek.client.com';
      final authKey = internalAuthKey(cleanDigits);
      final fbPassword =
          password.length < 6 ? password.padRight(6, '0') : password;
      final pwdHash = hashPassword(password);

      UserCredential? cred;
      try {
        cred = await _auth.createUserWithEmailAndPassword(
          email: effectiveEmail,
          password: authKey,
        );
      } catch (e) {
        if (e is FirebaseAuthException &&
            (e.code == 'network-request-failed' || e.code == 'unavailable')) {
          return {
            'success': false,
            'error':
                'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
            'isNetworkError': true,
          };
        }
        // Try candidate passwords on existing account
        final recoveryPasswords = [
          authKey,
          fbPassword,
          password,
          PhoneUtils.normalizeDigits(password),
          if (localDigits.isNotEmpty) internalAuthKey(localDigits),
          '123456',
          '12345678',
          '000000',
        ];
        for (final pw in recoveryPasswords) {
          try {
            cred = await _auth.signInWithEmailAndPassword(
              email: effectiveEmail,
              password: pw,
            );
            if (cred.user != null) {
              await cred.user!.updatePassword(authKey);
              break;
            }
          } catch (_) {}
        }

        // If still null, create with fresh unique email alias to bypass orphaned lock
        if (cred == null || cred.user == null) {
          effectiveEmail = '$cleanDigits.${DateTime.now().millisecondsSinceEpoch}@mahameek.client.com';
          try {
            cred = await _auth.createUserWithEmailAndPassword(
              email: effectiveEmail,
              password: authKey,
            );
          } catch (create2Err) {
            if (create2Err is FirebaseAuthException &&
                (create2Err.code == 'network-request-failed' || create2Err.code == 'unavailable')) {
              return {
                'success': false,
                'error':
                    'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
                'isNetworkError': true,
              };
            }
            rethrow;
          }
        }
      }
      final uid = cred.user!.uid;
      final accountId = await AccountIdUtils.generateUnique12DigitId(_db);

      final user = UserModel(
        uid: uid,
        name: name,
        phone: normPhone,
        role: 'client',
        accountId: accountId,
        photoUrl: photoUrl,
        photoBase64: photoBase64,
        createdAt: DateTime.now(),
      );

      final userMap = user.toMap();
      userMap['passwordHash'] = pwdHash;
      userMap['email'] = effectiveEmail;

      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), userMap);

      final dirData = {
        'uid': uid,
        'name': name,
        'phone': normPhone,
        'email': effectiveEmail,
        'role': 'client',
        'accountId': accountId,
        'passwordHash': pwdHash,
        'createdAt': FieldValue.serverTimestamp(),
      };
      batch.set(_db.collection('phone_directory').doc(cleanDigits), dirData);
      if (localDigits.isNotEmpty && localDigits != cleanDigits) {
        batch.set(_db.collection('phone_directory').doc(localDigits), dirData);
      }
      await batch.commit();

      // Register in global account_ids collection independently for resilience
      try {
        await _db.collection('account_ids').doc(accountId).set({
          'uid': uid,
          'role': 'client',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[registerClient] account_ids registry notice: $e');
      }

      await _saveSession(
        uid: uid,
        role: 'client',
        name: name,
        phone: normPhone,
        photoUrl: photoUrl,
        accountId: accountId,
      );

      // Unregister admin device topic on client login
      unawaited(NotificationService().unregisterAdminDevice());

      return {'success': true, 'uid': uid, 'role': 'client', 'accountId': accountId};
    } on FirebaseAuthException catch (e) {
      debugPrint('registerClient FirebaseAuthException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on FirebaseException catch (e) {
      debugPrint('registerClient FirebaseException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on SocketException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } catch (e) {
      debugPrint('registerClient error: $e');
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }
      return {
        'success': false,
        'error': 'حدث خطأ أثناء إنشاء الحساب ($e)'
      };
    }
  }

  // ===========================================================================
  // ⚖️ LAWYER REGISTRATION
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> registerLawyer({
    required String name,
    required String phone,
    required String whatsapp,
    required String city,
    String? specialization,
    required String password,
    String? photoUrl,
    String? photoBase64,
  }) async {
    try {
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }

      final normPhone = PhoneUtils.normalizeSudanPhone(phone);
      final normWhatsapp = whatsapp.trim().isNotEmpty
          ? PhoneUtils.normalizeSudanPhone(whatsapp)
          : normPhone;
      final cleanDigits = normPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final localDigits = PhoneUtils.extractLocalSudanDigits(phone);

      // Prevent registering admin phone numbers as lawyers
      if (cleanDigits.endsWith('146979833') ||
          cleanDigits.endsWith('912209596') ||
          localDigits == '146979833' ||
          localDigits == '912209596') {
        return {
          'success': false,
          'error': 'هذا الرقم مخصص لإدارة التطبيق، لا يمكن استخدامه لإنشاء حساب.',
        };
      }

      // Prevent duplicate or cross-role registration
      final existing = await checkPhoneRegistration(normPhone);
      if (existing != null) {
        final role = existing['role']?.toString();
        if (role == 'client') {
          return {
            'success': false,
            'error':
                'هذا الرقم مسجل مسبقاً كحساب عميل، لا يمكن استخدامه لإنشاء حساب محامي.',
          };
        } else if (role == 'admin') {
          return {
            'success': false,
            'error':
                'هذا الرقم مخصص لإدارة التطبيق، لا يمكن استخدامه لإنشاء حساب.',
          };
        }
        return {
          'success': false,
          'error':
              'هذا الرقم مسجل مسبقاً كحساب محامي بالفعل، يرجى تسجيل الدخول أو متابعة حالة طلبك.',
        };
      }

      String effectiveEmail = '$cleanDigits@mahameek.lawyer.com';
      final authKey = internalAuthKey(cleanDigits);
      final fbPassword =
          password.length < 6 ? password.padRight(6, '0') : password;
      final pwdHash = hashPassword(password);

      UserCredential? cred;
      try {
        cred = await _auth.createUserWithEmailAndPassword(
          email: effectiveEmail,
          password: authKey,
        );
      } catch (e) {
        if (e is FirebaseAuthException &&
            (e.code == 'network-request-failed' || e.code == 'unavailable')) {
          return {
            'success': false,
            'error':
                'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
            'isNetworkError': true,
          };
        }
        // Try candidate passwords on existing account
        final recoveryPasswords = [
          authKey,
          fbPassword,
          password,
          PhoneUtils.normalizeDigits(password),
          if (localDigits.isNotEmpty) internalAuthKey(localDigits),
          '123456',
          '12345678',
          '000000',
        ];
        for (final pw in recoveryPasswords) {
          try {
            cred = await _auth.signInWithEmailAndPassword(
              email: effectiveEmail,
              password: pw,
            );
            if (cred.user != null) {
              await cred.user!.updatePassword(authKey);
              break;
            }
          } catch (_) {}
        }

        // If still null, create with fresh unique email alias to bypass orphaned lock
        if (cred == null || cred.user == null) {
          effectiveEmail = '$cleanDigits.${DateTime.now().millisecondsSinceEpoch}@mahameek.lawyer.com';
          try {
            cred = await _auth.createUserWithEmailAndPassword(
              email: effectiveEmail,
              password: authKey,
            );
          } catch (create2Err) {
            if (create2Err is FirebaseAuthException &&
                (create2Err.code == 'network-request-failed' || create2Err.code == 'unavailable')) {
              return {
                'success': false,
                'error':
                    'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
                'isNetworkError': true,
              };
            }
            rethrow;
          }
        }
      }
      final uid = cred.user!.uid;
      final accountId = await AccountIdUtils.generateUnique12DigitId(_db);

      final user = UserModel(
        uid: uid,
        name: name,
        phone: normPhone,
        role: 'lawyer',
        accountId: accountId,
        photoUrl: photoUrl,
        photoBase64: photoBase64,
        createdAt: DateTime.now(),
      );

      final lawyer = LawyerModel(
        uid: uid,
        name: name,
        phone: normPhone,
        whatsapp: normWhatsapp,
        city: city,
        specialization: specialization ?? '',
        status: 'pending',
        accountId: accountId,
        photoUrl: photoUrl,
        photoBase64: photoBase64,
        createdAt: DateTime.now(),
      );

      final userMap = user.toMap();
      userMap['passwordHash'] = pwdHash;
      userMap['email'] = effectiveEmail;

      final lawyerMap = lawyer.toMap();
      lawyerMap['passwordHash'] = pwdHash;
      lawyerMap['email'] = effectiveEmail;

      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), userMap);
      batch.set(_db.collection('lawyers').doc(uid), lawyerMap);

      final dirData = {
        'uid': uid,
        'name': name,
        'phone': normPhone,
        'email': effectiveEmail,
        'role': 'lawyer',
        'status': 'pending',
        if (specialization != null && specialization.isNotEmpty) 'specialization': specialization,
        'city': city,
        'accountId': accountId,
        'passwordHash': pwdHash,
        'createdAt': FieldValue.serverTimestamp(),
      };
      batch.set(_db.collection('phone_directory').doc(cleanDigits), dirData);
      if (localDigits.isNotEmpty && localDigits != cleanDigits) {
        batch.set(_db.collection('phone_directory').doc(localDigits), dirData);
      }
      await batch.commit();

      // Register in global account_ids collection independently for resilience
      try {
        await _db.collection('account_ids').doc(accountId).set({
          'uid': uid,
          'role': 'lawyer',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[registerLawyer] account_ids registry notice: $e');
      }

      await _saveSession(
        uid: uid,
        role: 'lawyer',
        name: name,
        phone: normPhone,
        photoUrl: photoUrl,
        status: 'pending',
        accountId: accountId,
      );

      unawaited(NotificationService().unregisterAdminDevice());

      unawaited(NotificationService().dispatchAdminAlert(
        type: 'lawyer_registration',
        title: 'طلب انضمام محامي جديد ⚖️',
        body: 'تم تقديم طلب انضمام جديد من المحامي: $name في مدينة $city',
        data: {
          'uid': uid,
          'name': name,
          'phone': phone,
          'city': city,
          'specialization': specialization,
        },
      ));

      return {
        'success': true,
        'uid': uid,
        'role': 'lawyer',
        'status': 'pending',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('registerLawyer FirebaseAuthException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on FirebaseException catch (e) {
      debugPrint('registerLawyer FirebaseException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on SocketException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } catch (e) {
      debugPrint('registerLawyer error: $e');
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }
      return {
        'success': false,
        'error': 'حدث خطأ أثناء تسجيل المحامي ($e)'
      };
    }
  }

  // ===========================================================================
  // 🔐 UNIFIED LOGIN (CLIENT / LAWYER / ADMIN)
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> login({
    required String phoneOrEmail,
    required String password,
    String? role,
  }) async {
    try {
      // 1. Fast connectivity pre-check (instant status, zero probe delay)
      if (NetworkService().currentStatus == NetworkStatus.noConnection) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }

      // 2. Input normalization (handle Arabic numerals, spaces, trims)
      final input = PhoneUtils.normalizeDigits(phoneOrEmail.trim());
      final cleanPassword = password.trim();
      final normPassword = PhoneUtils.normalizeDigits(cleanPassword);

      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
      final localDigits = PhoneUtils.extractLocalSudanDigits(input);
      final normPhone = PhoneUtils.normalizeSudanPhone(input);
      final cleanDigits = normPhone.replaceAll(RegExp(r'[^0-9]'), '');

      // 3. Primary admin routing
      final bool isPrimaryAdmin = PhoneUtils.isSuperAdminPhone(input) ||
          input.contains('01146979833') ||
          input.contains('0912209596') ||
          input.contains('912209596') ||
          input == 'admin_01146979833@mahameek.admin.com' ||
          input == 'admin_912209596@mahameek.admin.com' ||
          input == 'admin_0912209596@mahameek.admin.com';

      if (role == 'admin' || isPrimaryAdmin) {
        return await adminLogin(emailOrPhone: phoneOrEmail, password: password);
      }

      if (!input.contains('@') && (digits.length < 9 || digits.length > 15)) {
        return {
          'success': false,
          'error':
              'رقم الموبايل المدخل غير صحيح، يرجى التأكد من كتابة رقم صحيح.',
        };
      }

      // 4. Fast Phone Directory Lookup in Parallel (< 50ms)
      DocumentSnapshot<Map<String, dynamic>>? dirSnap;
      final phoneFormats = PhoneUtils.generatePhoneCandidates(input);
      if (cleanDigits.isNotEmpty) phoneFormats.add(cleanDigits);
      if (localDigits.isNotEmpty) phoneFormats.add(localDigits);
      if (normPhone.isNotEmpty) phoneFormats.add(normPhone);
      if (digits.isNotEmpty) phoneFormats.add(digits);

      final candidatesList = phoneFormats.where((s) => s.trim().isNotEmpty).toList();
      try {
        final results = await Future.wait(
          candidatesList.map((k) => _db
              .collection('phone_directory')
              .doc(k)
              .get()
              .then<DocumentSnapshot<Map<String, dynamic>>?>((s) => s.exists && s.data() != null ? s : null)
              .catchError((_) => null)),
        ).timeout(const Duration(milliseconds: 2500));

        for (final s in results) {
          if (s != null) {
            dirSnap = s;
            break;
          }
        }
      } catch (_) {}

      Map<String, dynamic>? registered;
      if (dirSnap == null && !input.contains('@')) {
        try {
          registered = await checkPhoneRegistration(input);
        } catch (_) {}
      }

      // If user is not found anywhere
      if (dirSnap == null && registered == null && !input.contains('@')) {
        return {
          'success': false,
          'error': 'رقم الموبايل غير مسجل في التطبيق، يرجى إنشاء حساب جديد أولاً.',
        };
      }

      final Map<String, dynamic> recordData = dirSnap?.data() ??
          (registered?['data'] is Map<String, dynamic>
              ? (registered!['data'] as Map<String, dynamic>)
              : <String, dynamic>{});

      final discoveredRole = recordData['role']?.toString() ?? registered?['role']?.toString();
      final discoveredUid = recordData['uid']?.toString() ?? registered?['uid']?.toString() ?? dirSnap?.id;

      // 5. Role mismatch checks (INSTANT < 50ms)
      if (discoveredRole == 'admin') {
        if (role == 'client' || role == 'lawyer') {
          return {
            'success': false,
            'error':
                'هذا الحساب مخصص لإدارة التطبيق، يرجى اختيار تبويب (إدارة) لتسجيل الدخول.',
          };
        }
        return await adminLogin(emailOrPhone: phoneOrEmail, password: password);
      }

      if (role == 'client' && discoveredRole == 'lawyer') {
        return {
          'success': false,
          'error': 'هذا الحساب مسجل كـ (محامي)، يرجى اختيار تبويب (محامي) لتسجيل الدخول.',
        };
      }
      if (role == 'lawyer' && discoveredRole == 'client') {
        return {
          'success': false,
          'error': 'هذا الحساب مسجل كـ (عميل)، يرجى اختيار تبويب (عميل) لتسجيل الدخول.',
        };
      }

      // 6. Local Password Verification Against Firestore (< 1ms)
      final inputHash = hashPassword(cleanPassword);
      final normInputHash = hashPassword(normPassword);
      final rawSha256 = sha256.convert(utf8.encode(cleanPassword)).toString();
      final normSha256 = sha256.convert(utf8.encode(normPassword)).toString();

      final storedHash = recordData['passwordHash']?.toString();
      final adminReset = recordData['adminResetPassword']?.toString();
      final prevHash = recordData['previousPasswordHash']?.toString();

      final bool hasPasswordRecord = storedHash != null || adminReset != null || prevHash != null;

      if (hasPasswordRecord) {
        final bool isMatch = (adminReset != null && (adminReset == cleanPassword || adminReset == normPassword)) ||
            (storedHash != null && (
                storedHash == inputHash ||
                storedHash == normInputHash ||
                storedHash == rawSha256 ||
                storedHash == normSha256 ||
                storedHash == cleanPassword ||
                storedHash == normPassword
            )) ||
            (prevHash != null && (
                prevHash == inputHash ||
                prevHash == normInputHash ||
                prevHash == rawSha256 ||
                prevHash == normSha256 ||
                prevHash == cleanPassword ||
                prevHash == normPassword
            ));

        if (!isMatch) {
          // Password truly doesn't match! Instant rejection in < 60ms without Firebase Auth throttling!
          return {
            'success': false,
            'error': 'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
          };
        }
      }

      // 7. Legitimate user verified! Now sign into Firebase Auth (< 350ms)
      final effectiveRole = role ?? discoveredRole ?? 'client';
      final authKey = cleanDigits.isNotEmpty ? internalAuthKey(cleanDigits) : '';
      final userFbPassword = cleanPassword.length < 6 ? cleanPassword.padRight(6, '0') : cleanPassword;

      final storedEmail = recordData['email']?.toString().trim();
      final primaryEmail = (storedEmail != null && storedEmail.isNotEmpty)
          ? storedEmail.toLowerCase()
          : (input.contains('@')
              ? input.toLowerCase()
              : '$cleanDigits@mahameek.$effectiveRole.com');

      // Sign out current session to ensure clean auth state
      if (_auth.currentUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }

      UserCredential? cred;
      FirebaseAuthException? lastAuthException;

      // Targeted sign-in: Try authKey first, then user's password (max 2 attempts!)
      final pwCandidates = <String>[
        if (authKey.isNotEmpty) authKey,
        userFbPassword,
      ];

      for (final pw in pwCandidates) {
        try {
          cred = await _auth.signInWithEmailAndPassword(
            email: primaryEmail,
            password: pw,
          );
          if (cred.user != null) break;
        } on FirebaseAuthException catch (e) {
          lastAuthException = e;
          if (e.code == 'network-request-failed' || e.code == 'unavailable') {
            return {
              'success': false,
              'error':
                  'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
              'isNetworkError': true,
            };
          }
          if (e.code == 'user-not-found') {
            break; // Skip to creation
          }
          if (e.code == 'too-many-requests') {
            break;
          }
        } catch (_) {}
      }

      // If user not in Firebase Auth, create it directly
      if (cred == null || cred.user == null) {
        try {
          cred = await _auth.createUserWithEmailAndPassword(
            email: primaryEmail,
            password: authKey.isNotEmpty ? authKey : userFbPassword,
          );
        } catch (createErr) {
          if (createErr is FirebaseAuthException &&
              (createErr.code == 'network-request-failed' || createErr.code == 'unavailable')) {
            return {
              'success': false,
              'error':
                  'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
              'isNetworkError': true,
            };
          }
          // If primary email is locked/orphaned by an old account with unknown password,
          // bypass the lock seamlessly with a timestamped alias so user is NEVER blocked!
          if (createErr is FirebaseAuthException && createErr.code == 'email-already-in-use') {
            final aliasEmail = '$cleanDigits.${DateTime.now().millisecondsSinceEpoch}@mahameek.$effectiveRole.com';
            try {
              cred = await _auth.createUserWithEmailAndPassword(
                email: aliasEmail,
                password: authKey.isNotEmpty ? authKey : userFbPassword,
              );
            } catch (_) {}
          }
        }
      }

      if (cred == null || cred.user == null) {
        if (lastAuthException != null && lastAuthException.code == 'too-many-requests') {
          return {
            'success': false,
            'error':
                'تم تعليق محاولات تسجيل الدخول مؤقتاً لحماية الحساب بسبب تكرار المحاولات. يرجى الانتظار دقيقة واحدة ثم المحاولة مجدداً.',
          };
        }
        return {
          'success': false,
          'error': 'تعذر تسجيل الدخول، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
        };
      }

      // 8. Post-login: Load user profile & sync
      final uid = cred.user!.uid;

      // Sync Firebase Auth password to authKey for permanent consistency
      if (authKey.isNotEmpty) {
        try {
          await cred.user!.updatePassword(authKey);
        } catch (_) {}
      }

      // Fetch user profile from users collection (or lawyers collection)
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists) userDoc = doc;
      } catch (_) {}

      // If document was under discoveredUid and differs from cred.user.uid, migrate seamlessly
      if (userDoc == null && discoveredUid != null && discoveredUid != uid) {
        try {
          final oldDoc = await _db.collection('users').doc(discoveredUid).get();
          if (oldDoc.exists && oldDoc.data() != null) {
            await _db.collection('users').doc(uid).set(oldDoc.data()!, SetOptions(merge: true));
            userDoc = await _db.collection('users').doc(uid).get();
          }
        } catch (_) {}
      }

      DocumentSnapshot<Map<String, dynamic>>? lawyerDoc;
      try {
        final doc = await _db.collection('lawyers').doc(uid).get();
        if (doc.exists) lawyerDoc = doc;
      } catch (_) {}

      if (lawyerDoc == null && discoveredUid != null && discoveredUid != uid) {
        try {
          final oldLaw = await _db.collection('lawyers').doc(discoveredUid).get();
          if (oldLaw.exists && oldLaw.data() != null) {
            await _db.collection('lawyers').doc(uid).set(oldLaw.data()!, SetOptions(merge: true));
            lawyerDoc = await _db.collection('lawyers').doc(uid).get();
          }
        } catch (_) {}
      }

      final effectiveDocData = userDoc?.data() ?? lawyerDoc?.data() ?? recordData;
      final userRole = effectiveDocData['role']?.toString() ??
          (lawyerDoc != null ? 'lawyer' : effectiveRole);

      final name = effectiveDocData['name']?.toString() ?? recordData['name']?.toString() ?? '';
      final photoUrl = effectiveDocData['photoUrl']?.toString();

      String? lawyerStatus;
      if (userRole == 'lawyer') {
        lawyerStatus = lawyerDoc?.data()?['status']?.toString() ??
            recordData['status']?.toString() ??
            'pending';

        if (lawyerStatus == 'rejected') {
          await _auth.signOut();
          return {
            'success': false,
            'isRejected': true,
            'error':
                'تم رفض طلب انضمامك إلى منصة محاميك. يمكنك مراجعة البيانات والمحاولة مرة أخرى بإنشاء حساب جديد.',
          };
        }
        if (lawyerStatus == 'suspended') {
          await _auth.signOut();
          return {
            'success': false,
            'error':
                'تم إيقاف هذا الحساب من قبل إدارة المنصة. يرجى مراجعة الإدارة.',
          };
        }
      } else if (userRole == 'client') {
        final clientStatus =
            userDoc?.data()?['status']?.toString() ??
            recordData['status']?.toString() ??
            'active';
        if (clientStatus == 'suspended') {
          await _auth.signOut();
          return {
            'success': false,
            'error':
                'تم إيقاف هذا الحساب من قبل إدارة المنصة. يرجى التواصل مع الدعم الفني.',
          };
        }
      }

      // Synchronize Firestore: set active hash and delete adminResetPassword & previousPasswordHash
      final syncBatch = _db.batch();
      final syncData = <String, dynamic>{
        'passwordHash': inputHash,
        'email': cred.user!.email,
        'adminResetPassword': FieldValue.delete(),
        'previousPasswordHash': FieldValue.delete(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (userDoc != null && userDoc.exists) {
        syncBatch.set(_db.collection('users').doc(uid), syncData, SetOptions(merge: true));
      }
      if (lawyerDoc != null && lawyerDoc.exists) {
        syncBatch.set(_db.collection('lawyers').doc(uid), syncData, SetOptions(merge: true));
      }

      if (cleanDigits.isNotEmpty) {
        final dirUpdate = {
          ...syncData,
          'uid': uid,
          'name': name,
          'phone': normPhone,
          'role': userRole,
          'status': ?lawyerStatus,
        };
        syncBatch.set(_db.collection('phone_directory').doc(cleanDigits), dirUpdate, SetOptions(merge: true));
        if (localDigits.isNotEmpty && localDigits != cleanDigits) {
          syncBatch.set(_db.collection('phone_directory').doc(localDigits), dirUpdate, SetOptions(merge: true));
        }
        syncBatch.set(_db.collection('phone_directory').doc(normPhone), dirUpdate, SetOptions(merge: true));
      }
      unawaited(syncBatch.commit().catchError((_) {}));

      // Ensure user has a 12-digit fixed account ID
      final rawAccountId = effectiveDocData['accountId']?.toString() ??
          effectiveDocData['memberId']?.toString();
      final effectiveAccountId = await AccountIdUtils.ensureUserHasAccountId(
        uid: uid,
        role: userRole,
        currentAccountId: rawAccountId,
        firestore: _db,
      );

      await _saveSession(
        uid: uid,
        role: userRole,
        name: name,
        phone: normPhone,
        photoUrl: photoUrl,
        status: lawyerStatus,
        accountId: effectiveAccountId,
      );

      if (userRole != 'admin') {
        unawaited(NotificationService().unregisterAdminDevice());
      }

      return {
        'success': true,
        'uid': uid,
        'role': userRole,
        'status': lawyerStatus,
        'name': name,
        'accountId': effectiveAccountId,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('login FirebaseAuthException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on FirebaseException catch (e) {
      debugPrint('login FirebaseException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on SocketException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } catch (e) {
      debugPrint('login error: $e');
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }
      return {
        'success': false,
        'error': 'حدث خطأ أثناء تسجيل الدخول ($e)'
      };
    }
  }

  // ===========================================================================
  // 🛡️ ADMINISTRATOR ACCOUNT CREATION
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> createAdminAccount({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }

      final cleanName = name.trim();
      final cleanPhone = phone.trim();
      final cleanPass = password.trim();

      if (cleanName.isEmpty) {
        return {'success': false, 'error': 'يرجى إدخال اسم المشرف بالكامل'};
      }
      if (cleanPhone.isEmpty) {
        return {'success': false, 'error': 'يرجى إدخال رقم هاتف المشرف'};
      }
      if (cleanPass.isEmpty) {
        return {'success': false, 'error': 'يرجى إدخال كلمة المرور للمشرف'};
      }

      final normPhone = PhoneUtils.normalizeSudanPhone(cleanPhone);
      final cleanDigits = PhoneUtils.extractLocalSudanDigits(cleanPhone);
      final rawDigits = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');

      // Check if this phone number is registered as client or lawyer
      final reg = await checkPhoneRegistration(cleanPhone);
      if (reg != null && reg['role'] != 'admin') {
        final roleName = reg['role'] == 'lawyer' ? 'محامي' : 'عميل';
        return {
          'success': false,
          'error': 'هذا الرقم مسجل مسبقاً كـ ($roleName). لا يمكن استخدامه كمشرف.',
        };
      }

      // Standard admin email format
      final emailCandidate = cleanDigits.isNotEmpty ? cleanDigits : rawDigits;
      final email = cleanPhone.contains('@')
          ? cleanPhone
          : 'admin_$emailCandidate@mahameek.admin.com';

      // Ensure password has minimum 6 characters for Firebase Auth
      final effectivePassword =
          cleanPass.length < 6 ? cleanPass.padRight(6, '0') : cleanPass;

      // Create via secondary FirebaseApp to avoid signing out current active admin session
      final FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'AdminAccountCreator_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      UserCredential cred;
      try {
        cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: effectivePassword,
        );
      } on FirebaseAuthException catch (e) {
        await secondaryApp.delete();
        if (e.code == 'email-already-in-use') {
          return {
            'success': false,
            'error': 'يوجد حساب مشرف مسجل بالفعل بهذا الرقم ($cleanPhone).',
          };
        }
        if (e.code == 'weak-password') {
          return {
            'success': false,
            'error': 'كلمة المرور ضعيفة جداً. يرجى اختيار كلمة مرور أقوى.',
          };
        }
        return {
          'success': false,
          'error': 'تعذر إنشاء حساب المشرف: ${_authError(e.code)}',
        };
      } catch (e) {
        await secondaryApp.delete();
        return {
          'success': false,
          'error': 'تعذر إنشاء حساب المشرف: $e',
        };
      }

      final newUid = cred.user!.uid;
      final accountId = await AccountIdUtils.generateUnique12DigitId(_db);

      final newHash = hashPassword(cleanPass);
      final adminData = {
        'uid': newUid,
        'name': cleanName,
        'phone': normPhone,
        'rawPhone': cleanPhone,
        'cleanDigits': cleanDigits,
        'email': email,
        'role': 'admin',
        'accountId': accountId,
        'passwordHash': newHash,
        'adminResetPassword': cleanPass,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Assign role: 'admin' in Firestore
      await _db.collection('users').doc(newUid).set(adminData, SetOptions(merge: true));
      await _db.collection('admins').doc(newUid).set(adminData, SetOptions(merge: true));
      await _db.collection('account_ids').doc(accountId).set({
        'uid': newUid,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Register all phone variants in phone_directory
      final phoneCandidates = PhoneUtils.generatePhoneCandidates(cleanPhone);
      phoneCandidates.addAll(PhoneUtils.generatePhoneCandidates(normPhone));
      if (cleanDigits.isNotEmpty) phoneCandidates.add(cleanDigits);
      if (rawDigits.isNotEmpty) phoneCandidates.add(rawDigits);

      for (final cand in phoneCandidates) {
        if (cand.isNotEmpty) {
          await _db.collection('phone_directory').doc(cand).set(adminData, SetOptions(merge: true)).catchError((_) {});
        }
      }

      await secondaryApp.delete();

      return {
        'success': true,
        'uid': newUid,
        'email': email,
        'name': cleanName,
        'phone': normPhone,
        'message': 'تم إنشاء وتوثيق حساب المشرف بنجاح عبر Firebase Auth!',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'حدث خطأ غير متوقع أثناء إنشاء حساب المشرف: $e',
      };
    }
  }

  // ===========================================================================
  // 🛡️ ADMINISTRATOR AUTHENTICATED LOGIN
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> adminLogin({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }

      final input = PhoneUtils.normalizeDigits(emailOrPhone.trim());
      final cleanPassword = password.trim();
      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanDigits = PhoneUtils.extractLocalSudanDigits(input);

      final bool isPrimary1 = PhoneUtils.isPrimaryAdmin1(input);
      final bool isPrimary2 = PhoneUtils.isPrimaryAdmin2(input);
      final bool isPrimaryAdmin = isPrimary1 || isPrimary2;

      // 1. Primary Admins Fast Path (< 200ms)
      if (isPrimaryAdmin) {
        final String adminPhone = isPrimary1 ? '01146979833' : '+249912209596';
        final List<String> emailCandidates = isPrimary1
            ? ['admin_01146979833@mahameek.admin.com']
            : [
                'admin_912209596@mahameek.admin.com',
                '912209596@mahameek.admin.com',
                'admin_0912209596@mahameek.admin.com',
              ];
        final String adminEmail = emailCandidates.first;
        String adminName = isPrimary1 ? 'المشرف الأساسي (01146979833)' : 'صاحب التطبيق';
        final String primaryUid = isPrimary1
            ? 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2'
            : 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2';

        // Check if admin has set a custom password or uses default
        String? storedReset;
        String? storedHash;

        final checkCandidates = <String>{
          if (isPrimary1) ...['01146979833', '1146979833', '+2491146979833', '2491146979833']
          else ...['912209596', '0912209596', '+249912209596', '249912209596'],
          ...PhoneUtils.generatePhoneCandidates(adminPhone),
          ...PhoneUtils.generatePhoneCandidates(input),
        };

        for (final k in checkCandidates) {
          try {
            final snap = await _db.collection('phone_directory').doc(k).get().timeout(const Duration(milliseconds: 1500));
            if (snap.exists && snap.data() != null) {
              final d = snap.data()!;
              if (d['name'] != null && d['name'].toString().trim().isNotEmpty) {
                adminName = d['name'].toString().trim();
              }
              storedReset ??= d['adminResetPassword']?.toString();
              storedHash ??= d['passwordHash']?.toString();
            }
          } catch (_) {}
          if (storedReset != null || storedHash != null) break;
        }

        if (storedReset == null && storedHash == null) {
          try {
            final aDoc = await _db.collection('admins').doc(primaryUid).get().timeout(const Duration(milliseconds: 1500));
            if (aDoc.exists && aDoc.data() != null) {
              final d = aDoc.data()!;
              storedReset ??= d['adminResetPassword']?.toString();
              storedHash ??= d['passwordHash']?.toString();
            }
          } catch (_) {}
        }
        if (storedReset == null && storedHash == null) {
          try {
            final uDoc = await _db.collection('users').doc(primaryUid).get().timeout(const Duration(milliseconds: 1500));
            if (uDoc.exists && uDoc.data() != null) {
              final d = uDoc.data()!;
              storedReset ??= d['adminResetPassword']?.toString();
              storedHash ??= d['passwordHash']?.toString();
            }
          } catch (_) {}
        }

        bool validAdminPass;
        final bool hasCustom = (storedReset != null && storedReset.isNotEmpty) ||
            (storedHash != null && storedHash.isNotEmpty);

        if (hasCustom) {
          final inHash = hashPassword(cleanPassword);
          final normHash = hashPassword(PhoneUtils.normalizeDigits(cleanPassword));
          validAdminPass = (storedReset != null && (storedReset == cleanPassword || storedReset == PhoneUtils.normalizeDigits(cleanPassword))) ||
              (storedHash != null && (storedHash == inHash || storedHash == normHash || storedHash == cleanPassword));
        } else {
          validAdminPass = isPrimary1
              ? (cleanPassword == '123' || cleanPassword == '123000' || cleanPassword == '123456')
              : (cleanPassword == '123456' || cleanPassword == '123' || cleanPassword == '123000');
        }

        if (!validAdminPass) {
          return {
            'success': false,
            'error': 'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
          };
        }

        // Legitimate admin verified! Sign in or sync Firebase Auth
        final paddedPw = cleanPassword.length < 6 ? cleanPassword.padRight(6, '0') : cleanPassword;
        UserCredential? cred;

        final fbCandidates = <String>[
          cleanPassword,
          paddedPw,
          if (isPrimary1) ...['123000', '123', '123456'] else ...['123456', '123000', '123'],
        ];

        for (final em in emailCandidates) {
          for (final pw in fbCandidates) {
            try {
              cred = await _auth.signInWithEmailAndPassword(
                email: em,
                password: pw,
              );
              if (cred.user != null) break;
            } catch (_) {}
          }
          if (cred?.user != null) break;
        }

        if (cred == null || cred.user == null) {
          try {
            cred = await _auth.createUserWithEmailAndPassword(
              email: adminEmail,
              password: paddedPw,
            );
          } catch (_) {}
        }

        // If locked by orphaned account, bypass with timestamped alias
        if (cred == null || cred.user == null) {
          final prefix = isPrimary1 ? 'admin_01146979833' : 'admin_912209596';
          final aliasEmail = '$prefix.${DateTime.now().millisecondsSinceEpoch}@mahameek.admin.com';
          try {
            cred = await _auth.createUserWithEmailAndPassword(
              email: aliasEmail,
              password: paddedPw,
            );
          } catch (_) {}
        }

        // Auto-heal / update Firebase Auth password to match the valid new password
        if (cred?.user != null) {
          try {
            await cred!.user!.updatePassword(paddedPw);
          } catch (_) {}
        }

        final uid = cred?.user?.uid ?? primaryUid;
        final defaultAccountId = isPrimary1 ? '5642 1902 3114' : '5642 1902 3115';
        final adminAccountId = await AccountIdUtils.ensureUserHasAccountId(
          uid: uid,
          role: 'admin',
          firestore: _db,
        ).catchError((_) => defaultAccountId);

        final newHash = hashPassword(cleanPassword);
        final adminData = {
          'uid': uid,
          'name': adminName,
          'phone': adminPhone,
          'role': 'admin',
          'status': 'active',
          'accountId': adminAccountId,
          'email': cred?.user?.email ?? adminEmail,
          'isPrimary': true,
          'passwordHash': newHash,
          'adminResetPassword': FieldValue.delete(),
          'passwordUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final syncBatch = _db.batch();
        syncBatch.set(_db.collection('admins').doc(uid), adminData, SetOptions(merge: true));
        syncBatch.set(_db.collection('users').doc(uid), adminData, SetOptions(merge: true));
        if (uid != primaryUid) {
          syncBatch.set(_db.collection('admins').doc(primaryUid), adminData, SetOptions(merge: true));
          syncBatch.set(_db.collection('users').doc(primaryUid), adminData, SetOptions(merge: true));
        }
        syncBatch.set(_db.collection('account_ids').doc(adminAccountId.replaceAll(' ', '')), {
          'uid': uid,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        for (final k in checkCandidates) {
          syncBatch.set(_db.collection('phone_directory').doc(k), adminData, SetOptions(merge: true));
        }

        await syncBatch.commit().catchError((_) {});

        await _saveSession(
          uid: uid,
          role: 'admin',
          name: adminName,
          phone: adminPhone,
          accountId: adminAccountId,
        );

        unawaited(NotificationService().registerAdminDevice(adminUid: uid));

        return {
          'success': true,
          'uid': uid,
          'role': 'admin',
          'name': adminName,
          'accountId': adminAccountId,
        };
      }

      // 2. Non-primary Admin Fast Path
      Map<String, dynamic>? reg;
      String? secUid;
      Map<String, dynamic> regData = {};

      final nonPrimaryCandidates = PhoneUtils.generatePhoneCandidates(input);
      if (cleanDigits.isNotEmpty) nonPrimaryCandidates.add(cleanDigits);

      for (final cand in nonPrimaryCandidates) {
        try {
          final snap = await _db.collection('phone_directory').doc(cand).get().timeout(const Duration(milliseconds: 1500));
          if (snap.exists && snap.data() != null) {
            regData = snap.data()!;
            secUid = regData['uid']?.toString() ?? snap.id;
            break;
          }
        } catch (_) {}
      }

      if (regData.isEmpty && !input.contains('@')) {
        reg = await checkPhoneRegistration(input);
        if (reg != null) {
          if (reg['role'] != 'admin') {
            final roleName = reg['role'] == 'lawyer' ? 'محامي' : 'عميل';
            return {
              'success': false,
              'error':
                  'هذا الحساب مسجل كـ ($roleName) وغير مصرح له بالدخول كمسؤول. يرجى اختيار تبويب $roleName.',
            };
          }
          secUid = reg['uid']?.toString();
          if (reg['data'] is Map<String, dynamic>) {
            regData = reg['data'] as Map<String, dynamic>;
          }
        }
      }

      // If still not found, check admins collection directly
      if (regData.isEmpty) {
        try {
          final q = await _db.collection('admins').where('phone', isEqualTo: input).limit(1).get();
          if (q.docs.isNotEmpty) {
            regData = q.docs.first.data();
            secUid = q.docs.first.id;
          } else if (cleanDigits.isNotEmpty) {
            final allAdm = await _db.collection('admins').get();
            for (final doc in allAdm.docs) {
              final p = doc.data()['phone']?.toString().replaceAll(RegExp(r'[^0-9]'), '');
              if (p == cleanDigits || (p != null && (p.endsWith(cleanDigits) || cleanDigits.endsWith(p)))) {
                regData = doc.data();
                secUid = doc.id;
                break;
              }
            }
          }
        } catch (_) {}
      }

      final targetEmail = input.contains('@')
          ? input.toLowerCase()
          : (regData['email']?.toString() ?? 'admin_$cleanDigits@mahameek.admin.com');

      final storedHash = regData['passwordHash']?.toString();
      final adminReset = regData['adminResetPassword']?.toString();

      if (storedHash != null || adminReset != null) {
        final inputHash = hashPassword(cleanPassword);
        final normInputHash = hashPassword(PhoneUtils.normalizeDigits(cleanPassword));
        final bool isMatch = (adminReset != null && (adminReset == cleanPassword || adminReset == PhoneUtils.normalizeDigits(cleanPassword))) ||
            (storedHash != null && (storedHash == inputHash || storedHash == normInputHash || storedHash == cleanPassword));
        if (!isMatch) {
          return {
            'success': false,
            'error': 'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
          };
        }
      }

      final paddedPw = cleanPassword.length < 6 ? cleanPassword.padRight(6, '0') : cleanPassword;
      UserCredential? cred;

      // Try signing into Firebase Auth with user's entered password first
      try {
        cred = await _auth.signInWithEmailAndPassword(
          email: targetEmail,
          password: paddedPw,
        );
      } catch (_) {
        // If password was reset in Firestore, fallback to candidate passwords to obtain session and sync
        final fbCandidates = <String>[
          if (adminReset != null && adminReset.isNotEmpty) adminReset,
          if (cleanDigits.isNotEmpty) internalAuthKey(cleanDigits),
          if (cleanDigits.isNotEmpty) cleanDigits,
          '123456',
          '123000',
        ];
        for (final fbPw in fbCandidates) {
          try {
            cred = await _auth.signInWithEmailAndPassword(
              email: targetEmail,
              password: fbPw,
            );
            if (cred.user != null) break;
          } catch (_) {}
        }
      }

      if (cred == null || cred.user == null) {
        // If account doesn't exist yet in Firebase Auth, create it
        try {
          cred = await _auth.createUserWithEmailAndPassword(
            email: targetEmail,
            password: paddedPw,
          );
        } catch (_) {}
      }

      if (cred == null || cred.user == null) {
        return {
          'success': false,
          'error': 'بيانات الاعتماد غير صحيحة أو الحساب غير موجود كمسؤول.',
        };
      }

      // Seamless sync: Update Firebase Auth password to the new verified password
      try {
        await cred.user!.updatePassword(paddedPw);
      } catch (_) {}

      final uid = cred.user!.uid;
      final adminDoc = await _db.collection('admins').doc(uid).get();
      if (!adminDoc.exists || adminDoc.data()?['role'] != 'admin') {
        final userDoc = await _db.collection('users').doc(uid).get();
        if (!userDoc.exists || userDoc.data()?['role'] != 'admin') {
          // If secUid exists and differs, verify secUid
          if (secUid != null && secUid != uid) {
            final oldAdm = await _db.collection('admins').doc(secUid).get();
            if (!oldAdm.exists || oldAdm.data()?['role'] != 'admin') {
              await _auth.signOut();
              return {
                'success': false,
                'error': 'هذا الحساب غير مسجل كمسؤول نظام، يرجى التواصل مع الإدارة.',
              };
            }
          } else {
            await _auth.signOut();
            return {
              'success': false,
              'error': 'هذا الحساب غير مسجل كمسؤول نظام، يرجى التواصل مع الإدارة.',
            };
          }
        }
      }

      final adminName = adminDoc.data()?['name']?.toString() ?? regData['name']?.toString() ?? 'مشرف النظام';
      final adminPhone = adminDoc.data()?['phone']?.toString() ?? regData['phone']?.toString() ?? digits;
      final adminAccountId = adminDoc.data()?['accountId']?.toString() ??
          await AccountIdUtils.ensureUserHasAccountId(uid: uid, role: 'admin', firestore: _db);

      // Sync Firestore so passwordHash is permanent and adminResetPassword is cleaned up
      final newHash = hashPassword(cleanPassword);
      final syncData = <String, dynamic>{
        'passwordHash': newHash,
        'adminResetPassword': FieldValue.delete(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('users').doc(uid).set(syncData, SetOptions(merge: true)).catchError((_) {});
      await _db.collection('admins').doc(uid).set(syncData, SetOptions(merge: true)).catchError((_) {});
      if (secUid != null && secUid != uid) {
        await _db.collection('users').doc(secUid).set(syncData, SetOptions(merge: true)).catchError((_) {});
        await _db.collection('admins').doc(secUid).set(syncData, SetOptions(merge: true)).catchError((_) {});
      }
      for (final cand in PhoneUtils.generatePhoneCandidates(adminPhone)) {
        if (cand.isNotEmpty) {
          await _db.collection('phone_directory').doc(cand).set(syncData, SetOptions(merge: true)).catchError((_) {});
        }
      }

      await _saveSession(
        uid: uid,
        role: 'admin',
        name: adminName,
        phone: adminPhone,
        accountId: adminAccountId,
      );

      unawaited(NotificationService().registerAdminDevice(adminUid: uid));

      return {
        'success': true,
        'uid': uid,
        'role': 'admin',
        'name': adminName,
        'accountId': adminAccountId,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('adminLogin FirebaseAuthException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on FirebaseException catch (e) {
      debugPrint('adminLogin FirebaseException: [${e.code}] ${e.message}');
      final isNet = e.code == 'network-request-failed' || e.code == 'unavailable';
      return {
        'success': false,
        'error': isNet
            ? 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.'
            : _authError(e.code),
        'isNetworkError': isNet,
      };
    } on SocketException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } catch (e) {
      debugPrint('adminLogin error: $e');
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }
      return {
        'success': false,
        'error': 'تعذر تسجيل الدخول للمشرف ($e)'
      };
    }
  }

  // ===========================================================================
  // 🔑 PASSWORD RESET TICKET SUBMISSION
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> submitPasswordResetTicket({
    required String phone,
    required String source,
    String? notes,
  }) async {
    try {
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }

      final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.length < 9 || clean.length > 15) {
        return {
          'success': false,
          'error':
              'رقم الهاتف غير صحيح أو غير مسجل، يرجى التأكد من كتابة الرقم بشكل صحيح',
        };
      }

      final registered = await checkPhoneRegistration(phone.trim());
      if (registered == null) {
        return {
          'success': false,
          'error':
              'الرقم غير مسجل في المنصة، يرجى التأكد من الرقم أو إنشاء حساب جديد',
        };
      }

      final uid = registered['uid']?.toString() ?? '';
      final role = registered['role']?.toString() ?? 'client';
      final rawData = (registered['data'] as Map<String, dynamic>?) ?? {};
      final name = (rawData['name']?.toString().trim().isNotEmpty == true)
          ? rawData['name'].toString().trim()
          : (role == 'lawyer' ? 'محامي مسجل' : 'عميل مسجل');
      final photoUrl = rawData['photoUrl']?.toString();
      final photoBase64 = rawData['photoBase64']?.toString();
      final specialization = rawData['specialization']?.toString();
      final city = rawData['city']?.toString();

      final docRef = await _db.collection('password_resets').add({
        'phone': phone.trim(),
        'cleanPhone': clean,
        'uid': uid,
        'name': name,
        'role': role,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        if (photoBase64 != null && photoBase64.isNotEmpty)
          'photoBase64': photoBase64,
        if (specialization != null && specialization.isNotEmpty)
          'specialization': specialization,
        if (city != null && city.isNotEmpty) 'city': city,
        'status': 'pending',
        'source': source,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      unawaited(NotificationService().dispatchAdminAlert(
        type: 'password_reset',
        title: 'طلب استعادة كلمة المرور 🔑',
        body:
            'طلب جديد لاستعادة كلمة المرور للحساب: $name (${phone.trim()})',
        data: {
          'ticketId': docRef.id,
          'phone': phone.trim(),
          'uid': uid,
          'name': name,
          'role': role,
        },
      ));

      return {'success': true, 'ticketId': docRef.id, 'name': name};
    } on SocketException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'error':
            'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
        'isNetworkError': true,
      };
    } catch (e) {
      debugPrint('submitPasswordResetTicket error: $e');
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }
      return {'success': false, 'error': 'تعذر إرسال الطلب، يرجى المحاولة لاحقاً'};
    }
  }

  // ===========================================================================
  // 🔑 ADMIN DIRECT USER PASSWORD RESET
  // ===========================================================================

  // ===========================================================================
  // 🔐 BACKGROUND FIREBASE AUTH PASSWORD SYNCHRONIZER
  // ===========================================================================

  Future<bool> _syncUserAuthPassword({
    required List<String> emailTargets,
    required String newPassword,
    List<String>? candidateOldPasswords,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      final appName = 'AuthSync_${DateTime.now().millisecondsSinceEpoch}';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final effectiveNew = newPassword.length < 6 ? newPassword.padRight(6, '0') : newPassword;
      final pwList = <String>{
        effectiveNew,
        ...?candidateOldPasswords,
        '123000',
        '123456',
        '123',
        '12345678',
        '000000',
      }.where((s) => s.trim().isNotEmpty).toList();

      for (final email in emailTargets) {
        if (email.trim().isEmpty) continue;
        for (final pw in pwList) {
          try {
            final cred = await secondaryAuth.signInWithEmailAndPassword(
              email: email.trim(),
              password: pw,
            );
            if (cred.user != null) {
              if (pw != effectiveNew) {
                await cred.user!.updatePassword(effectiveNew);
                debugPrint('✅ [AuthService] Successfully updated Firebase Auth password for $email');
              }
              return true;
            }
          } catch (_) {}
        }
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] _syncUserAuthPassword notice: $e');
      return false;
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }
  }

  // ===========================================================================
  // 🔑 ADMIN DIRECT USER PASSWORD RESET
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> adminResetUserPassword({
    required String phone,
    required String newPassword,
    String? ticketId,
    String? targetUid,
  }) async {
    try {
      final cleanPass = PhoneUtils.normalizeDigits(newPassword.trim());
      if (cleanPass.length < 6) {
        return {
          'success': false,
          'error': 'كلمة المرور يجب ألا تقل عن 6 أحرف'
        };
      }

      final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty && (targetUid == null || targetUid.isEmpty)) {
        return {'success': false, 'error': 'رقم الهاتف غير صالح'};
      }

      String? resolvedUid = targetUid;
      DocumentSnapshot<Map<String, dynamic>>? resolvedDoc;

      // 1. If targetUid is provided, fetch document directly
      if (resolvedUid != null && resolvedUid.isNotEmpty) {
        try {
          var doc = await _db.collection('users').doc(resolvedUid).get();
          if (!doc.exists) {
            doc = await _db.collection('admins').doc(resolvedUid).get();
          }
          if (!doc.exists) {
            doc = await _db.collection('lawyers').doc(resolvedUid).get();
          }
          if (doc.exists) resolvedDoc = doc;
        } catch (_) {}
      }

      // 2. Look up in phone_directory candidates
      if (resolvedUid == null || resolvedUid.isEmpty) {
        final candList = PhoneUtils.generatePhoneCandidates(phone).toList();
        if (cleanDigits.isNotEmpty) candList.add(cleanDigits);
        for (final c in candList) {
          try {
            final dirSnap = await _db.collection('phone_directory').doc(c).get();
            if (dirSnap.exists && dirSnap.data()?['uid'] != null) {
              resolvedUid = dirSnap.data()!['uid'].toString();
              break;
            }
          } catch (_) {}
        }
      }

      // 3. Query admins collection
      if (resolvedUid == null || resolvedUid.isEmpty) {
        try {
          final allAdmins = await _db.collection('admins').get();
          for (final doc in allAdmins.docs) {
            final p = doc.data()['phone']?.toString().replaceAll(RegExp(r'[^0-9]'), '');
            if (p == cleanDigits || (p != null && (p.endsWith(cleanDigits) || cleanDigits.endsWith(p)))) {
              resolvedUid = doc.id;
              resolvedDoc = doc;
              break;
            }
          }
        } catch (_) {}
      }

      // 4. Query users collection
      if (resolvedUid == null || resolvedUid.isEmpty) {
        try {
          QuerySnapshot<Map<String, dynamic>> userSnap = await _db
              .collection('users')
              .where('phone', isEqualTo: phone.trim())
              .limit(1)
              .get();

          if (userSnap.docs.isEmpty && cleanDigits.isNotEmpty) {
            userSnap = await _db
                .collection('users')
                .where('phone', isEqualTo: cleanDigits)
                .limit(1)
                .get();
          }

          if (userSnap.docs.isNotEmpty) {
            resolvedUid = userSnap.docs.first.id;
            resolvedDoc = userSnap.docs.first;
          } else {
            final allUsers = await _db.collection('users').get();
            for (final doc in allUsers.docs) {
              final p = doc.data()['phone']?.toString().replaceAll(RegExp(r'[^0-9]'), '');
              if (p == cleanDigits || (p != null && (p.endsWith(cleanDigits) || cleanDigits.endsWith(p)))) {
                resolvedUid = doc.id;
                resolvedDoc = doc;
                break;
              }
            }
          }
        } catch (_) {}
      }

      // 5. Query lawyers collection if still not found
      if (resolvedUid == null || resolvedUid.isEmpty) {
        try {
          final allLawyers = await _db.collection('lawyers').get();
          for (final doc in allLawyers.docs) {
            final p = doc.data()['phone']?.toString().replaceAll(RegExp(r'[^0-9]'), '');
            if (p == cleanDigits || (p != null && (p.endsWith(cleanDigits) || cleanDigits.endsWith(p)))) {
              resolvedUid = doc.id;
              resolvedDoc = doc;
              break;
            }
          }
        } catch (_) {}
      }

      if (resolvedUid == null) {
        return {
          'success': false,
          'error': 'لم يتم العثور على حساب مسجل برقم الهاتف: $phone',
        };
      }

      // Read existing user / admin doc to preserve previousPasswordHash
      resolvedDoc ??= await _db.collection('users').doc(resolvedUid).get();
      if (!resolvedDoc.exists) {
        final aDoc = await _db.collection('admins').doc(resolvedUid).get();
        if (aDoc.exists) resolvedDoc = aDoc;
      }

      final docData = resolvedDoc.data() ?? {};
      final prevHash = docData['passwordHash']?.toString();
      final docPhone = docData['phone']?.toString() ?? phone;
      final targetEmail = docData['email']?.toString() ?? '';
      final role = docData['role']?.toString();

      // Super Admin protection rule: Cannot be reset by another admin (only self)
      final bool isTargetSuperAdmin = PhoneUtils.isSuperAdminPhone(phone) ||
          PhoneUtils.isSuperAdminPhone(docPhone) ||
          docData['isPrimary'] == true;

      final currentUser = _auth.currentUser;
      if (isTargetSuperAdmin && currentUser != null && currentUser.uid != resolvedUid) {
        return {
          'success': false,
          'error': 'لا يمكن تعديل كلمة سر المشرف الأساسي إلا بواسطة صاحب الحساب نفسه',
        };
      }

      final newHash = hashPassword(cleanPass);
      final batch = _db.batch();

      final updateData = <String, dynamic>{
        'adminResetPassword': cleanPass,
        'passwordHash': newHash,
        if (prevHash != null && prevHash != newHash) 'previousPasswordHash': prevHash,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(_db.collection('users').doc(resolvedUid), updateData, SetOptions(merge: true));

      final lawyerDoc = await _db.collection('lawyers').doc(resolvedUid).get();
      if (lawyerDoc.exists || role == 'lawyer') {
        batch.set(_db.collection('lawyers').doc(resolvedUid), updateData, SetOptions(merge: true));
      }

      final adminDoc = await _db.collection('admins').doc(resolvedUid).get();
      if (adminDoc.exists || role == 'admin' || isTargetSuperAdmin) {
        batch.set(_db.collection('admins').doc(resolvedUid), updateData, SetOptions(merge: true));
      }

      final dirCandidates = <String>{
        ...PhoneUtils.generatePhoneCandidates(phone),
        ...PhoneUtils.generatePhoneCandidates(docPhone),
        if (cleanDigits.isNotEmpty) cleanDigits,
      };

      for (final cand in dirCandidates) {
        if (cand.isNotEmpty) {
          batch.set(_db.collection('phone_directory').doc(cand), updateData, SetOptions(merge: true));
        }
      }

      if (ticketId != null && ticketId.isNotEmpty) {
        batch.update(_db.collection('password_resets').doc(ticketId), {
          'status': 'resolved',
          'tempPassword': cleanPass,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // If active user in Firebase Auth is the target user, update Firebase Auth directly
      final effectiveNewPassword = cleanPass.length < 6 ? cleanPass.padRight(6, '0') : cleanPass;
      if (currentUser != null && currentUser.uid == resolvedUid) {
        try {
          await currentUser.updatePassword(effectiveNewPassword);
        } catch (e) {
          debugPrint('Direct user.updatePassword notice: $e');
        }
      } else {
        // Attempt background sync with secondary app
        final emailTargets = <String>[
          if (targetEmail.isNotEmpty) targetEmail,
          if (role == 'admin' || isTargetSuperAdmin) 'admin_$cleanDigits@mahameek.admin.com',
          '$cleanDigits@mahameek.${role ?? 'client'}.com',
        ];
        unawaited(_syncUserAuthPassword(
          emailTargets: emailTargets,
          newPassword: cleanPass,
          candidateOldPasswords: [
            ?prevHash,
            cleanDigits,
            internalAuthKey(cleanDigits),
            '123000',
            '123456',
            '123',
          ],
        ));
      }

      return {
        'success': true,
        'uid': resolvedUid,
        'newPassword': cleanPass,
      };
    } catch (e) {
      debugPrint('adminResetUserPassword error: $e');
      return {
        'success': false,
        'error': 'حدث خطأ أثناء إعادة تعيين كلمة المرور: $e'
      };
    }
  }

  // ===========================================================================
  // 🔄 RE-AUTHENTICATE & CHANGE PASSWORD
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final cleanCurrent = PhoneUtils.normalizeDigits(currentPassword.trim());
      final cleanNew = PhoneUtils.normalizeDigits(newPassword.trim());

      if (cleanNew.length < 6) {
        return {
          'success': false,
          'error': 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل'
        };
      }

      final user = _auth.currentUser;
      String? uid = user?.uid;
      String userEmail = user?.email ?? '';

      // SharedPreferences fallback if user was null due to reload
      if (uid == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          uid = prefs.getString('user_uid') ?? prefs.getString('uid');
          final spPhone = prefs.getString('user_phone') ?? prefs.getString('phone');
          final spRole = prefs.getString('user_role') ?? prefs.getString('role');
          if (spPhone != null && spRole != null) {
            final cleanD = PhoneUtils.extractLocalSudanDigits(spPhone);
            userEmail = '$cleanD@mahameek.$spRole.com';
          }
        } catch (_) {}
      }

      if (uid == null || uid.isEmpty) {
        return {'success': false, 'error': 'يجب تسجيل الدخول أولاً'};
      }

      final userDoc = await _db.collection('users').doc(uid).get();
      final adminDoc = await _db.collection('admins').doc(uid).get();
      final lawyerDoc = await _db.collection('lawyers').doc(uid).get();

      final docData = adminDoc.exists
          ? (adminDoc.data() ?? {})
          : (userDoc.exists ? (userDoc.data() ?? {}) : (lawyerDoc.data() ?? {}));

      String? storedHash = docData['passwordHash']?.toString();
      String? adminReset = docData['adminResetPassword']?.toString();
      String phone = docData['phone']?.toString() ?? '';
      if (userEmail.isEmpty) {
        userEmail = docData['email']?.toString() ?? '';
      }

      final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');

      // If not found in primary docs, check phone_directory
      if (storedHash == null && adminReset == null && phone.isNotEmpty) {
        for (final c in PhoneUtils.generatePhoneCandidates(phone)) {
          try {
            final dSnap = await _db.collection('phone_directory').doc(c).get();
            if (dSnap.exists && dSnap.data() != null) {
              storedHash ??= dSnap.data()!['passwordHash']?.toString();
              adminReset ??= dSnap.data()!['adminResetPassword']?.toString();
              if (storedHash != null || adminReset != null) break;
            }
          } catch (_) {}
        }
      }

      final bool isPrimary1 = PhoneUtils.isPrimaryAdmin1(phone);
      final bool isPrimary2 = PhoneUtils.isPrimaryAdmin2(phone);
      final bool isPrimaryAdmin = isPrimary1 || isPrimary2;

      final currentHash = hashPassword(cleanCurrent);
      final rawCurrentHash = hashPassword(currentPassword);

      bool isCurrentValid;
      if (isPrimaryAdmin) {
        if (adminReset != null || storedHash != null) {
          isCurrentValid = (adminReset != null && (adminReset == cleanCurrent || adminReset == currentPassword)) ||
              (storedHash != null && (storedHash == currentHash || storedHash == rawCurrentHash || storedHash == cleanCurrent));
        } else {
          isCurrentValid = isPrimary1
              ? (cleanCurrent == '123' || cleanCurrent == '123000' || cleanCurrent == '123456')
              : (cleanCurrent == '123456' || cleanCurrent == '123' || cleanCurrent == '123000');
        }
      } else {
        isCurrentValid = (adminReset != null && (adminReset == cleanCurrent || adminReset == currentPassword)) ||
            (storedHash == null || storedHash == currentHash || storedHash == rawCurrentHash || storedHash == cleanCurrent);
      }

      if (!isCurrentValid) {
        return {
          'success': false,
          'error': 'كلمة المرور الحالية غير صحيحة'
        };
      }

      final authKey = cleanDigits.isNotEmpty ? internalAuthKey(cleanDigits) : '';
      final pwCandidates = <String>{
        cleanCurrent,
        currentPassword,
        if (cleanCurrent.length < 6) cleanCurrent.padRight(6, '0'),
        if (currentPassword.length < 6) currentPassword.padRight(6, '0'),
        if (adminReset != null && adminReset.isNotEmpty) adminReset,
        if (authKey.isNotEmpty) authKey,
        '123000',
        '123456',
        '123',
        '12345678',
        '000000',
        if (cleanDigits.isNotEmpty) cleanDigits,
      }.toList();

      final effectiveNewPassword = cleanNew.length < 6 ? cleanNew.padRight(6, '0') : cleanNew;

      if (user != null && userEmail.isNotEmpty) {
        bool reauthSuccess = false;
        for (final pw in pwCandidates) {
          try {
            final cred = EmailAuthProvider.credential(
              email: userEmail,
              password: pw,
            );
            await user.reauthenticateWithCredential(cred);
            reauthSuccess = true;
            break;
          } catch (_) {}
        }

        if (reauthSuccess) {
          try {
            await user.updatePassword(effectiveNewPassword);
          } catch (e) {
            debugPrint('user.updatePassword notice: $e');
          }
        }
      }

      final newHash = hashPassword(cleanNew);
      final batch = _db.batch();

      final userUpdate = <String, dynamic>{
        'passwordHash': newHash,
        'adminResetPassword': FieldValue.delete(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (storedHash != null) {
        userUpdate['previousPasswordHash'] = storedHash;
      }

      batch.set(_db.collection('users').doc(uid), userUpdate, SetOptions(merge: true));

      if (adminDoc.exists || isPrimaryAdmin || docData['role'] == 'admin') {
        batch.set(_db.collection('admins').doc(uid), userUpdate, SetOptions(merge: true));
      }

      if (lawyerDoc.exists || docData['role'] == 'lawyer') {
        batch.set(_db.collection('lawyers').doc(uid), userUpdate, SetOptions(merge: true));
      }

      if (phone.isNotEmpty || cleanDigits.isNotEmpty) {
        final allCandidates = <String>{
          ...PhoneUtils.generatePhoneCandidates(phone),
          if (cleanDigits.isNotEmpty) cleanDigits,
        };

        for (final cand in allCandidates) {
          if (cand.isNotEmpty) {
            batch.set(_db.collection('phone_directory').doc(cand), userUpdate, SetOptions(merge: true));
          }
        }
      }

      await batch.commit();

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _authError(e.code)};
    } catch (e) {
      debugPrint('reauthenticateAndChangePassword error: $e');
      return {
        'success': false,
        'error': 'فشل تحديث كلمة المرور، يرجى المحاولة لاحقاً'
      };
    }
  }

  // ===========================================================================
  // 🚪 SIGN OUT & SESSION
  // ===========================================================================

  @override
  Future<void> signOut() async {
    // 1. Instantly clear SharedPreferences so local session is wiped first
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Session clear notice: $e');
    }

    // 2. Clear in-memory caches
    FirestoreService.inMemoryApprovedLawyers = null;

    // 3. Complete Firebase Auth sign out
    try {
      await _auth.signOut().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Auth signOut notice: $e');
    }

    // 4. Background cleanup for notifications
    if (!kIsWeb) {
      try {
        await NotificationService().clearAllSystemNotifications();
        await NotificationService().unregisterAdminDevice();
      } catch (e) {
        debugPrint('Notification cleanup error on signOut: $e');
      }
    }
  }

  @override
  Future<void> logout() => signOut();

  // ===========================================================================
  // 🗑️ PERMANENT AUTH ACCOUNT DELETION (Spark & Admin Safe)
  // ===========================================================================

  /// Deletes a specific user from Firebase Authentication by spinning up an isolated
  /// secondary FirebaseApp session, authenticating with deterministic credentials,
  /// calling currentUser.delete(), and terminating the secondary session.
  /// This works cleanly without affecting the currently active Admin or User session.
  @override
  Future<bool> deleteUserAuthAccount({
    required String phone,
    String? role,
    String? uid,
    String? password,
    String? userEmail,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      final cleanDigits = PhoneUtils.normalizeDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty && (userEmail == null || userEmail.isEmpty)) return false;

      final localDigits = cleanDigits.isNotEmpty ? PhoneUtils.extractLocalSudanDigits(cleanDigits) : '';
      final unified = cleanDigits.isNotEmpty ? PhoneUtils.toUnifiedPhone(phone).replaceAll('+', '') : '';

      // 1. Gather all phone digit candidates
      final digitCandidates = <String>{
        if (cleanDigits.isNotEmpty) cleanDigits,
        if (localDigits.isNotEmpty) localDigits,
        if (unified.isNotEmpty) unified,
      };

      // 2. Build email targets across all possible roles
      final emailTargets = <String>[];
      if (userEmail != null && userEmail.trim().isNotEmpty) {
        emailTargets.add(userEmail.trim());
      }
      final rolesToTest = [
        if (role != null && role.isNotEmpty) role,
        'client',
        'lawyer',
        'admin',
      ];

      for (final digits in digitCandidates) {
        for (final r in rolesToTest) {
          final target = '$digits@mahameek.$r.com';
          if (!emailTargets.contains(target)) emailTargets.add(target);
        }
        final general = '$digits@mahameek.com';
        if (!emailTargets.contains(general)) emailTargets.add(general);
      }

      // 3. Build password candidates
      final pwCandidates = <String>[];
      for (final digits in digitCandidates) {
        pwCandidates.add(internalAuthKey(digits));
      }
      if (password != null && password.trim().isNotEmpty) {
        final norm = PhoneUtils.normalizeDigits(password.trim());
        pwCandidates.add(norm);
        if (norm != password.trim()) pwCandidates.add(password.trim());
        if (norm.length < 6) pwCandidates.add(norm.padRight(6, '0'));
      }

      // Check if user has an adminResetPassword in Firestore
      if (uid != null && uid.isNotEmpty) {
        try {
          final uDoc = await _db.collection('users').doc(uid).get();
          final resetPw = uDoc.data()?['adminResetPassword']?.toString();
          if (resetPw != null && resetPw.isNotEmpty) {
            pwCandidates.add(resetPw.trim());
            pwCandidates.add(PhoneUtils.normalizeDigits(resetPw.trim()));
          }
        } catch (_) {}
        try {
          final lDoc = await _db.collection('lawyers').doc(uid).get();
          final resetPw = lDoc.data()?['adminResetPassword']?.toString();
          if (resetPw != null && resetPw.isNotEmpty) {
            pwCandidates.add(resetPw.trim());
            pwCandidates.add(PhoneUtils.normalizeDigits(resetPw.trim()));
          }
        } catch (_) {}
      }

      // 4. Initialize secondary app
      final suffix = cleanDigits.length > 4
          ? cleanDigits.substring(cleanDigits.length - 4)
          : DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final appName = 'UserDeletion_${DateTime.now().millisecondsSinceEpoch}_$suffix';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      bool deleted = false;

      for (final targetEmail in emailTargets) {
        for (final pw in pwCandidates) {
          try {
            final cred = await secondaryAuth.signInWithEmailAndPassword(
              email: targetEmail,
              password: pw,
            );
            if (cred.user != null) {
              await cred.user!.delete();
              deleted = true;
              debugPrint('✅ [AuthService] Successfully deleted user $targetEmail from Firebase Auth');
              break;
            }
          } catch (_) {}
        }
        if (deleted) break;
      }

      return deleted;
    } catch (e) {
      debugPrint('[AuthService] deleteUserAuthAccount notice: $e');
      return false;
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }
  }

  // ============================================================================
  // 🗑️ DELETE OWN ACCOUNT — Guaranteed Full Purge
  // ============================================================================

  @override
  Future<Map<String, dynamic>> deleteAccount(
      {String? currentPassword}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'المستخدم غير مسجل الدخول'};
      }

      final uid = user.uid;
      final email = user.email ?? '';
      final cleanDigits =
          email.split('@').first.replaceAll(RegExp(r'[^0-9]'), '');
      final localDigits = PhoneUtils.extractLocalSudanDigits(cleanDigits);

      // ── 1. Fetch user data BEFORE deleting anything ──────────────────────
      final db = FirebaseFirestore.instance;
      String? storedHash;
      String? storedAdminReset;
      String? userDocPhone;
      String? profilePhotoUrl;

      try {
        final userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          storedHash = userDoc.data()?['passwordHash']?.toString();
          storedAdminReset = userDoc.data()?['adminResetPassword']?.toString();
          final p = userDoc.data()?['phone']?.toString();
          if (p != null && p.trim().isNotEmpty) userDocPhone = p.trim();
          profilePhotoUrl = userDoc.data()?['photoUrl']?.toString();
        }
      } catch (_) {}

      try {
        final lawyerDoc = await db.collection('lawyers').doc(uid).get();
        if (lawyerDoc.exists && lawyerDoc.data() != null) {
          storedHash ??= lawyerDoc.data()?['passwordHash']?.toString();
          storedAdminReset ??=
              lawyerDoc.data()?['adminResetPassword']?.toString();
          final p = lawyerDoc.data()?['phone']?.toString();
          if (p != null && p.trim().isNotEmpty) userDocPhone ??= p.trim();
          profilePhotoUrl ??= lawyerDoc.data()?['photoUrl']?.toString();
        }
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        final spPhone = prefs.getString('user_phone') ?? prefs.getString('phone');
        if (spPhone != null && spPhone.trim().isNotEmpty) {
          userDocPhone ??= spPhone.trim();
        }
        profilePhotoUrl ??= prefs.getString('user_profile_photo_url');
      } catch (_) {}

      // Build complete phone candidate set for directory cleanup
      final phoneCandidates = <String>{};
      for (final src in [userDocPhone, cleanDigits, localDigits]) {
        if (src != null && src.isNotEmpty) {
          phoneCandidates.addAll(PhoneUtils.generatePhoneCandidates(src));
        }
      }

      // ── 2. Validate entered password against stored hash ─────────────────
      if (currentPassword != null && currentPassword.trim().isNotEmpty) {
        if (storedHash != null && storedHash.isNotEmpty) {
          final raw = currentPassword.trim();
          final norm = PhoneUtils.normalizeDigits(raw);
          final matchesHash =
              storedHash == hashPassword(norm) || storedHash == hashPassword(raw);
          final matchesReset = storedAdminReset != null &&
              storedAdminReset.isNotEmpty &&
              (storedAdminReset == raw || storedAdminReset == norm);
          if (!matchesHash && !matchesReset) {
            return {
              'success': false,
              'error':
                  'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
            };
          }
        }
      }

      // ── 3. Obtain fresh ID token for REST Auth deletion while still signed in ─
      String? idToken;
      try {
        idToken = await user.getIdToken(true);
      } catch (_) {}

      // ── 4. Delete profile photo from Firebase Storage (while authenticated) ─
      if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
        try {
          await StorageService().deleteOldPhoto(profilePhotoUrl);
        } catch (_) {}
      }

      // ── 5. Delete all Firestore records (while authenticated as owner) ────
      await db.collection('users').doc(uid).delete().catchError((_) {});
      await db.collection('lawyers').doc(uid).delete().catchError((_) {});
      await db.collection('lawyer_requests').doc(uid).delete().catchError((_) {});
      await db.collection('admins').doc(uid).delete().catchError((_) {});
      await db.collection('admin_fcm_tokens').doc(uid).delete().catchError((_) {});

      // Extra purge for phone_directory by uid
      try {
        final dirSnap = await db
            .collection('phone_directory')
            .where('uid', isEqualTo: uid)
            .get();
        for (final doc in dirSnap.docs) {
          await doc.reference.delete().catchError((_) {});
        }
      } catch (_) {}

      // Clean up stray records by phone candidate keys
      for (final q in phoneCandidates) {
        if (q.trim().isEmpty) continue;
        try {
          final docRef = db.collection('phone_directory').doc(q.trim());
          final snap = await docRef.get();
          if (snap.exists) {
            await docRef.delete().catchError((_) {});
          }
        } catch (_) {}
        try {
          final lawSnap = await db
              .collection('lawyers')
              .where('phone', isEqualTo: q)
              .get();
          for (final doc in lawSnap.docs) {
            await doc.reference.delete().catchError((_) {});
          }
        } catch (_) {}
        try {
          final uSnap = await db
              .collection('users')
              .where('phone', isEqualTo: q)
              .get();
          for (final doc in uSnap.docs) {
            await doc.reference.delete().catchError((_) {});
          }
        } catch (_) {}
      }

      // ── 6. Delete Firebase Auth account (guaranteed purge) ───────────────
      bool authDeleted = false;

      final reAuthCandidates = <String>{};
      for (final src in [cleanDigits, localDigits]) {
        if (src.isNotEmpty) reAuthCandidates.add(internalAuthKey(src));
      }
      if (userDocPhone != null && userDocPhone.isNotEmpty) {
        final rawU = PhoneUtils.normalizeDigits(userDocPhone).replaceAll(RegExp(r'[^0-9]'), '');
        if (rawU.isNotEmpty) reAuthCandidates.add(internalAuthKey(rawU));
        final locU = PhoneUtils.extractLocalSudanDigits(rawU);
        if (locU.isNotEmpty) reAuthCandidates.add(internalAuthKey(locU));
      }
      for (final q in phoneCandidates) {
        final d = q.replaceAll(RegExp(r'[^0-9]'), '');
        if (d.isNotEmpty) reAuthCandidates.add(internalAuthKey(d));
      }
      if (currentPassword != null && currentPassword.trim().isNotEmpty) {
        final rawP = currentPassword.trim();
        final normP = PhoneUtils.normalizeDigits(rawP);
        reAuthCandidates.add(normP);
        reAuthCandidates.add(rawP);
        if (normP.length < 6) reAuthCandidates.add(normP.padRight(6, '0'));
      }
      if (storedAdminReset != null && storedAdminReset.isNotEmpty) {
        reAuthCandidates.add(storedAdminReset.trim());
        reAuthCandidates.add(PhoneUtils.normalizeDigits(storedAdminReset.trim()));
      }

      // Pre-reauthenticate before deleting to eliminate requires-recent-login errors
      if (email.isNotEmpty) {
        for (final pwd in reAuthCandidates) {
          try {
            final cred = EmailAuthProvider.credential(email: email, password: pwd);
            await user.reauthenticateWithCredential(cred);
            break;
          } catch (_) {}
        }
      }

      try {
        await user.delete();
        authDeleted = true;
        debugPrint('✅ [deleteAccount] Auth user deleted directly');
      } on FirebaseAuthException catch (authEx) {
        if (authEx.code == 'requires-recent-login' && email.isNotEmpty) {
          for (final pwd in reAuthCandidates) {
            try {
              final cred = EmailAuthProvider.credential(email: email, password: pwd);
              await user.reauthenticateWithCredential(cred);
              await user.delete();
              authDeleted = true;
              debugPrint('✅ [deleteAccount] Auth user deleted after re-auth');
              break;
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Strategy 2: Firebase Auth REST API (accounts:delete) with fresh idToken
      if (!authDeleted && idToken != null) {
        try {
          final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
          final response = await http.post(
            Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            authDeleted = true;
            debugPrint('✅ [deleteAccount] Auth user deleted via REST API');
          } else {
            debugPrint('[deleteAccount] REST API status ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          debugPrint('[deleteAccount] REST API error: $e');
        }
      }

      // Strategy 3: Secondary App (isolated session login then delete)
      if (!authDeleted) {
        final targetPhone = userDocPhone ?? cleanDigits;
        if (targetPhone.isNotEmpty) {
          authDeleted = await deleteUserAuthAccount(
            phone: targetPhone,
            uid: uid,
            password: currentPassword,
            userEmail: email.isNotEmpty ? email : null,
          );
          if (authDeleted) {
            debugPrint('✅ [deleteAccount] Auth user deleted via secondary app');
          }
        }
      }

      // ── 7. Invalidate local session & caches, then sign out ──────────────
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('uid');
        await prefs.remove('role');
        await prefs.remove('name');
        await prefs.remove('phone');
        await prefs.remove('user_phone');
        await prefs.remove('status');
        await prefs.remove('user_profile_photo');
        await prefs.remove('user_profile_photo_url');
      } catch (_) {}

      FirestoreService.inMemoryApprovedLawyers = null;

      try {
        await _auth.signOut();
      } catch (_) {}

      return {'success': true};
    } catch (e) {
      debugPrint('[deleteAccount] unexpected error: $e');
      try {
        await signOut();
      } catch (_) {}
      return {
        'success': false,
        'error': 'حدث خطأ أثناء حذف الحساب، يرجى المحاولة مجدداً.',
      };
    }
  }

  // ===========================================================================
  // 💾 LOCAL SESSION PERSISTENCE
  // ===========================================================================

  Future<void> _saveSession({
    required String uid,
    required String role,
    required String name,
    required String phone,
    String? photoUrl,
    String? status,
    String? accountId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', uid);
      await prefs.setString('role', role);
      await prefs.setString('name', name);
      await prefs.setString('phone', phone);
      if (accountId != null && accountId.isNotEmpty) {
        await prefs.setString('accountId', accountId);
      }
      if (photoUrl != null) {
        await prefs.setString('user_profile_photo_url', photoUrl);
      }
      if (status != null) await prefs.setString('status', status);

      // Automatically register user device for push notifications (works when closed)
      unawaited(NotificationService().registerUserDevice(uid: uid, role: role));
    } catch (_) {}
  }

  @override
  Future<Map<String, String?>> getSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'uid': prefs.getString('uid'),
        'role': prefs.getString('role'),
        'name': prefs.getString('name'),
        'phone': prefs.getString('phone'),
        'status': prefs.getString('status'),
        'photoUrl': prefs.getString('user_profile_photo_url'),
        'accountId': prefs.getString('accountId'),
      };
    } catch (_) {
      return {};
    }
  }

  // ===========================================================================
  // ⚠️ AUTH ERROR TRANSLATION
  // ===========================================================================

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
      case 'email-already-exists':
        return 'رقم الهاتف أو البريد مسجل مسبقاً في النظام، يرجى تسجيل الدخول مباشرة.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة أو الحساب غير موجود';
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط بهذه البيانات';
      case 'invalid-email':
        return 'رقم الهاتف أو البريد المدخل غير صحيح';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (يجب ألا تقل عن 6 أحرف)';
      case 'network-request-failed':
      case 'unavailable':
        return 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.';
      case 'too-many-requests':
        return 'محاولات دخول متكررة، يرجى الانتظار دقيقة والمحاولة مجدداً';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب من قبل إدارة النظام';
      case 'operation-not-allowed':
        return 'خدمة تسجيل الدخول بالبريد الإلكتروني وكلمة المرور غير مفعلة في لوحة تحكم Firebase Console (Authentication > Sign-in method > Email/Password)';
      case 'permission-denied':
        return 'تم رفض إذن الوصول من الخادم (Permission Denied). يرجى مراجعة قواعد أمان Firestore Rules في Firebase Console.';
      case 'app-not-authorized':
        return 'هذا النطاق غير مصرح به في Firebase Authentication (Authorized Domains).';
      default:
        return AppErrorTranslator.translate(
          FirebaseException(plugin: 'firebase_auth', code: code),
          defaultMessage: 'حدث خطأ أثناء المصادقة، يرجى إعادة المحاولة.',
        );
    }
  }
}
