// ==============================================================================
// 🖼️ ROBUST IMAGE & AVATAR UTILITIES
// ==============================================================================
// Safely handles Base64 data (including Data URIs, newlines, padding),
// network URLs, and graceful fallbacks for avatars across the entire application.
// ==============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AppImageUtils {
  /// Safely extracts and decodes Base64 data from raw base64 or Data URI format.
  /// Handles whitespace, newlines, missing padding, and Data URI headers (e.g. data:image/jpeg;base64,...).
  static Uint8List? safeDecodeBase64(String? input) {
    if (input == null) return null;
    var str = input.trim();
    if (str.isEmpty || str == 'default') return null;

    // 1. Strip Data URI prefix if present (e.g. data:image/png;base64,...)
    if (str.contains(',')) {
      str = str.split(',').last.trim();
    }

    // 2. Remove all whitespace, newlines, carriage returns
    str = str.replaceAll(RegExp(r'\s+'), '');
    if (str.isEmpty) return null;

    // 3. Fix missing padding if necessary
    final remainder = str.length % 4;
    if (remainder > 0) {
      str += '=' * (4 - remainder);
    }

    // 4. Decode bytes safely
    try {
      final bytes = base64Decode(str);
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// Builds a high-performance image widget from either Base64 or Network URL.
  /// Seamlessly checks both sources and falls back gracefully.
  static Widget buildAvatarImage({
    String? photoBase64,
    String? photoUrl,
    required Widget fallback,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    // 1. Check photoBase64 first
    final bytesFromBase64 = safeDecodeBase64(photoBase64);
    if (bytesFromBase64 != null) {
      return Image.memory(
        bytesFromBase64,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // 2. Check if photoUrl is actually a Base64 / Data URI string
    if (photoUrl != null && photoUrl.trim().isNotEmpty && photoUrl != 'default') {
      final trimmedUrl = photoUrl.trim();
      if (trimmedUrl.startsWith('data:image') || !trimmedUrl.startsWith('http')) {
        final bytesFromUrl = safeDecodeBase64(trimmedUrl);
        if (bytesFromUrl != null) {
          return Image.memory(
            bytesFromUrl,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
        }
      } else {
        // Standard HTTP / HTTPS URL
        return Image.network(
          trimmedUrl,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      }
    }

    // 3. If neither worked, return the fallback widget
    return fallback;
  }
}
