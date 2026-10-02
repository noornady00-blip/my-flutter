import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/lawyer.dart';

/// ==============================================================================
/// 🔔 RECENT LAWYERS TRACKER (نظام تتبع وقراءة المحامين المنضمين حديثاً)
/// ==============================================================================
/// Tracks read/unread state of newly joined and approved lawyers in the platform.
/// Updates the notification badge on the "آخر المحامين المنضمين" card in real time.
/// When the admin opens the screen, the notification badge disappears immediately.
/// ==============================================================================
class RecentLawyersTracker {
  static const String _keySeenIds = 'admin_seen_recent_lawyers_ids_v2';
  static const String _keyInitialized = 'admin_recent_lawyers_init_done_v2';

  /// ValueNotifier exposing the current set of seen lawyer UIDs
  static final ValueNotifier<Set<String>> seenLawyerIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});

  static bool _isLoaded = false;
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  /// Load seen IDs from SharedPreferences at app startup
  static Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isInitialized = prefs.getBool(_keyInitialized) ?? false;
      final savedList = prefs.getStringList(_keySeenIds) ?? <String>[];
      seenLawyerIdsNotifier.value = savedList.toSet();
      _isLoaded = true;
    } catch (e) {
      debugPrint('RecentLawyersTracker.load error: $e');
    }
  }

  /// Ensure initial synchronization for existing lawyers on first run.
  /// If the admin opens the app for the very first time, existing approved lawyers
  /// are considered baseline so that the counter starts at 0 and only increments
  /// for newly joining lawyers.
  static Future<void> ensureInitialized(List<LawyerModel> initialApproved) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDone = prefs.getBool(_keyInitialized) ?? false;
      if (!isDone && initialApproved.isNotEmpty) {
        final existingIds = initialApproved.map((l) => l.uid).toSet();
        await prefs.setStringList(_keySeenIds, existingIds.toList());
        await prefs.setBool(_keyInitialized, true);
        _isInitialized = true;
        _isLoaded = true;
        seenLawyerIdsNotifier.value = existingIds;
      }
    } catch (e) {
      debugPrint('RecentLawyersTracker.ensureInitialized error: $e');
    }
  }

  /// Calculates how many approved lawyers have not yet been seen by the admin
  static int calculateUnreadCount(List<LawyerModel> approvedLawyers) {
    if (!_isInitialized) return 0;
    final seen = seenLawyerIdsNotifier.value;
    return approvedLawyers
        .where((l) => l.isApproved && !seen.contains(l.uid))
        .length;
  }

  /// Gets the set of unseen lawyer IDs
  static Set<String> getUnseenIds(List<LawyerModel> approvedLawyers) {
    final seen = seenLawyerIdsNotifier.value;
    return approvedLawyers
        .where((l) => l.isApproved && !seen.contains(l.uid))
        .map((l) => l.uid)
        .toSet();
  }

  /// Marks a specific list or set of lawyer IDs as seen
  static Future<void> markAsSeen(Iterable<String> lawyerIds) async {
    final updated = Set<String>.from(seenLawyerIdsNotifier.value)..addAll(lawyerIds);
    seenLawyerIdsNotifier.value = updated;
    _isInitialized = true;
    _isLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keySeenIds, updated.toList());
      await prefs.setBool(_keyInitialized, true);
    } catch (e) {
      debugPrint('RecentLawyersTracker.markAsSeen error: $e');
    }
  }

  /// Marks all current approved lawyers as seen (called when opening the recent lawyers screen)
  static Future<void> markAllApprovedAsSeen(List<LawyerModel> approvedLawyers) async {
    final ids = approvedLawyers.where((l) => l.isApproved).map((l) => l.uid);
    await markAsSeen(ids);
  }

  /// Checks if a specific lawyer is considered new (unseen)
  static bool isUnseen(String uid) {
    return !seenLawyerIdsNotifier.value.contains(uid);
  }
}
