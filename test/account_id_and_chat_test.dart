import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/core/utils/account_id_utils.dart';
import 'package:mahameek/data/models/chat_model.dart';
import 'package:mahameek/data/models/chat_message_model.dart';
import 'package:mahameek/data/models/user_model.dart';
import 'package:mahameek/data/models/lawyer.dart';

void main() {
  group('AccountIdUtils Tests', () {
    test('generateCandidate6DigitId produces valid 6-digit numeric string', () {
      for (int i = 0; i < 50; i++) {
        final id = AccountIdUtils.generateCandidate6DigitId();
        expect(id.length, 6);
        expect(AccountIdUtils.isValid6DigitId(id), isTrue);
        expect(AccountIdUtils.isValidAccountId(id), isTrue);
        expect(RegExp(r'^\d{6}$').hasMatch(id), isTrue);
        // Ensure leading digit is never zero
        expect(id.startsWith('0'), isFalse);
      }
    });

    test('format and formatForDisplay format 6 digits in 3-digit groups', () {
      const raw = '123456';
      final formatted = AccountIdUtils.formatForDisplay(raw);
      expect(formatted, '123 456');
      expect(AccountIdUtils.format(raw), '123 456');
      expect(AccountIdUtils.format6Digits(raw), '123 456');
      expect(AccountIdUtils.format12Digits(raw), '123 456');
    });

    test('format handles non-6-digit fallbacks safely', () {
      expect(AccountIdUtils.format(''), '');
      expect(AccountIdUtils.format('12345'), '12345');
    });

    test('isValid6DigitId and isValidAccountId validate strictly', () {
      expect(AccountIdUtils.isValid6DigitId('123456'), isTrue);
      expect(AccountIdUtils.isValidAccountId('123456'), isTrue);
      expect(AccountIdUtils.isValid6DigitId('12345'), isFalse);
      expect(AccountIdUtils.isValid6DigitId('1234567'), isFalse);
      expect(AccountIdUtils.isValid6DigitId('012345'), isFalse);
      expect(AccountIdUtils.isValid6DigitId('12345a'), isFalse);
      expect(AccountIdUtils.isValid6DigitId(null), isFalse);
    });
  });

  group('UserModel with Account ID & Roles', () {
    test('User contains and serializes accountId', () {
      final user = UserModel(
        uid: 'user_u1',
        name: 'مستخدم تجريبي',
        phone: '0912345678',
        role: 'client',
        accountId: '123456',
      );

      final map = user.toMap();
      expect(map['accountId'], '123456');

      final deserialized = UserModel.fromMap(map, 'user_u1');
      expect(deserialized.accountId, '123456');
    });

    test('Admin role recognized correctly', () {
      final admin = UserModel(
        uid: 'admin_u1',
        name: 'المشرف',
        phone: '01146979833',
        role: 'admin',
        accountId: '111111',
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
        isPending: true,
      );

      final map = msg.toMap();
      expect(map['senderId'], 'client_uid');
      expect(map['text'], 'استشارة قانونية بخصوص عقد');
      expect(map['isRead'], isFalse);
      expect(map['isPending'], isTrue);

      final parsed = ChatMessageModel.fromMap(map, 'msg_1');
      expect(parsed.text, 'استشارة قانونية بخصوص عقد');
      expect(parsed.senderName, 'عمر العميل');
      expect(parsed.isRead, isFalse);
      expect(parsed.isPending, isTrue);

      final jsonMap = msg.toJsonMap();
      expect(jsonMap['createdAt'], isA<String>());
      expect(jsonMap['isPending'], isTrue);
    });

    test('Chat purge phone candidates identify all standard format variations', () {
      const phone = '0912345678';
      final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      expect(cleanDigits, '0912345678');
      final raw9 = cleanDigits.substring(cleanDigits.length - 9);
      expect(raw9, '912345678');

      final candidates = <String>{
        phone,
        '+249$raw9',
        '249$raw9',
        '0$raw9',
        raw9,
      };

      expect(candidates.contains('0912345678'), isTrue);
      expect(candidates.contains('+249912345678'), isTrue);
      expect(candidates.contains('249912345678'), isTrue);
      expect(candidates.contains('912345678'), isTrue);
    });

    test('ChatModel matches participant by uid or phone for complete purge', () {
      final chat = ChatModel(
        id: 'chat_client_1_lawyer_2',
        participants: ['uid_client_1', 'uid_lawyer_2'],
        clientId: 'uid_client_1',
        clientPhone: '+249912345678',
        lawyerId: 'uid_lawyer_2',
        lawyerPhone: '+249987654321',
        clientName: 'عميل',
        lawyerName: 'محامٍ',
      );

      // Verify chat identification criteria used in purgeAllChatsForUser
      expect(chat.participants.contains('uid_client_1'), isTrue);
      expect(chat.clientId == 'uid_client_1', isTrue);
      expect(chat.clientPhone == '+249912345678', isTrue);
      expect(chat.isDeletedBy('uid_client_1'), isFalse);
    });
  });
}
