// ==============================================================================
// ⚖️ LAWYER REPOSITORY
// ==============================================================================
// Acts as a clean mediator between UI / Business Logic and Database Services.
// Handles lawyer searches, filtering, state changes, and client queries.
// ==============================================================================

import '../../network/database_contract.dart';
import '../../network/firestore_service.dart';
import '../models/lawyer.dart';
import '../models/user_model.dart';
import '../models/password_reset_model.dart';

/// Repository coordinating lawyer directory data, administrative moderation, and caching.
class LawyerRepo {
  final DatabaseContract _dbContract;

  LawyerRepo({DatabaseContract? dbContract})
      : _dbContract = dbContract ?? FirestoreService();

  // ---------------------------------------------------------------------------
  // Lawyer Streams & Queries
  // ---------------------------------------------------------------------------
  Stream<List<LawyerModel>> getLawyersByCity(String city) =>
      _dbContract.getLawyersByCity(city);

  Stream<List<LawyerModel>> getApprovedLawyers() =>
      _dbContract.getApprovedLawyers();

  Stream<List<LawyerModel>> getRecentApprovedLawyers({int limit = 5}) =>
      _dbContract.getRecentApprovedLawyers(limit: limit);

  Stream<List<LawyerModel>> getPendingLawyers() =>
      _dbContract.getPendingLawyers();

  Stream<List<LawyerModel>> getAllLawyers() => _dbContract.getAllLawyers();

  Future<LawyerModel?> getLawyer(String uid) => _dbContract.getLawyer(uid);

  Stream<LawyerModel?> streamLawyer(String uid) =>
      _dbContract.streamLawyer(uid);

  // ---------------------------------------------------------------------------
  // Lawyer Administration
  // ---------------------------------------------------------------------------
  Future<void> approveLawyer(String uid) => _dbContract.approveLawyer(uid);

  Future<void> suspendLawyer(String uid) => _dbContract.suspendLawyer(uid);

  Future<void> activateLawyer(String uid) => _dbContract.activateLawyer(uid);

  Future<void> rejectLawyer(String uid, [String? reason]) =>
      _dbContract.rejectLawyer(uid, reason);

  Future<void> deleteLawyer(String uid) => _dbContract.deleteLawyer(uid);

  Future<bool> updateLawyerProfile({
    required String uid,
    String? name,
    String? phone,
    String? whatsapp,
    String? city,
    String? specialization,
    String? photoUrl,
    String? photoBase64,
  }) =>
      _dbContract.updateLawyerProfile(
        uid: uid,
        name: name,
        phone: phone,
        whatsapp: whatsapp,
        city: city,
        specialization: specialization,
        photoUrl: photoUrl,
        photoBase64: photoBase64,
      );

  // ---------------------------------------------------------------------------
  // Users & Clients
  // ---------------------------------------------------------------------------
  Future<UserModel?> getUser(String uid) => _dbContract.getUser(uid);

  Stream<List<UserModel>> getAllClients() => _dbContract.getAllClients();

  Future<void> suspendClient(String uid) => _dbContract.suspendClient(uid);

  Future<void> activateClient(String uid) => _dbContract.activateClient(uid);

  Future<void> deleteClient(String uid) => _dbContract.deleteClient(uid);

  Future<void> deleteUser(String uid) => _dbContract.deleteUser(uid);

  // ---------------------------------------------------------------------------
  // Password Reset Tickets
  // ---------------------------------------------------------------------------
  Future<String> submitPasswordResetTicket({
    required String phone,
    required String source,
    String? notes,
  }) =>
      _dbContract.submitPasswordResetTicket(
        phone: phone,
        source: source,
        notes: notes,
      );

  Stream<List<PasswordResetModel>> getPasswordResetsStream() =>
      _dbContract.getPasswordResetsStream();

  Future<void> deletePasswordResetTicket(String ticketId) =>
      _dbContract.deletePasswordResetTicket(ticketId);

  Future<void> resolvePasswordResetTicket({
    required String ticketId,
    required String tempPassword,
  }) =>
      _dbContract.resolvePasswordResetTicket(
        ticketId: ticketId,
        tempPassword: tempPassword,
      );

  Future<void> rejectPasswordResetTicket(String ticketId) =>
      _dbContract.rejectPasswordResetTicket(ticketId);

  // ---------------------------------------------------------------------------
  // Statistics & Cache
  // ---------------------------------------------------------------------------
  Future<Map<String, int>> getStats() => _dbContract.getStats();

  Future<void> cacheApprovedLawyersLocally(List<LawyerModel> lawyers) =>
      _dbContract.cacheApprovedLawyersLocally(lawyers);

  Future<void> clearLocalLawyerCache() => _dbContract.clearLocalLawyerCache();

  Future<List<LawyerModel>> getCachedApprovedLawyers() =>
      _dbContract.getCachedApprovedLawyers();
}
