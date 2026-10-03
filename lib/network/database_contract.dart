// ==============================================================================
// 🗄️ DATABASE CONTRACT
// ==============================================================================
// Defines abstract contract interface for Firestore data operations, queries,
// local caching, and real-time synchronization.
// ==============================================================================

import '../data/models/lawyer.dart';
import '../data/models/user_model.dart';
import '../data/models/password_reset_model.dart';

/// Abstract contract for database and cloud storage operations.
abstract class DatabaseContract {
  // ---------------------------------------------------------------------------
  // Lawyer Queries & Streams
  // ---------------------------------------------------------------------------
  Stream<List<LawyerModel>> getLawyersByCity(String city);
  Stream<List<LawyerModel>> getApprovedLawyers();
  Stream<List<LawyerModel>> getRecentApprovedLawyers({int limit = 5});
  Stream<List<LawyerModel>> getPendingLawyers();
  Stream<List<LawyerModel>> getAllLawyers();
  Future<LawyerModel?> getLawyer(String uid);
  Stream<LawyerModel?> streamLawyer(String uid);

  // ---------------------------------------------------------------------------
  // Lawyer Administrative Actions
  // ---------------------------------------------------------------------------
  Future<void> approveLawyer(String uid);
  Future<void> suspendLawyer(String uid);
  Future<void> activateLawyer(String uid);
  Future<void> rejectLawyer(String uid, [String? reason]);
  Future<void> deleteLawyer(String uid);
  Future<bool> updateLawyerProfile({
    required String uid,
    String? name,
    String? phone,
    String? callPhone,
    String? whatsapp,
    String? city,
    String? specialization,
    String? photoUrl,
    String? photoBase64,
  });

  // ---------------------------------------------------------------------------
  // Users & Clients & Admins
  // ---------------------------------------------------------------------------
  Future<UserModel?> getUser(String uid);
  Stream<List<UserModel>> getAllClients();
  Future<void> suspendClient(String uid);
  Future<void> activateClient(String uid);
  Future<void> deleteClient(String uid);
  Future<void> deleteUser(String uid);

  // ---------------------------------------------------------------------------
  // Admins
  // ---------------------------------------------------------------------------
  Stream<List<UserModel>> getAllAdmins();
  Future<void> ensurePrimaryAdminsSeeded();
  Future<void> suspendAdmin(String uid);
  Future<void> activateAdmin(String uid);
  Future<void> deleteAdmin(String uid);

  // ---------------------------------------------------------------------------
  // Password Reset Operations
  // ---------------------------------------------------------------------------
  Future<String> submitPasswordResetTicket({
    required String phone,
    required String source,
    String? notes,
  });
  Stream<List<PasswordResetModel>> getPasswordResetsStream();
  Future<void> deletePasswordResetTicket(String ticketId);
  Future<void> resolvePasswordResetTicket({
    required String ticketId,
    required String tempPassword,
  });
  Future<void> rejectPasswordResetTicket(String ticketId);

  // ---------------------------------------------------------------------------
  // Statistics & Offline Cache
  // ---------------------------------------------------------------------------
  Future<Map<String, int>> getStats();
  Future<void> cacheApprovedLawyersLocally(List<LawyerModel> lawyers);
  Future<void> clearLocalLawyerCache();
  Future<List<LawyerModel>> getCachedApprovedLawyers();
}
