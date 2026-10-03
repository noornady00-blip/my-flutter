// ==============================================================================
// 🔐 AUTHENTICATION CONTRACT
// ==============================================================================
// Defines abstract contract interface for user authentication, registration,
// session management, and credential verification across Mahameek.
// ==============================================================================

import 'package:firebase_auth/firebase_auth.dart';

/// Abstract contract for authentication and session services.
abstract class AuthContract {
  /// Current authenticated Firebase user (or null if guest/logged out)
  User? get currentUser;

  /// Stream of Firebase authentication state changes
  Stream<User?> get authStateChanges;

  /// Authenticate client, lawyer, or admin via phone/email and password
  Future<Map<String, dynamic>> login({
    required String phoneOrEmail,
    required String password,
    String? role,
  });

  /// Unified Role-Guarded Sign-In for portals ('client', 'lawyer', 'admin')
  Future<Map<String, dynamic>> signInWithRole({
    required String phone,
    required String password,
    required String expectedPortal,
  });

  /// Register a new client account
  Future<Map<String, dynamic>> registerClient({
    required String name,
    required String phone,
    required String password,
    String? photoUrl,
    String? photoBase64,
  });

  /// Register a new lawyer account with pending status
  Future<Map<String, dynamic>> registerLawyer({
    required String name,
    required String phone,
    String? callPhone,
    required String whatsapp,
    required String city,
    String? specialization,
    required String password,
    String? photoUrl,
    String? photoBase64,
  });

  /// Authenticate administrator with enhanced validation
  Future<Map<String, dynamic>> adminLogin({
    required String emailOrPhone,
    required String password,
  });

  /// Create a new administrator account with Firebase Auth and Firestore permissions
  Future<Map<String, dynamic>> createAdminAccount({
    required String name,
    required String phone,
    required String password,
  });

  /// Re-authenticate and change password
  Future<Map<String, dynamic>> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Submit password reset ticket
  Future<Map<String, dynamic>> submitPasswordResetTicket({
    required String phone,
    required String source,
    String? notes,
  });

  /// Reset user password as administrator
  Future<Map<String, dynamic>> adminResetUserPassword({
    required String phone,
    required String newPassword,
    String? ticketId,
    String? targetUid,
  });

  /// Retrieve locally persisted session credentials
  Future<Map<String, String?>> getSavedSession();

  /// Sign out and clear local session
  Future<void> signOut();

  /// Terminate active session (alias for signOut)
  Future<void> logout();

  /// Permanently delete active account
  Future<Map<String, dynamic>> deleteAccount({String? currentPassword});

  /// Permanently delete a specific account from Firebase Auth (admin or background purge)
  Future<bool> deleteUserAuthAccount({
    required String phone,
    String? role,
    String? uid,
    String? password,
    String? userEmail,
  });
}
