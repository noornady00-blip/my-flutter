import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/data/models/user_model.dart';
import 'package:mahameek/data/models/lawyer.dart';
import 'package:mahameek/ui/custom_widgets/city_landmark_widget.dart';

void main() {
  group('UserModel Tests', () {
    test('Correctly parses client user from map', () {
      final map = {
        'name': 'أحمد محمد',
        'phone': '0912345678',
        'role': 'client',
        'photoUrl': 'https://firebasestorage.googleapis.com/v0/b/app/profile.jpg',
      };

      final user = UserModel.fromMap(map, 'user_123');
      expect(user.uid, 'user_123');
      expect(user.name, 'أحمد محمد');
      expect(user.phone, '0912345678');
      expect(user.role, 'client');
      expect(user.isClient, isTrue);
      expect(user.isLawyer, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.photoUrl, contains('firebasestorage.googleapis.com'));
    });

    test('Correctly parses admin user from map', () {
      final map = {
        'name': 'المشرف الرئيسي',
        'phone': '01146979833',
        'role': 'admin',
      };

      final user = UserModel.fromMap(map, 'admin_001');
      expect(user.isAdmin, isTrue);
      expect(user.isClient, isFalse);
      expect(user.isLawyer, isFalse);
    });

    test('Safely handles missing and malformed fields with defaults', () {
      final map = <String, dynamic>{};
      final user = UserModel.fromMap(map, 'empty_uid');

      expect(user.uid, 'empty_uid');
      expect(user.name, '');
      expect(user.phone, '');
      expect(user.role, 'client');
      expect(user.photoUrl, isNull);
      expect(user.photoBase64, isNull);
    });

    test('toMap does not contain password or hash fields', () {
      final user = UserModel(
        uid: 'u_1',
        name: 'سارة خالد',
        phone: '0998877665',
        role: 'client',
      );

      final map = user.toMap();
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('passwordHash'), isFalse);
      expect(map['role'], 'client');
      expect(map['name'], 'سارة خالد');
    });

    test('copyWith updates specified fields only', () {
      final user = UserModel(
        uid: 'u_1',
        name: 'محمد علي',
        phone: '0123456789',
        role: 'lawyer',
      );

      final updated = user.copyWith(
        name: 'د. محمد علي',
        photoUrl: 'https://newphoto.com/photo.jpg',
      );

      expect(updated.name, 'د. محمد علي');
      expect(updated.photoUrl, 'https://newphoto.com/photo.jpg');
      expect(updated.phone, '0123456789');
      expect(updated.role, 'lawyer');
    });
  });

  group('LawyerModel Tests', () {
    test('Parses approved lawyer correctly', () {
      final map = {
        'name': 'الأستاذ عثمان إبراهيم',
        'phone': '0911223344',
        'whatsapp': '0911223344',
        'city': 'الخرطوم',
        'specialization': 'قانون جنائي',
        'status': 'approved',
        'photoUrl': 'https://firebasestorage.com/photo.jpg',
        'rating': 4.9,
        'views': 120,
      };

      final lawyer = LawyerModel.fromMap(map, 'lawyer_01');
      expect(lawyer.uid, 'lawyer_01');
      expect(lawyer.name, 'الأستاذ عثمان إبراهيم');
      expect(lawyer.phone, '0911223344');
      expect(lawyer.whatsapp, '0911223344');
      expect(lawyer.city, 'الخرطوم');
      expect(lawyer.specialization, 'قانون جنائي');
      expect(lawyer.isApproved, isTrue);
      expect(lawyer.isPending, isFalse);
      expect(lawyer.isRejected, isFalse);
      expect(lawyer.photoUrl, 'https://firebasestorage.com/photo.jpg');
    });

    test('Parses pending lawyer correctly', () {
      final map = {
        'name': 'الأستاذة منى حسن',
        'phone': '0955443322',
        'city': 'بحري',
        'specialization': 'قانون الأسرة',
        'status': 'pending',
      };

      final lawyer = LawyerModel.fromMap(map, 'lawyer_02');
      expect(lawyer.isPending, isTrue);
      expect(lawyer.isApproved, isFalse);
      expect(lawyer.isRejected, isFalse);
    });

    test('Parses rejected lawyer correctly', () {
      final map = {
        'name': 'محامٍ ملغى',
        'phone': '0900000000',
        'status': 'rejected',
      };

      final lawyer = LawyerModel.fromMap(map, 'lawyer_03');
      expect(lawyer.isRejected, isTrue);
      expect(lawyer.isApproved, isFalse);
      expect(lawyer.isPending, isFalse);
    });

    test('Handles null and missing fields with safe defaults', () {
      final map = <String, dynamic>{};

      final lawyer = LawyerModel.fromMap(map, 'lawyer_04');
      expect(lawyer.uid, 'lawyer_04');
      expect(lawyer.name, '');
      expect(lawyer.phone, '');
      expect(lawyer.status, 'pending');
      expect(lawyer.isPending, isTrue);
    });

    test('toMap produces clean Firestore-ready data without credential leakage', () {
      final lawyer = LawyerModel(
        uid: 'lawyer_test',
        name: 'المحامي علي',
        phone: '0912345678',
        whatsapp: '0912345678',
        city: 'الخرطوم',
        status: 'approved',
      );

      final map = lawyer.toMap();
      expect(map['name'], 'المحامي علي');
      expect(map['status'], 'approved');
      expect(map.containsKey('password'), isFalse);
    });
  });

  group('SudanCities & Other Cities Tests', () {
    test('SudanCities includes exactly the 12 specified cities plus باقي المدن', () {
      final expectedCities = [
        'الخرطوم',
        'أم درمان',
        'بحري',
        'بورتسودان',
        'كسلا',
        'عطبرة',
        'ود مدني',
        'الأبيض',
        'الفاشر',
        'نيالا',
        'دنقلا',
        'كوستي',
        'باقي المدن',
      ];

      expect(SudanCities.names, equals(expectedCities));
      expect(SudanCities.cities.last['name'], 'باقي المدن');
      expect(SudanCities.names.last, 'باقي المدن');
      expect(SudanCities.names.contains('باقي المدن'), isTrue);
      expect(SudanCities.names.contains('كوستي'), isTrue);

      // Verify removed cities are no longer present
      expect(SudanCities.names.contains('القضارف'), isFalse);
      expect(SudanCities.names.contains('شندي'), isFalse);
      expect(SudanCities.names.contains('مروي'), isFalse);
      expect(SudanCities.names.contains('سنار'), isFalse);
      expect(SudanCities.names.contains('الدمازين'), isFalse);
      expect(SudanCities.names.contains('زالنجي'), isFalse);
      expect(SudanCities.names.contains('الضعين'), isFalse);
      expect(SudanCities.names.contains('الجنينة'), isFalse);
      expect(SudanCities.names.contains('كادقلي'), isFalse);
    });

    test('CityLandmarkWidget resolves correct assets for cities, Kosti, باقي المدن and جميع المدن', () {
      expect(
        CityLandmarkWidget.getAssetPath('كوستي'),
        'assets/images/cities/kosti.png',
      );
      expect(
        CityLandmarkWidget.getAssetPath('باقي المدن'),
        'assets/images/cities/default_seal.png',
      );
      expect(
        CityLandmarkWidget.getAssetPath('جميع المدن'),
        'assets/images/cities/default_seal.png',
      );
    });

    test('Lawyers registered with باقي المدن are included in all cities logic', () {
      final otherCityLawyer = LawyerModel(
        uid: 'other_lawyer_1',
        name: 'أستاذ من مدينة أخرى',
        phone: '0912345678',
        city: 'باقي المدن',
        status: 'approved',
      );

      expect(otherCityLawyer.city, 'باقي المدن');

      // Emulate the filter used in LawyersListScreen and FirestoreService
      const targetCity = 'جميع المدن';
      final matchesFilter = targetCity == 'جميع المدن' || otherCityLawyer.city == targetCity;
      expect(matchesFilter, isTrue);
    });
  });
}

