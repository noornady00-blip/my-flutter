// ==============================================================================
// 🏛️ AUTHENTICATION REPOSITORY
// ==============================================================================
// Acts as a clean mediator between UI / Business Logic and Auth Services.
// Follows the Repository Pattern demonstrated in reyadalsalehin1 architecture.
// ==============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import '../../network/auth_contract.dart';
import '../../network/auth_service.dart';

/// Repository coordinating authentication, session storage, and profile state.
class AuthRepo {
  final AuthContract _authContract;

  AuthRepo({AuthContract? authContract})
      : _authContract = authContract ?? AuthService();

  // ---------------------------------------------------------------------------
  // Current Session Getters & Streams
  // ---------------------------------------------------------------------------
  User? get currentUser => _authContract.currentUser;
  Stream<User?> get authStateChanges => _authContract.authStateChanges;

  // ---------------------------------------------------------------------------
  // Authentication Actions
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> login({
    required String phoneOrEmail,
    required String password,
    String? role,
  }) =>
      _authContract.login(
        phoneOrEmail: phoneOrEmail,
        password: password,
        role: role,
      );

  Future<Map<String, dynamic>> signInWithRole({
    required String phone,
    required String password,
    required String expectedPortal,
  }) =>
      _authContract.signInWithRole(
        phone: phone,
        password: password,
        expectedPortal: expectedPortal,
      );

  Future<Map<String, dynamic>> registerClient({
    required String name,
    required String phone,
    required String password,
    String? photoUrl,
    String? photoBase64,
  }) =>
      _authContract.registerClient(
        name: name,
        phone: phone,
        password: password,
        photoUrl: photoUrl,
        photoBase64: photoBase64,
      );

  Future<Map<String, dynamic>> registerLawyer({
    required String name,
    required String phone,
    required String password,
    required String city,
    String? specialization,
    required String whatsapp,
    String? photoUrl,
    String? photoBase64,
  }) =>
      _authContract.registerLawyer(
        name: name,
        phone: phone,
        password: password,
        city: city,
        specialization: specialization,
        whatsapp: whatsapp,
        photoUrl: photoUrl,
        photoBase64: photoBase64,
      );

  Future<Map<String, dynamic>> adminLogin({
    required String emailOrPhone,
    required String password,
  }) =>
      _authContract.adminLogin(
        emailOrPhone: emailOrPhone,
        password: password,
      );

  Future<Map<String, dynamic>> createAdminAccount({
    required String name,
    required String phone,
    required String password,
  }) =>
      _authContract.createAdminAccount(
        name: name,
        phone: phone,
        password: password,
      );

  Future<Map<String, dynamic>> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _authContract.reauthenticateAndChangePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<Map<String, dynamic>> submitPasswordResetTicket({
    required String phone,
    required String source,
    String? notes,
  }) =>
      _authContract.submitPasswordResetTicket(
        phone: phone,
        source: source,
        notes: notes,
      );

  Future<Map<String, dynamic>> adminResetUserPassword({
    required String phone,
    required String newPassword,
    String? ticketId,
    String? targetUid,
  }) =>
      _authContract.adminResetUserPassword(
        phone: phone,
        newPassword: newPassword,
        ticketId: ticketId,
        targetUid: targetUid,
      );

  Future<Map<String, String?>> getSavedSession() =>
      _authContract.getSavedSession();

  Future<void> logout() => _authContract.logout();

  Future<void> signOut() => _authContract.signOut();

  Future<Map<String, dynamic>> deleteAccount({String? currentPassword}) =>
      _authContract.deleteAccount(currentPassword: currentPassword);

  Future<bool> deleteUserAuthAccount({
    required String phone,
    String? role,
    String? uid,
    String? password,
    String? userEmail,
  }) =>
      _authContract.deleteUserAuthAccount(
        phone: phone,
        role: role,
        uid: uid,
        password: password,
        userEmail: userEmail,
      );
}

