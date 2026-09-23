// ==============================================================================
// 🌐 UNIVERSAL ARABIC ERROR TRANSLATOR (محرك ترجمة كافة أخطاء التطبيق للعربية)
// ==============================================================================
// Converts any Firebase, Firestore, Storage, Network, or Platform exceptions
// into clear, friendly, and professional Arabic messages. Never leaks English jargon.
// ==============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

class AppErrorTranslator {
  /// Translates any error or exception to a clear, professional Arabic string
  static String translate(dynamic error, {String? defaultMessage}) {
    if (error == null) {
      return defaultMessage ?? 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.';
    }

    final rawStr = error.toString();
    final lower = rawStr.toLowerCase();

    // ── 1. Specific Firebase Core & Auth Exceptions ──
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      final translated = _fromFirebaseCode(code, error.plugin);
      if (translated != null) return translated;
    }

    // ── 2. Network & Connectivity Exceptions ──
    if (error is SocketException ||
        lower.contains('socketexception') ||
        lower.contains('network-request-failed') ||
        lower.contains('network_error') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception')) {
      return 'تعذر الاتصال بالخادم، يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.';
    }

    if (error is TimeoutException || lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'استغرقت العملية وقتاً أطول من المتوقع، يرجى إعادة المحاولة.';
    }

    // ── 3. Firestore Specific Errors ──
    if (lower.contains('invalid-argument') || lower.contains('invalid_argument')) {
      return 'بيانات غير صالحة أو حجم الصورة كبير جداً، يرجى تجربة صورة أصغر حجماً.';
    }
    if (lower.contains('permission-denied') || lower.contains('permission_denied')) {
      return 'تم رفض العملية: ليس لديك الصلاحية الكافية لإتمام هذا الإجراء.';
    }
    if (lower.contains('not-found') || lower.contains('not_found')) {
      return 'البيانات أو الملف المطلوب غير موجود في النظام.';
    }
    if (lower.contains('already-exists') || lower.contains('already_exists')) {
      return 'هذه البيانات مسجلة مسبقاً في النظام.';
    }
    if (lower.contains('resource-exhausted')) {
      return 'تم تجاوز عدد العمليات المسموح بها مؤقتاً، يرجى الانتظار لحظات.';
    }
    if (lower.contains('failed-precondition')) {
      return 'لا يمكن إتمام العملية في الوقت الحالي، يرجى إعادة المحاولة.';
    }
    if (lower.contains('unavailable')) {
      return 'الخدمة غير متوفرة حالياً، يرجى التحقق من اتصال الإنترنت.';
    }

    // ── 4. Firebase Storage Errors ──
    if (lower.contains('object-not-found')) {
      return 'الصورة أو الملف المطلوب غير موجود في الخادم السحابي.';
    }
    if (lower.contains('bucket-not-found') || lower.contains('project-not-found')) {
      return 'تعذر الوصول لمساحة التخزين السحابية، يرجى مراجعة إدارة المنصة.';
    }
    if (lower.contains('quota-exceeded')) {
      return 'تم استهلاك سعة التخزين المحددة مؤقتاً.';
    }
    if (lower.contains('unauthorized')) {
      return 'غير مصرح برفع الملفات، يرجى تسجيل الدخول أولاً.';
    }
    if (lower.contains('canceled') || lower.contains('cancelled')) {
      return 'تم إلغاء عملية الرفع.';
    }
    if (lower.contains('cannot-slice-blob') || lower.contains('server-file-wrong-size')) {
      return 'حدث خطأ أثناء معالجة ملف الصورة، يرجى اختيار صورة أخرى.';
    }

    // ── 5. Firebase Auth Error Patterns ──
    if (lower.contains('wrong-password') || lower.contains('invalid-credential')) {
      return 'كلمة المرور غير صحيحة، يرجى التأكد وإعادة المحاولة.';
    }
    if (lower.contains('user-not-found')) {
      return 'لا يوجد حساب مسجل بهذه البيانات.';
    }
    if (lower.contains('email-already-in-use') || lower.contains('email-already-exists')) {
      return 'رقم الهاتف مسجل مسبقاً في المنصة، يرجى تسجيل الدخول مباشرة.';
    }
    if (lower.contains('weak-password')) {
      return 'كلمة المرور ضعيفة جداً، يرجى إدخال 6 خانات على الأقل.';
    }
    if (lower.contains('too-many-requests')) {
      return 'تم رصد محاولات متكررة، يرجى الانتظار دقيقة والمحاولة ثانية.';
    }
    if (lower.contains('user-disabled')) {
      return 'تم تعطيل هذا الحساب من قبل إدارة المنصة.';
    }
    if (lower.contains('invalid-phone-number')) {
      return 'رقم الهاتف المدخل غير صحيح، يرجى التأكد من كتابته بشكل سليم.';
    }

    // ── 6. Platform & Format Exceptions ──
    if (error is PlatformException) {
      if (error.message != null && error.message!.isNotEmpty) {
        final m = error.message!.toLowerCase();
        if (m.contains('camera_access_denied') || m.contains('permission')) {
          return 'يرجى منح التطبيق إذن الوصول للكاميرا أو المعرض من إعدادات الهاتف.';
        }
      }
      return 'حدث خطأ في النظام، يرجى إعادة المحاولة.';
    }

    if (error is FormatException) {
      return 'صيغة البيانات غير صحيحة، يرجى التأكد من المدخلات.';
    }

    // ── 7. Fallback: Clean non-technical friendly Arabic ──
    return defaultMessage ?? 'تعذر إتمام العملية بنجاح، يرجى التحقق من اتصالك والمحاولة لاحقاً.';
  }

  static String? _fromFirebaseCode(String code, String? plugin) {
    switch (code) {
      case 'invalid-argument':
        return 'البيانات المدخلة غير صالحة أو حجم الصورة كبير جداً، يرجى اختيار صورة أصغر.';
      case 'permission-denied':
        return 'تم رفض الطلب: ليس لديك الصلاحية الكافية لإتمام هذه العملية.';
      case 'not-found':
        return 'العنصر المطلوب غير موجود في النظام.';
      case 'already-exists':
        return 'هذا السجل موجود بالفعل مسبقاً.';
      case 'resource-exhausted':
        return 'تم تجاوز الحد المسموح به من العمليات مؤقتاً، يرجى الانتظار.';
      case 'unavailable':
        return 'الخادم غير متاح حالياً، يرجى التأكد من اتصال الإنترنت.';
      case 'unauthenticated':
        return 'انتهت جلستك الحالية، يرجى إعادة تسجيل الدخول.';
      case 'object-not-found':
        return 'الملف غير موجود في الخادم.';
      case 'unauthorized':
        return 'ليس لديك إذن برفع أو تعديل هذا الملف.';
      case 'quota-exceeded':
        return 'تم استهلاك المساحة المحددة مؤقتاً.';
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط بهذه البيانات.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة، يرجى إعادة المحاولة.';
      case 'email-already-in-use':
        return 'رقم الهاتف مسجل مسبقاً بالفعل، يرجى تسجيل الدخول.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، يرجى استخدام 6 خانات على الأقل.';
      case 'network-request-failed':
        return 'الشبكة لا يتوفر بها إنترنت، يرجى التحقق من اتصالك.';
      case 'too-many-requests':
        return 'محاولات متكررة، يرجى الانتظار دقيقة والمحاولة ثانية.';
      default:
        return null;
    }
  }
}
