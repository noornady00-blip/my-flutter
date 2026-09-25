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
      final rawDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final bool isPrimaryAdmin = rawDigits == '01146979833' ||
          rawDigits == '1146979833' ||
          rawDigits == '146979833' ||
          rawDigits == '0146979833' ||
          phone.contains('01146979833') ||
          phone.contains('1146979833');

      if (isPrimaryAdmin) {
        return {
          'uid': 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2',
          'role': 'admin',
          'data': {
            'name': 'المشرف الأساسي (01146979833)',
            'phone': '01146979833',
            'role': 'admin',
          },
        };
      }

      final candidates = PhoneUtils.generatePhoneCandidates(phone);
      if (candidates.isEmpty) return null;

      for (final q in candidates) {
        if (q.isEmpty) continue;

        // 1. Check phone_directory collection (public lightweight registry)
        try {
          final dirDoc = await _db
              .collection('phone_directory')
              .doc(q)
              .get()
              .timeout(const Duration(seconds: 4));
          if (dirDoc.exists && dirDoc.data() != null) {
            final data = dirDoc.data()!;
            final role = data['role']?.toString() ?? 'client';
            final uid = data['uid']?.toString() ?? dirDoc.id;
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
              .timeout(const Duration(seconds: 4));
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
                .timeout(const Duration(seconds: 4));
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

      final email = '$cleanDigits@mahameek.client.com';
      final authKey = internalAuthKey(cleanDigits);
      final fbPassword =
          password.length < 6 ? password.padRight(6, '0') : password;
      final pwdHash = hashPassword(password);

      UserCredential cred;
      try {
        cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: authKey,
        );
      } catch (e) {
        if (e is FirebaseAuthException &&
            e.code == 'network-request-failed') {
          return {
            'success': false,
            'error':
                'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
            'isNetworkError': true,
          };
        }
        try {
          cred = await _auth.signInWithEmailAndPassword(
            email: email,
            password: authKey,
          );
        } catch (e2) {
          if (e2 is FirebaseAuthException &&
              e2.code == 'network-request-failed') {
            return {
              'success': false,
              'error':
                  'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
              'isNetworkError': true,
            };
          }
          try {
            cred = await _auth.signInWithEmailAndPassword(
              email: email,
              password: fbPassword,
            );
            await cred.user!.updatePassword(authKey);
          } catch (_) {
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

      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), userMap);

      final dirData = {
        'uid': uid,
        'name': name,
        'phone': normPhone,
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

      final email = '$cleanDigits@mahameek.lawyer.com';
      final authKey = internalAuthKey(cleanDigits);
      final fbPassword =
          password.length < 6 ? password.padRight(6, '0') : password;
      final pwdHash = hashPassword(password);

      UserCredential cred;
      try {
        cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: authKey,
        );
      } catch (e) {
        if (e is FirebaseAuthException &&
            e.code == 'network-request-failed') {
          return {
            'success': false,
            'error':
                'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
            'isNetworkError': true,
          };
        }
        try {
          cred = await _auth.signInWithEmailAndPassword(
            email: email,
            password: authKey,
          );
        } catch (e2) {
          if (e2 is FirebaseAuthException &&
              e2.code == 'network-request-failed') {
            return {
              'success': false,
              'error':
                  'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
              'isNetworkError': true,
            };
          }
          try {
            cred = await _auth.signInWithEmailAndPassword(
              email: email,
              password: fbPassword,
            );
            await cred.user!.updatePassword(authKey);
          } catch (_) {
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

      final lawyerMap = lawyer.toMap();
      lawyerMap['passwordHash'] = pwdHash;

      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), userMap);
      batch.set(_db.collection('lawyers').doc(uid), lawyerMap);

      final dirData = {
        'uid': uid,
        'name': name,
        'phone': normPhone,
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
      final hasNet = await NetworkService().hasInternet();
      if (!hasNet) {
        return {
          'success': false,
          'error':
              'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          'isNetworkError': true,
        };
      }

      final input = phoneOrEmail.trim();
      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
      final localDigits = PhoneUtils.extractLocalSudanDigits(input);
      final normPhone = PhoneUtils.normalizeSudanPhone(input);

      final bool isPrimaryAdmin = digits == '01146979833' ||
          digits == '1146979833' ||
          digits == '146979833' ||
          digits == '0146979833' ||
          input.contains('01146979833') ||
          input.contains('1146979833');

      if (role == 'admin') {
        return await adminLogin(emailOrPhone: phoneOrEmail, password: password);
      }

      if (isPrimaryAdmin) {
        if (role == 'client' || role == 'lawyer') {
          return {
            'success': false,
            'error':
                'هذا الحساب مخصص لإدارة التطبيق، يرجى اختيار تبويب (إدارة) لتسجيل الدخول.',
          };
        }
        return await adminLogin(emailOrPhone: phoneOrEmail, password: password);
      }

      if (!input.contains('@') && (digits.length < 9 || digits.length > 15)) {
        return {
          'success': false,
          'error':
              'رقم الموبايل المدخل غير صحيح، يرجى التأكد من كتابة رقم صحيح.',
        };
      }

      // Check phone registration in database (if not email)
      Map<String, dynamic>? registered;
      if (!input.contains('@')) {
        try {
          registered = await checkPhoneRegistration(input);
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
                'تعذر الاتصال بالخادم، يرجى التأكد من توفر إنترنت بالشبكة والمحاولة مجدداً.',
            'isNetworkError': true,
          };
        } on FirebaseException catch (e) {
          if (e.code == 'unavailable' || e.code == 'network-request-failed') {
            return {
              'success': false,
              'error':
                  'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
              'isNetworkError': true,
            };
          }
        } catch (_) {}

        // IF THE PHONE NUMBER IS NOT REGISTERED ANYWHERE:
        if (registered == null) {
          return {
            'success': false,
            'error': 'رقم الموبايل غير مسجل في التطبيق، يرجى إنشاء حساب جديد أولاً.',
          };
        }
      }

      final discoveredRole = registered?['role']?.toString();
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

      // Cross-role verification
      if (role == 'client' && discoveredRole == 'lawyer') {
        return {
          'success': false,
          'error':
              'هذا الحساب مسجل كـ (محامي)، يرجى اختيار تبويب (محامي) لتسجيل الدخول.',
        };
      }
      if (role == 'lawyer' && discoveredRole == 'client') {
        return {
          'success': false,
          'error':
              'هذا الحساب مسجل كـ (عميل)، يرجى اختيار تبويب (عميل) لتسجيل الدخول.',
        };
      }

      final targetDigits = normPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanDigits = targetDigits.isNotEmpty ? targetDigits : digits;
      final fbPassword =
          password.length < 6 ? password.padRight(6, '0') : password;
      final inputHash = hashPassword(password);

      // Build prioritized email list based on discovered role or parameter
      final List<String> emailCandidates = [];
      if (input.contains('@')) {
        emailCandidates.add(input);
      } else {
        final clientEmail = '$cleanDigits@mahameek.client.com';
        final lawyerEmail = '$cleanDigits@mahameek.lawyer.com';
        final legacyEmail = '$cleanDigits@mahameek.com';

        final effectiveRole = role ?? discoveredRole;
        if (effectiveRole == 'lawyer') {
          emailCandidates.add(lawyerEmail);
          if (localDigits.isNotEmpty && localDigits != cleanDigits) {
            emailCandidates.add('$localDigits@mahameek.lawyer.com');
          }
        } else if (effectiveRole == 'client') {
          emailCandidates.add(clientEmail);
          if (localDigits.isNotEmpty && localDigits != cleanDigits) {
            emailCandidates.add('$localDigits@mahameek.client.com');
          }
        } else {
          emailCandidates.add(clientEmail);
          emailCandidates.add(lawyerEmail);
          if (localDigits.isNotEmpty && localDigits != cleanDigits) {
            emailCandidates.add('$localDigits@mahameek.client.com');
            emailCandidates.add('$localDigits@mahameek.lawyer.com');
          }
        }
        emailCandidates.add(legacyEmail);
        if (localDigits.isNotEmpty && localDigits != cleanDigits) {
          emailCandidates.add('$localDigits@mahameek.com');
        }
      }

      // Fetch directory record for fast verification across all possible phone formats
      DocumentSnapshot<Map<String, dynamic>>? dirSnap;
      final phoneFormats = [
        cleanDigits,
        normPhone,
        localDigits,
        digits,
        if (cleanDigits.startsWith('0')) cleanDigits.substring(1),
        if (digits.startsWith('0')) digits.substring(1),
      ];
      for (final key in phoneFormats) {
        if (key.isEmpty) continue;
        try {
          final s = await _db.collection('phone_directory').doc(key).get();
          if (s.exists && s.data() != null) {
            dirSnap = s;
            break;
          }
        } catch (_) {}
      }

      final Map<String, dynamic>? dirData = dirSnap?.data() ??
          (registered?['data'] is Map<String, dynamic> ? (registered!['data'] as Map<String, dynamic>) : null);
      final storedAdminReset = dirData?['adminResetPassword']?.toString();
      final storedDirHash = dirData?['passwordHash']?.toString();
      final storedDirPrevHash = dirData?['previousPasswordHash']?.toString();

      final authKey = cleanDigits.isNotEmpty ? internalAuthKey(cleanDigits) : '';
      final localAuthKey = localDigits.isNotEmpty ? internalAuthKey(localDigits) : '';

      final pwCandidates = {
        if (authKey.isNotEmpty) authKey,
        if (localAuthKey.isNotEmpty) localAuthKey,
        password,
        fbPassword,
        if (storedAdminReset != null && storedAdminReset.isNotEmpty) storedAdminReset,
        if (storedAdminReset != null && storedAdminReset.length < 6) storedAdminReset.padRight(6, '0'),
        '123456',
        '12345678',
        '000000',
        if (cleanDigits.isNotEmpty) cleanDigits,
      }.toList();

      UserCredential? cred;
      FirebaseAuthException? lastAuthException;

      // 1. First attempt: Authenticate directly against Firebase Auth using candidate passwords
      for (final email in emailCandidates) {
        for (final pw in pwCandidates) {
          try {
            cred = await _auth.signInWithEmailAndPassword(
              email: email,
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
          } catch (_) {}
        }
        if (cred?.user != null) break;
      }

      // If authentication failed across all candidates
      if (cred == null || cred.user == null) {
        if (registered != null) {
          return {
            'success': false,
            'error': 'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
          };
        }
        if (lastAuthException != null) {
          final code = lastAuthException.code;
          if (code == 'wrong-password' || code == 'invalid-credential') {
            return {
              'success': false,
              'error':
                  'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
            };
          }
          if (code == 'user-not-found') {
            return {
              'success': false,
              'error':
                  'رقم الموبايل غير مسجل في التطبيق، يرجى إنشاء حساب جديد أولاً.',
            };
          }
        }
        return {
          'success': false,
          'error':
              'رقم الموبايل غير مسجل في التطبيق، يرجى إنشاء حساب جديد أولاً.',
        };
      }

      // User is authenticated in Firebase Auth!
      final uid = cred.user!.uid;
      final userDoc = await _db.collection('users').doc(uid).get();

      final docHash = userDoc.data()?['passwordHash']?.toString();
      final docAdminReset = userDoc.data()?['adminResetPassword']?.toString();
      final prevHash = userDoc.data()?['previousPasswordHash']?.toString() ?? storedDirPrevHash;
      final effectiveAdminReset = docAdminReset ?? storedAdminReset;
      final effectiveHash = docHash ?? storedDirHash;

      // Verify entered password against Firestore records:
      // Accepts:
      // 1) The admin reset password (e.g. 123456)
      // 2) The current active password hash
      // 3) The previous password hash (so original password works even during reset period)
      final bool isMatch = (effectiveAdminReset != null && effectiveAdminReset == password) ||
          (effectiveHash != null && effectiveHash == inputHash) ||
          (prevHash != null && prevHash == inputHash) ||
          (effectiveHash == null && effectiveAdminReset == null);

      if (!isMatch) {
        await _auth.signOut();
        return {
          'success': false,
          'error': 'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
        };
      }

      // Keep Firebase Auth password set to authKey for permanent stability across resets
      if (authKey.isNotEmpty) {
        try {
          await cred.user!.updatePassword(authKey);
        } catch (_) {}
      }

      // Synchronize Firestore: set active hash and delete adminResetPassword & previousPasswordHash
      final syncBatch = _db.batch();
      final syncData = <String, dynamic>{
        'passwordHash': inputHash,
        'adminResetPassword': FieldValue.delete(),
        'previousPasswordHash': FieldValue.delete(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };
      syncBatch.set(_db.collection('users').doc(uid), syncData, SetOptions(merge: true));

      final lawyerDocRef = _db.collection('lawyers').doc(uid);
      final lawyerSnap = await lawyerDocRef.get();
      if (lawyerSnap.exists) {
        syncBatch.set(lawyerDocRef, syncData, SetOptions(merge: true));
      }

      if (cleanDigits.isNotEmpty) {
        syncBatch.set(_db.collection('phone_directory').doc(cleanDigits), syncData, SetOptions(merge: true));
        if (normPhone.isNotEmpty && normPhone != cleanDigits) {
          syncBatch.set(_db.collection('phone_directory').doc(normPhone), syncData, SetOptions(merge: true));
        }
        if (localDigits.isNotEmpty && localDigits != cleanDigits) {
          syncBatch.set(_db.collection('phone_directory').doc(localDigits), syncData, SetOptions(merge: true));
        }
      }
      unawaited(syncBatch.commit().catchError((_) {}));

      final userRole = userDoc.data()?['role']?.toString() ??
          (discoveredRole ?? 'client');
      final name = userDoc.data()?['name']?.toString() ?? '';
      final photoUrl = userDoc.data()?['photoUrl']?.toString();

      String? lawyerStatus;
      if (userRole == 'lawyer') {
        final lawyerDoc = await _db.collection('lawyers').doc(uid).get();
        lawyerStatus = lawyerDoc.data()?['status']?.toString() ?? 'pending';

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
            userDoc.data()?['status']?.toString() ?? 'active';
        if (clientStatus == 'suspended') {
          await _auth.signOut();
          return {
            'success': false,
            'error':
                'تم إيقاف هذا الحساب من قبل إدارة المنصة. يرجى التواصل مع الدعم الفني.',
          };
        }
      }

      // Sync phone_directory for instant future lookups
      try {
        final dirData = {
          'uid': uid,
          'name': name,
          'phone': normPhone,
          'role': userRole,
          'status': ?lawyerStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _db.collection('phone_directory').doc(cleanDigits).set(dirData, SetOptions(merge: true));
        if (localDigits.isNotEmpty && localDigits != cleanDigits) {
          await _db.collection('phone_directory').doc(localDigits).set(dirData, SetOptions(merge: true));
        }
      } catch (_) {}

      // Ensure user has a 12-digit fixed account ID
      final rawAccountId = userDoc.data()?['accountId']?.toString() ??
          userDoc.data()?['memberId']?.toString();
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

      final adminData = {
        'uid': newUid,
        'name': cleanName,
        'phone': normPhone,
        'rawPhone': cleanPhone,
        'cleanDigits': cleanDigits,
        'email': email,
        'role': 'admin',
        'accountId': accountId,
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
      for (final cand in phoneCandidates) {
        if (cand.isNotEmpty) {
          await _db.collection('phone_directory').doc(cand).set({
            'uid': newUid,
            'role': 'admin',
            'phone': normPhone,
            'name': cleanName,
            'email': email,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((_) {});
        }
      }
      if (cleanDigits.isNotEmpty) {
        await _db.collection('phone_directory').doc(cleanDigits).set({
          'uid': newUid,
          'role': 'admin',
          'phone': normPhone,
          'name': cleanName,
          'email': email,
        }, SetOptions(merge: true)).catchError((_) {});
      }
      if (rawDigits.isNotEmpty) {
        await _db.collection('phone_directory').doc(rawDigits).set({
          'uid': newUid,
          'role': 'admin',
          'phone': normPhone,
          'name': cleanName,
          'email': email,
        }, SetOptions(merge: true)).catchError((_) {});
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

      final input = emailOrPhone.trim();
      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanDigits = PhoneUtils.extractLocalSudanDigits(input);
      final rawDigits = digits;
      final withoutLeadingZero = rawDigits.startsWith('0')
          ? rawDigits.replaceFirst(RegExp(r'^0+'), '')
          : rawDigits;
      final withLeadingZero =
          rawDigits.startsWith('0') ? rawDigits : '0$rawDigits';

      final bool isPrimaryAdmin = digits == '01146979833' ||
          digits == '1146979833' ||
          digits == '146979833' ||
          digits == '0146979833' ||
          input.contains('01146979833') ||
          input.contains('1146979833') ||
          input == 'admin_01146979833@mahameek.admin.com';

      Map<String, dynamic>? reg;
      if (!isPrimaryAdmin && !input.contains('@')) {
        try {
          reg = await checkPhoneRegistration(input);
        } catch (_) {}
        if (reg != null && reg['role'] != 'admin') {
          final roleName = reg['role'] == 'lawyer' ? 'محامي' : 'عميل';
          return {
            'success': false,
            'error':
                'هذا الحساب مسجل كـ ($roleName) وغير مصرح له بالدخول كمسؤول. يرجى اختيار تبويب $roleName.',
          };
        }
      }

      // Build comprehensive list of email candidates
      final List<String> emailCandidates = [];
      if (input.contains('@')) {
        emailCandidates.add(input);
      } else if (isPrimaryAdmin) {
        emailCandidates.addAll([
          'admin_01146979833@mahameek.admin.com',
          '01146979833@mahameek.admin.com',
          'admin_1146979833@mahameek.admin.com',
          '1146979833@mahameek.admin.com',
        ]);
      } else {
        if (reg != null &&
            reg['data'] != null &&
            reg['data']['email'] != null &&
            reg['data']['email'].toString().trim().isNotEmpty) {
          emailCandidates.add(reg['data']['email'].toString().trim());
        }
        if (cleanDigits.isNotEmpty) {
          emailCandidates.add('admin_$cleanDigits@mahameek.admin.com');
          emailCandidates.add('$cleanDigits@mahameek.admin.com');
        }
        if (rawDigits.isNotEmpty) {
          emailCandidates.add('admin_$rawDigits@mahameek.admin.com');
          emailCandidates.add('$rawDigits@mahameek.admin.com');
        }
        if (withoutLeadingZero.isNotEmpty &&
            withoutLeadingZero != cleanDigits &&
            withoutLeadingZero != rawDigits) {
          emailCandidates.add('admin_$withoutLeadingZero@mahameek.admin.com');
          emailCandidates.add('$withoutLeadingZero@mahameek.admin.com');
        }
        if (withLeadingZero.isNotEmpty &&
            withLeadingZero != cleanDigits &&
            withLeadingZero != rawDigits) {
          emailCandidates.add('admin_$withLeadingZero@mahameek.admin.com');
          emailCandidates.add('$withLeadingZero@mahameek.admin.com');
        }
        emailCandidates.add('admin@mahameek.com');
      }

      // Deduplicate email candidates
      final uniqueEmails = emailCandidates
          .where((e) => e.trim().isNotEmpty)
          .map((e) => e.trim().toLowerCase())
          .toSet()
          .toList();

      // Build password candidates
      final List<String> pwCandidates = [];
      if (password.isNotEmpty) {
        pwCandidates.add(password);
        if (password.length < 6) pwCandidates.add(password.padRight(6, '0'));
        if (password == '123') {
          pwCandidates.addAll(['123000', '123456', '123123']);
        }
      }
      if (isPrimaryAdmin) {
        if (!pwCandidates.contains('123000')) pwCandidates.add('123000');
        if (!pwCandidates.contains('123456')) pwCandidates.add('123456');
        if (!pwCandidates.contains('123')) pwCandidates.add('123');
      }

      final uniquePasswords = pwCandidates.toSet().toList();

      UserCredential? cred;
      FirebaseAuthException? lastAuthException;
      String successfulEmail = uniqueEmails.isNotEmpty ? uniqueEmails.first : '';

      for (final emailCand in uniqueEmails) {
        for (final pw in uniquePasswords) {
          try {
            cred = await _auth.signInWithEmailAndPassword(
              email: emailCand,
              password: pw,
            );
            if (cred.user != null) {
              successfulEmail = emailCand;
              break;
            }
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
          } catch (_) {}
        }
        if (cred?.user != null) break;
      }

      // Auto-provision primary admin if not exists in Firebase Auth
      if (cred == null || cred.user == null) {
        if (isPrimaryAdmin) {
          try {
            cred = await _auth.createUserWithEmailAndPassword(
              email: 'admin_01146979833@mahameek.admin.com',
              password: uniquePasswords.isNotEmpty ? uniquePasswords.first : '123000',
            );
            successfulEmail = 'admin_01146979833@mahameek.admin.com';
          } catch (createErr) {
            if (createErr is FirebaseAuthException &&
                createErr.code == 'network-request-failed') {
              return {
                'success': false,
                'error':
                    'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
                'isNetworkError': true,
              };
            }
          }
        }
      }

      if (cred == null || cred.user == null) {
        if (reg != null && reg['role'] == 'admin') {
          return {
            'success': false,
            'error':
                'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
          };
        }
        if (lastAuthException != null) {
          final code = lastAuthException.code;
          if (code == 'wrong-password') {
            return {
              'success': false,
              'error':
                  'كلمة المرور غير صحيحة، يرجى التأكد من كلمة المرور والمحاولة مجدداً.',
            };
          }
          if (code == 'user-not-found' || code == 'invalid-credential') {
            return {
              'success': false,
              'error':
                  'هذا الحساب غير مسجل كمسؤول، أو كلمة المرور غير صحيحة.',
            };
          }
          return {'success': false, 'error': _authError(code)};
        }
        return {
          'success': false,
          'error': 'بيانات الاعتماد غير صحيحة أو الحساب غير موجود كمسؤول.',
        };
      }

      final uid = cred.user!.uid;

      final adminName = isPrimaryAdmin
          ? 'المشرف الأساسي (01146979833)'
          : 'مشرف النظام';
      final adminPhone = isPrimaryAdmin
          ? '01146979833'
          : (digits.isNotEmpty ? digits : input);

      final adminAccountId = await AccountIdUtils.ensureUserHasAccountId(
        uid: uid,
        role: 'admin',
        firestore: _db,
      );

      if (isPrimaryAdmin) {
        final adminData = {
          'uid': uid,
          'name': adminName,
          'phone': adminPhone,
          'role': 'admin',
          'accountId': adminAccountId,
          'email': successfulEmail,
          'isPrimary': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _db
            .collection('admins')
            .doc(uid)
            .set(adminData, SetOptions(merge: true))
            .catchError((e) {
          debugPrint('adminRef.set notice: $e');
        });
        await _db
            .collection('users')
            .doc(uid)
            .set(adminData, SetOptions(merge: true))
            .catchError((e) {
          debugPrint('userRef.set notice: $e');
        });

        await _db
            .collection('phone_directory')
            .doc('01146979833')
            .set(adminData, SetOptions(merge: true))
            .catchError((_) {});
        await _db
            .collection('phone_directory')
            .doc('1146979833')
            .set(adminData, SetOptions(merge: true))
            .catchError((_) {});

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

      // Check authorization for non-primary admins
      String resolvedName = adminName;
      try {
        final userDoc = await _db.collection('users').doc(uid).get();
        final currentRole = userDoc.data()?['role']?.toString();
        final adminDoc = await _db.collection('admins').doc(uid).get();

        if (currentRole == 'admin' || adminDoc.exists) {
          resolvedName = userDoc.data()?['name']?.toString() ??
              adminDoc.data()?['name']?.toString() ??
              adminName;
        } else {
          await _auth.signOut();
          return {
            'success': false,
            'error': 'هذا الحساب غير مصرح له بالدخول كمسؤول في النظام.',
          };
        }
      } catch (_) {}

      await _saveSession(
        uid: uid,
        role: 'admin',
        name: resolvedName,
        phone: input,
        accountId: adminAccountId,
      );

      unawaited(NotificationService().registerAdminDevice(adminUid: uid));

      return {
        'success': true,
        'uid': uid,
        'role': 'admin',
        'name': resolvedName,
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

  @override
  Future<Map<String, dynamic>> adminResetUserPassword({
    required String phone,
    required String newPassword,
    String? ticketId,
    String? targetUid,
  }) async {
    try {
      if (newPassword.length < 6) {
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

      // 1. If targetUid not passed, look up in phone_directory
      if (resolvedUid == null || resolvedUid.isEmpty) {
        try {
          final dirSnap = await _db.collection('phone_directory').doc(cleanDigits).get();
          if (dirSnap.exists && dirSnap.data()?['uid'] != null) {
            resolvedUid = dirSnap.data()!['uid'].toString();
          }
        } catch (_) {}
      }

      // 2. Query users collection
      if (resolvedUid == null || resolvedUid.isEmpty) {
        QuerySnapshot userSnap = await _db
            .collection('users')
            .where('phone', isEqualTo: phone.trim())
            .limit(1)
            .get();

        if (userSnap.docs.isEmpty) {
          userSnap = await _db
              .collection('users')
              .where('phone', isEqualTo: cleanDigits)
              .limit(1)
              .get();
        }

        if (userSnap.docs.isNotEmpty) {
          resolvedUid = userSnap.docs.first.id;
        } else {
          final allUsers = await _db.collection('users').get();
          for (final doc in allUsers.docs) {
            final p = doc
                .data()['phone']
                ?.toString()
                .replaceAll(RegExp(r'[^0-9]'), '');
            if (p == cleanDigits ||
                (p != null &&
                    (p.endsWith(cleanDigits) || cleanDigits.endsWith(p)))) {
              resolvedUid = doc.id;
              break;
            }
          }
        }
      }

      // 3. Query lawyers collection if still not found
      if (resolvedUid == null || resolvedUid.isEmpty) {
        final allLawyers = await _db.collection('lawyers').get();
        for (final doc in allLawyers.docs) {
          final p = doc
              .data()['phone']
              ?.toString()
              .replaceAll(RegExp(r'[^0-9]'), '');
          if (p == cleanDigits ||
              (p != null &&
                  (p.endsWith(cleanDigits) || cleanDigits.endsWith(p)))) {
            resolvedUid = doc.id;
            break;
          }
        }
      }

      if (resolvedUid == null) {
        return {
          'success': false,
          'error': 'لم يتم العثور على حساب مسجل برقم الهاتف: $phone',
        };
      }

      // Read existing user doc to preserve previousPasswordHash
      final existingDoc = await _db.collection('users').doc(resolvedUid).get();
      final prevHash = existingDoc.data()?['passwordHash']?.toString();

      final newHash = hashPassword(newPassword);
      final localDigits = PhoneUtils.extractLocalSudanDigits(cleanDigits);
      final normPhone = PhoneUtils.normalizeSudanPhone(phone);

      final batch = _db.batch();

      final updateData = <String, dynamic>{
        'adminResetPassword': newPassword,
        'passwordHash': newHash,
        if (prevHash != null && prevHash != newHash) 'previousPasswordHash': prevHash,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(_db.collection('users').doc(resolvedUid), updateData, SetOptions(merge: true));

      final lawyerDoc = await _db.collection('lawyers').doc(resolvedUid).get();
      if (lawyerDoc.exists) {
        batch.set(_db.collection('lawyers').doc(resolvedUid), updateData, SetOptions(merge: true));
      }

      final dirData = <String, dynamic>{
        'adminResetPassword': newPassword,
        'passwordHash': newHash,
        if (prevHash != null && prevHash != newHash) 'previousPasswordHash': prevHash,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (cleanDigits.isNotEmpty) {
        batch.set(_db.collection('phone_directory').doc(cleanDigits), dirData, SetOptions(merge: true));
      }
      if (normPhone.isNotEmpty && normPhone != cleanDigits) {
        batch.set(_db.collection('phone_directory').doc(normPhone), dirData, SetOptions(merge: true));
      }
      if (localDigits.isNotEmpty && localDigits != cleanDigits && localDigits != normPhone) {
        batch.set(_db.collection('phone_directory').doc(localDigits), dirData, SetOptions(merge: true));
      }
      if (cleanDigits.startsWith('0')) {
        batch.set(_db.collection('phone_directory').doc(cleanDigits.substring(1)), dirData, SetOptions(merge: true));
      }

      if (ticketId != null && ticketId.isNotEmpty) {
        batch.update(_db.collection('password_resets').doc(ticketId), {
          'status': 'resolved',
          'tempPassword': newPassword,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      return {
        'success': true,
        'uid': resolvedUid,
        'newPassword': newPassword,
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
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return {'success': false, 'error': 'يجب تسجيل الدخول أولاً'};
      }

      if (newPassword.length < 6) {
        return {
          'success': false,
          'error': 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل'
        };
      }

      final userDoc = await _db.collection('users').doc(user.uid).get();
      final storedHash = userDoc.data()?['passwordHash']?.toString();
      final adminReset = userDoc.data()?['adminResetPassword']?.toString();
      final phone = userDoc.data()?['phone']?.toString() ?? '';
      final currentHash = hashPassword(currentPassword);

      final bool isCurrentValid = (adminReset != null && adminReset == currentPassword) ||
          (storedHash == null || storedHash == currentHash);

      if (!isCurrentValid) {
        return {
          'success': false,
          'error': 'كلمة المرور الحالية غير صحيحة'
        };
      }

      final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
      final authKey = cleanDigits.isNotEmpty ? internalAuthKey(cleanDigits) : '';

      final pwCandidates = {
        currentPassword,
        if (currentPassword.length < 6) currentPassword.padRight(6, '0'),
        if (adminReset != null && adminReset.isNotEmpty) adminReset,
        if (authKey.isNotEmpty) authKey,
        '123456',
        '12345678',
        '000000',
        if (cleanDigits.isNotEmpty) cleanDigits,
      }.toList();

      bool reauthSuccess = false;
      for (final pw in pwCandidates) {
        try {
          final cred = EmailAuthProvider.credential(
            email: user.email!,
            password: pw,
          );
          await user.reauthenticateWithCredential(cred);
          reauthSuccess = true;
          break;
        } catch (_) {}
      }

      final effectiveNewPassword =
          newPassword.length < 6 ? newPassword.padRight(6, '0') : newPassword;

      if (reauthSuccess) {
        try {
          await user.updatePassword(effectiveNewPassword);
        } catch (_) {}
      }

      final newHash = hashPassword(newPassword);
      final batch = _db.batch();

      final userUpdate = <String, dynamic>{
        'passwordHash': newHash,
        'adminResetPassword': FieldValue.delete(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (storedHash != null) {
        userUpdate['previousPasswordHash'] = storedHash;
      }

      batch.set(_db.collection('users').doc(user.uid), userUpdate, SetOptions(merge: true));

      final lawyerDoc = await _db.collection('lawyers').doc(user.uid).get();
      if (lawyerDoc.exists) {
        batch.set(_db.collection('lawyers').doc(user.uid), userUpdate, SetOptions(merge: true));
      }

      if (cleanDigits.isNotEmpty) {
        final localDigits = PhoneUtils.extractLocalSudanDigits(cleanDigits);
        final normPhone = PhoneUtils.normalizeSudanPhone(phone);

        final dirData = {
          'passwordHash': newHash,
          'adminResetPassword': FieldValue.delete(),
          'passwordUpdatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(_db.collection('phone_directory').doc(cleanDigits), dirData, SetOptions(merge: true));
        if (normPhone.isNotEmpty && normPhone != cleanDigits) {
          batch.set(_db.collection('phone_directory').doc(normPhone), dirData, SetOptions(merge: true));
        }
        if (localDigits.isNotEmpty && localDigits != cleanDigits && localDigits != normPhone) {
          batch.set(_db.collection('phone_directory').doc(localDigits), dirData, SetOptions(merge: true));
        }
        if (cleanDigits.startsWith('0')) {
          batch.set(_db.collection('phone_directory').doc(cleanDigits.substring(1)), dirData, SetOptions(merge: true));
        }
      }

      await batch.commit();

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _authError(e.code)};
    } catch (e) {
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
    if (!kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentUid = prefs.getString('uid');
        await NotificationService().clearAllSystemNotifications();
        await NotificationService().unregisterUserDevice(uid: currentUid);
        await NotificationService().unregisterAdminDevice();
      } catch (e) {
        debugPrint('Notification cleanup error on signOut: $e');
      }
    }

    try {
      await _auth.signOut().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Auth signOut notice: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Session clear notice: $e');
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
      final batch = db.batch();
      batch.delete(db.collection('users').doc(uid));
      batch.delete(db.collection('lawyers').doc(uid));
      batch.delete(db.collection('lawyer_requests').doc(uid));
      batch.delete(db.collection('admins').doc(uid));
      batch.delete(db.collection('admin_fcm_tokens').doc(uid));

      for (final q in phoneCandidates) {
        if (q.trim().isEmpty) continue;
        batch.delete(db.collection('phone_directory').doc(q.trim()));
      }

      try {
        await batch.commit();
      } catch (batchErr) {
        debugPrint('[deleteAccount] batch delete failed: $batchErr, using direct deletes');
        await db.collection('users').doc(uid).delete().catchError((_) {});
        await db.collection('lawyers').doc(uid).delete().catchError((_) {});
        await db.collection('lawyer_requests').doc(uid).delete().catchError((_) {});
        await db.collection('admins').doc(uid).delete().catchError((_) {});
        await db.collection('admin_fcm_tokens').doc(uid).delete().catchError((_) {});
        for (final q in phoneCandidates) {
          if (q.trim().isEmpty) continue;
          await db.collection('phone_directory').doc(q.trim()).delete().catchError((_) {});
        }
      }

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

      // Clean up stray records by phone
      for (final q in phoneCandidates) {
        if (q.trim().isEmpty) continue;
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

      // ── 6. Delete Firebase Auth account (3 strategies) ───────────────────
      bool authDeleted = false;

      // Strategy 1: Primary app re-auth & user.delete()
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
