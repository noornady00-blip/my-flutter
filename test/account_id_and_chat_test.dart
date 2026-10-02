import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/core/utils/account_id_utils.dart';
import 'package:mahameek/data/models/chat_model.dart';
import 'package:mahameek/data/models/chat_message_model.dart';
import 'package:mahameek/data/models/user_model.dart';
import 'package:mahameek/data/models/lawyer.dart';

void main() {
  group('AccountIdUtils Tests', () {
    test('generateCandidate12DigitId produces valid 12-digit numeric string', () {
      for (int i = 0; i < 50; i++) {
        final id = AccountIdUtils.generateCandidate12DigitId();
        expect(id.length, 12);
        expect(AccountIdUtils.isValid12DigitId(id), isTrue);
        expect(RegExp(r'^\d{12}$').hasMatch(id), isTrue);
        // Ensure leading digit is never zero
        expect(id.startsWith('0'), isFalse);
      }
    });

    test('format and formatForDisplay format 12 digits in 4-digit groups', () {
      const raw = '123456789012';
      final formatted = AccountIdUtils.formatForDisplay(raw);
      expect(formatted, '1234 5678 9012');
      expect(AccountIdUtils.format(raw), '1234 5678 9012');
      expect(AccountIdUtils.format12Digits(raw), '1234 5678 9012');
    });

    test('format handles non-12-digit fallbacks safely', () {
      expect(AccountIdUtils.format(''), '');
      expect(AccountIdUtils.format('12345'), '12345');
    });

    test('isValid12DigitId validates strictly', () {
      expect(AccountIdUtils.isValid12DigitId('123456789012'), isTrue);
      expect(AccountIdUtils.isValid12DigitId('12345678901'), isFalse);
      expect(AccountIdUtils.isValid12DigitId('1234567890123'), isFalse);
      expect(AccountIdUtils.isValid12DigitId('12345678901a'), isFalse);
      expect(AccountIdUtils.isValid12DigitId(null), isFalse);
    });
  });

  group('UserModel with Account ID & Roles', () {
    test('User contains and serializes accountId', () {
      final user = UserModel(
        uid: 'user_u1',
        name: 'مستخدم تجريبي',
        phone: '0912345678',
        role: 'client',
        accountId: '123456789012',
      );

      final map = user.toMap();
      expect(map['accountId'], '123456789012');

      final deserialized = UserModel.fromMap(map, 'user_u1');
      expect(deserialized.accountId, '123456789012');
    });

    test('Admin role recognized correctly', () {
      final admin = UserModel(
        uid: 'admin_u1',
        name: 'المشرف',
        phone: '01146979833',
        role: 'admin',
        accountId: '999888777666',
      );

      expect(admin.isAdmin, isTrue);
    });
  });

  group('LawyerModel with Account ID and No Specialization Requirement', () {
    test('Lawyer default specialization is empty string', () {
      final lawyer = LawyerModel(
        uid: 'l_1',
        name: 'أحمد المحامي',
        phone: '0911223344',
        city: 'الخرطوم',
        accountId: '555666777888',
      );

      expect(lawyer.specialization, '');
      expect(lawyer.accountId, '555666777888');
      final map = lawyer.toMap();
      expect(map['accountId'], '555666777888');
    });
  });

  group('ChatModel and ChatMessageModel Tests', () {
    test('ChatModel serialization and helper properties', () {
      final now = DateTime.now();
      final chat = ChatModel(
        id: 'chat_client_lawyer',
        participants: ['client_uid', 'lawyer_uid'],
        clientId: 'client_uid',
        clientPhone: '0912345678',
        lawyerId: 'lawyer_uid',
        lawyerPhone: '0987654321',
        clientName: 'عمر العميل',
        lawyerName: 'أ. طارق المحامي',
        clientAccountId: '111122223333',
        lawyerAccountId: '444455556666',
        lastMessage: 'مرحباً، هل أنت متاح؟',
        lastSenderId: 'client_uid',
        lastMessageTime: now,
        unreadByLawyer: 1,
        unreadByClient: 0,
      );

      expect(chat.getOtherPartyName('client_uid'), 'أ. طارق المحامي');
      expect(chat.getOtherPartyName('lawyer_uid'), 'عمر العميل');
      expect(chat.getOtherPartyAccountId('client_uid'), '444455556666');
      expect(chat.getOtherPartyAccountId('lawyer_uid'), '111122223333');
      expect(chat.getOtherPartyRole('client_uid'), 'lawyer');
      expect(chat.getOtherPartyRole('lawyer_uid'), 'client');

      final map = chat.toMap();
      expect(map['clientId'], 'client_uid');
      expect(map['lawyerId'], 'lawyer_uid');
      expect(map['clientAccountId'], '111122223333');
      expect(map['lawyerAccountId'], '444455556666');

      final fromMap = ChatModel.fromMap(map, 'chat_client_lawyer');
      expect(fromMap.clientName, 'عمر العميل');
      expect(fromMap.lawyerName, 'أ. طارق المحامي');
      expect(chat.isLastMessageReadByRecipient('client_uid'), isFalse);

      final readChat = ChatModel(
        id: 'chat_read',
        participants: ['client_uid', 'lawyer_uid'],
        clientId: 'client_uid',
        clientPhone: '0912345678',
        lawyerId: 'lawyer_uid',
        lawyerPhone: '0987654321',
        clientName: 'عمر العميل',
        lawyerName: 'أ. طارق المحامي',
        lastMessage: 'تمام، استلمت الرسالة',
        lastSenderId: 'client_uid',
        unreadByLawyer: 0,
        isLastMessageRead: true,
      );
      expect(readChat.isLastMessageReadByRecipient('client_uid'), isTrue);
    });

    test('ChatMessageModel serialization', () {
      final now = DateTime.now();
      final msg = ChatMessageModel(
        id: 'msg_1',
        chatId: 'chat_client_lawyer',
        senderId: 'client_uid',
        senderName: 'عمر العميل',
        senderRole: 'client',
        senderAccountId: '111122223333',
        text: 'استشارة قانونية بخصوص عقد',
        createdAt: now,
        isRead: false,
      );

      final map = msg.toMap();
      expect(map['senderId'], 'client_uid');
      expect(map['text'], 'استشارة قانونية بخصوص عقد');
      expect(map['isRead'], isFalse);

      final parsed = ChatMessageModel.fromMap(map, 'msg_1');
      expect(parsed.text, 'استشارة قانونية بخصوص عقد');
      expect(parsed.senderName, 'عمر العميل');
      expect(parsed.isRead, isFalse);
    });
  });
}
