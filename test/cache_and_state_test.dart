import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahameek/data/models/lawyer.dart';
import 'package:mahameek/network/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirestoreService Cache Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FirestoreService.inMemoryApprovedLawyers = null;
    });

    test('Local cache stores and loads approved lawyers correctly', () async {
      final service = FirestoreService();
      final List<LawyerModel> sampleLawyers = [
        LawyerModel(
          uid: 'l1',
          name: 'المحامي الأول',
          phone: '0911111111',
          city: 'الخرطوم',
          status: 'approved',
        ),
        LawyerModel(
          uid: 'l2',
          name: 'المحامي الثاني',
          phone: '0922222222',
          city: 'أم درمان',
          status: 'approved',
        ),
      ];

      await service.cacheApprovedLawyersLocally(sampleLawyers);
      final cached = await service.getCachedApprovedLawyers();

      expect(cached, isNotNull);
      expect(cached.length, equals(2));
      expect(cached[0].uid, equals('l1'));
      expect(cached[1].uid, equals('l2'));
      expect(cached[0].isApproved, isTrue);
    });

    test('When remote data becomes empty, cache is invalidated and does not show stale lawyers', () async {
      final service = FirestoreService();

      // Populate cache with stale lawyer
      await service.cacheApprovedLawyersLocally([
        LawyerModel(
          uid: 'l_stale',
          name: 'محامٍ سابق',
          phone: '0900000000',
          status: 'approved',
        ),
      ]);

      expect(FirestoreService.inMemoryApprovedLawyers!.length, equals(1));

      // Simulate remote live result returning empty list (e.g. all lawyers deleted/rejected)
      final emptyRemoteResult = <LawyerModel>[];
      await service.cacheApprovedLawyersLocally(emptyRemoteResult);

      final cachedAfterSync = await service.getCachedApprovedLawyers();
      expect(cachedAfterSync, isEmpty);
      expect(FirestoreService.inMemoryApprovedLawyers, isEmpty);
    });
  });
}
