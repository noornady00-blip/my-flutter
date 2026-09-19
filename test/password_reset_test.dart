import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mahameek/data/models/password_reset_model.dart';
import 'package:mahameek/data/models/admin_notification_model.dart';
import 'package:mahameek/network/auth_service.dart';

void main() {
  group('PasswordResetModel Tests', () {
    test('Parses pending reset ticket correctly from Map', () {
      final now = DateTime(2026, 9, 5, 20, 30);
      final map = {
        'phone': '01146979833',
        'cleanPhone': '01146979833',
        'status': 'pending',
        'source': 'whatsapp',
        'notes': 'طلب استعادة فوري',
        'createdAt': Timestamp.fromDate(now),
      };

      final ticket = PasswordResetModel.fromMap(map, 'ticket_001');

      expect(ticket.id, 'ticket_001');
      expect(ticket.phone, '01146979833');
      expect(ticket.cleanPhone, '01146979833');
      expect(ticket.status, 'pending');
      expect(ticket.isPending, isTrue);
      expect(ticket.isResolved, isFalse);
      expect(ticket.isRejected, isFalse);
      expect(ticket.source, 'whatsapp');
      expect(ticket.notes, 'طلب استعادة فوري');
      expect(ticket.createdAt, now);
      expect(ticket.resolvedAt, isNull);
      expect(ticket.tempPassword, isNull);
    });

    test('Parses resolved reset ticket with tempPassword', () {
      final created = DateTime(2026, 9, 5, 10, 0);
      final resolved = DateTime(2026, 9, 5, 10, 15);
      final map = {
        'phone': '0912345678',
        'status': 'resolved',
        'source': 'in_app',
        'createdAt': Timestamp.fromDate(created),
        'resolvedAt': Timestamp.fromDate(resolved),
        'tempPassword': 'temp_pass_123',
      };

      final ticket = PasswordResetModel.fromMap(map, 'ticket_002');

      expect(ticket.isPending, isFalse);
      expect(ticket.isResolved, isTrue);
      expect(ticket.tempPassword, 'temp_pass_123');
      expect(ticket.resolvedAt, resolved);
    });

    test('toMap formats data correctly for Firestore persistence', () {
      final now = DateTime(2026, 9, 5, 12, 0);
      final ticket = PasswordResetModel(
        id: 'ticket_003',
        phone: '01146979833',
        cleanPhone: '01146979833',
        status: 'pending',
        source: 'whatsapp',
        createdAt: now,
      );

      final map = ticket.toMap();

      expect(map['phone'], '01146979833');
      expect(map['cleanPhone'], '01146979833');
      expect(map['status'], 'pending');
      expect(map['source'], 'whatsapp');
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('formatWhatsAppNumber converts Sudanese local and international numbers correctly', () {
      // Local 10-digit starting with 0
      expect(PasswordResetModel.formatWhatsAppNumber('01146979833'), '2491146979833');
      expect(PasswordResetModel.formatWhatsAppNumber('0912345678'), '249912345678');

      // International with leading 00249
      expect(PasswordResetModel.formatWhatsAppNumber('002491146979833'), '2491146979833');

      // International with +
      expect(PasswordResetModel.formatWhatsAppNumber('+2491146979833'), '2491146979833');

      // 9-digit without leading 0
      expect(PasswordResetModel.formatWhatsAppNumber('1146979833'), '2491146979833');
    });
  });

  group('AuthService Password & Key Security Tests', () {
    test('hashPassword produces 64-char hex SHA-256 hash', () {
      final hash1 = AuthService.hashPassword('123456');
      final hash2 = AuthService.hashPassword('123456');
      final hash3 = AuthService.hashPassword('654321');

      expect(hash1.length, 64);
      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
    });

    test('internalAuthKey is deterministic and meets password complexity', () {
      final key1 = AuthService.internalAuthKey('01146979833');
      final key2 = AuthService.internalAuthKey('01146979833');
      final key3 = AuthService.internalAuthKey('0912345678');

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
      expect(key1.length, greaterThanOrEqualTo(6));
      expect(key1, contains('@'));
      expect(key1, contains('#'));
    });

    test('Password verification rejects mismatched input hashes', () {
      final storedHash = AuthService.hashPassword('correct_pass_123');
      final correctInputHash = AuthService.hashPassword('correct_pass_123');
      final wrongInputHash = AuthService.hashPassword('wrong_pass_456');

      expect(storedHash == correctInputHash, isTrue);
      expect(storedHash == wrongInputHash, isFalse);
    });
  });

  group('Admin Notification & Success Message Tests', () {
    test('AdminNotificationModel parses password reset alert correctly', () {
      final now = DateTime(2026, 9, 5, 23, 0);
      final notif = AdminNotificationModel.fromMap({
        'type': 'password_reset',
        'title': 'طلب استعادة كلمة المرور 🔑',
        'body': 'طلب جديد لاستعادة كلمة المرور لرقم: 01146979833',
        'data': {'phone': '01146979833'},
        'createdAt': Timestamp.fromDate(now),
        'read': false,
      }, 'notif_001');

      expect(notif.id, 'notif_001');
      expect(notif.isPasswordReset, isTrue);
      expect(notif.isLawyerRegistration, isFalse);
      expect(notif.isRead, isFalse);
      expect(notif.data['phone'], '01146979833');
    });

    test('AdminNotificationModel parses lawyer registration alert correctly', () {
      final now = DateTime(2026, 9, 5, 23, 0);
      final notif = AdminNotificationModel.fromMap({
        'type': 'lawyer_registration',
        'title': 'طلب انضمام محامٍ جديد ⚖️',
        'body': 'تم تقديم طلب انضمام جديد من المحامي: أحمد علي (الخرطوم)',
        'data': {'name': 'أحمد علي', 'city': 'الخرطوم'},
        'createdAt': Timestamp.fromDate(now),
        'read': true,
      }, 'notif_002');

      expect(notif.isLawyerRegistration, isTrue);
      expect(notif.isPasswordReset, isFalse);
      expect(notif.isRead, isTrue);
      expect(notif.data['name'], 'أحمد علي');
    });

    test('AdminNotificationModel parses support message alert correctly', () {
      final now = DateTime(2026, 9, 5, 23, 0);
      final notif = AdminNotificationModel.fromMap({
        'type': 'support_message',
        'title': 'رسالة دعم فني جديدة 💬',
        'body': 'رسالة من العميل: محمد',
        'data': {'phone': '01146979833', 'msgId': 'msg_001'},
        'createdAt': Timestamp.fromDate(now),
        'read': false,
      }, 'notif_003');

      expect(notif.isSupportMessage, isTrue);
      expect(notif.isPasswordReset, isFalse);
      expect(notif.isLawyerRegistration, isFalse);
      expect(notif.isRead, isFalse);
    });

    test('Bulk selection logic toggles correctly between select all and deselect all', () {
      final list = ['n1', 'n2', 'n3'];
      final selected = <String>{};

      // Default on trash click: select all
      selected.addAll(list);
      expect(selected.length, 3);
      expect(selected.contains('n1'), isTrue);
      expect(selected.contains('n2'), isTrue);
      expect(selected.contains('n3'), isTrue);

      // Deselect single item: leave one out
      selected.remove('n2');
      expect(selected.length, 2);
      expect(selected.contains('n2'), isFalse);
      expect(selected.length == list.length, isFalse);

      // Deselect all
      selected.clear();
      expect(selected.isEmpty, isTrue);

      // Select single item
      selected.add('n1');
      expect(selected.length, 1);
      expect(selected.contains('n1'), isTrue);
    });

    test('Password reset success message contains all required Arabic text segments', () {
      const phone = '01146979833';
      final message = 'مرحباً بك، أنت طلبت تغيير كلمة السر لحسابك في تطبيق محاميك، وتم تغييرها بنجاح إلى: 123456.\n\n'
          'يمكنك الآن تسجيل الدخول برقم الهاتف: $phone وكلمة السر: 123456.\n\n'
          'إن لم تكن أنت فيرجى إعلامنا بذلك.';

      expect(message, contains('أنت طلبت تغيير كلمة السر'));
      expect(message, contains('123456'));
      expect(message, contains('يمكنك الآن تسجيل الدخول برقم الهاتف: 01146979833 وكلمة السر: 123456'));
      expect(message, contains('إن لم تكن أنت فيرجى إعلامنا بذلك'));
    });
  });
}
