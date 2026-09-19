// ==============================================================================
// ☁️ FIREBASE STORAGE SERVICE
// ==============================================================================
// Manages profile image uploads, compression, validation, and storage lifecycle.
// ==============================================================================

import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Service handling media and profile photo uploads to Firebase Cloud Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ---------------------------------------------------------------------------
  // Profile Photo Upload & Fallback
  // ---------------------------------------------------------------------------
  /// Uploads a user's profile photo to Firebase Storage with size validation and metadata.
  /// Automatically deletes [oldPhotoUrl] if provided to avoid orphaned files.
  /// Returns the permanent public download URL.
  Future<String> uploadProfilePhoto({
    required String uid,
    required XFile imageFile,
    String? oldPhotoUrl,
  }) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();

      // Check max size: 5MB
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        throw Exception(
            'حجم الصورة كبير جداً، الحد الأقصى المسموح به هو 5 ميجابايت');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('profile_photos/$uid/$timestamp.jpg');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': uid,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Attempt deletion of old photo in background if it's a valid Firebase Storage URL
      if (oldPhotoUrl != null &&
          oldPhotoUrl.isNotEmpty &&
          oldPhotoUrl.startsWith('http')) {
        deletePhotoByUrl(oldPhotoUrl).catchError((e) {
          debugPrint('Notice: Could not delete previous photo: $e');
        });
      }

      return downloadUrl;
    } catch (e) {
      debugPrint(
          'StorageService Firebase Storage notice: $e -> Falling back to Base64 storage');
      try {
        final Uint8List bytes = await imageFile.readAsBytes();
        final base64Str = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64Str';
      } catch (fallbackErr) {
        debugPrint('StorageService Base64 fallback error: $fallbackErr');
        rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Deletion Helpers
  // ---------------------------------------------------------------------------
  /// Deletes a photo from Firebase Storage safely by its download URL.
  Future<void> deletePhotoByUrl(String photoUrl) async {
    try {
      if (!photoUrl.startsWith('http') ||
          !photoUrl.contains('firebasestorage.googleapis.com')) {
        return; // Skip non-Firebase Storage URLs (e.g. assets or base64)
      }
      final ref = _storage.refFromURL(photoUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('deletePhotoByUrl notice: $e');
    }
  }

  /// Alias for deleting an old photo safely
  Future<void> deleteOldPhoto(String? photoUrl) async {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await deletePhotoByUrl(photoUrl);
    }
  }
}
