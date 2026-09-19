import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mahameek/network/network_service.dart';

/// Mock Connectivity Interface
class MockConnectivity implements ConnectivityInterface {
  List<ConnectivityResult> connectivityResults;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  MockConnectivity(this.connectivityResults);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => connectivityResults;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  void emit(List<ConnectivityResult> results) {
    connectivityResults = results;
    _controller.add(results);
  }

  void dispose() {
    _controller.close();
  }
}

/// Mock Internet Reachability Checker
class MockReachabilityChecker implements InternetReachabilityChecker {
  bool isReachable;
  int checkCount = 0;
  Completer<void>? delayCompleter;

  MockReachabilityChecker(this.isReachable);

  @override
  Future<bool> checkReachability({Duration timeout = const Duration(milliseconds: 2800)}) async {
    checkCount++;
    if (delayCompleter != null) {
      await delayCompleter!.future;
    }
    return isReachable;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkService Comprehensive Unit Tests', () {
    test('1. Wi-Fi with genuine Internet (online)', () async {
      final mockConnectivity = MockConnectivity([ConnectivityResult.wifi]);
      final mockReachability = MockReachabilityChecker(true);

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      final state = await service.checkNow();

      expect(state.transportType, equals(NetworkTransportType.wifi));
      expect(state.hasInternet, isTrue);
      expect(state.status, equals(NetworkStatus.online));
      expect(state.message, equals('متصل بالإنترنت عبر Wi‑Fi'));
      expect(await service.hasInternet(), isTrue);
      expect(service.isOnline, isTrue);
      expect(mockReachability.checkCount, equals(2));
    });

    test('2. Wi-Fi without Internet (connectedNoInternet)', () async {
      final mockConnectivity = MockConnectivity([ConnectivityResult.wifi]);
      final mockReachability = MockReachabilityChecker(false);

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      final state = await service.checkNow();

      expect(state.transportType, equals(NetworkTransportType.wifi));
      expect(state.hasInternet, isFalse);
      expect(state.status, equals(NetworkStatus.connectedNoInternet));
      expect(state.message, equals('متصل بشبكة Wi‑Fi بدون إنترنت'));
      expect(await service.hasInternet(), isFalse);
      expect(service.isOnline, isFalse);
    });

    test('3. Mobile data with genuine Internet (online)', () async {
      final mockConnectivity = MockConnectivity([ConnectivityResult.mobile]);
      final mockReachability = MockReachabilityChecker(true);

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      final state = await service.checkNow();

      expect(state.transportType, equals(NetworkTransportType.mobile));
      expect(state.hasInternet, isTrue);
      expect(state.status, equals(NetworkStatus.online));
      expect(state.message, equals('متصل بالإنترنت عبر بيانات الهاتف'));
      expect(await service.hasInternet(), isTrue);
    });

    test('4. Mobile data without Internet (connectedNoInternet)', () async {
      final mockConnectivity = MockConnectivity([ConnectivityResult.mobile]);
      final mockReachability = MockReachabilityChecker(false);

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      final state = await service.checkNow();

      expect(state.transportType, equals(NetworkTransportType.mobile));
      expect(state.hasInternet, isFalse);
      expect(state.status, equals(NetworkStatus.connectedNoInternet));
      expect(state.message, equals('بيانات الهاتف متصلة ولكن لا يوجد إنترنت'));
      expect(await service.hasInternet(), isFalse);
    });

    test('5. No Physical Connection (noConnection)', () async {
      final mockConnectivity = MockConnectivity([ConnectivityResult.none]);
      final mockReachability = MockReachabilityChecker(false);

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      final state = await service.checkNow();

      expect(state.transportType, equals(NetworkTransportType.none));
      expect(state.hasInternet, isFalse);
      expect(state.status, equals(NetworkStatus.noConnection));
      expect(state.message, equals('لا يوجد اتصال Wi‑Fi أو بيانات'));
      expect(await service.hasInternet(), isFalse);
      // Reachability probe should not even be called when there is no physical link
      expect(mockReachability.checkCount, equals(0));
    });

    test('6. Multiple Connections (Wi-Fi + Cellular) with Internet', () async {
      final mockConnectivity = MockConnectivity([
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
      ]);
      final mockReachability = MockReachabilityChecker(true);

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      final state = await service.checkNow();

      expect(state.transportType, equals(NetworkTransportType.multiple));
      expect(state.hasInternet, isTrue);
      expect(state.status, equals(NetworkStatus.online));
      expect(state.message, equals('متصل بالإنترنت عبر Wi‑Fi أو البيانات'));
    });

    test('7. Restoration transition from offline to online (isRestored)', () async {
      final mockConnectivity = MockConnectivity([ConnectivityResult.wifi]);
      final mockReachability = MockReachabilityChecker(false);

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      // Step 1: Initial check establishes offline state
      final firstState = await service.checkNow();
      expect(firstState.status, equals(NetworkStatus.connectedNoInternet));
      expect(firstState.isRestored, isFalse);

      // Step 2: Internet comes back online
      mockReachability.isReachable = true;
      final secondState = await service.checkNow();

      expect(secondState.status, equals(NetworkStatus.restored));
      expect(secondState.isRestored, isTrue);
      expect(secondState.message, equals('تم استعادة الاتصال بالإنترنت'));
      expect(service.statusNotifier.value, equals(NetworkStatus.restored));
      expect(service.isOnline, isTrue);
    });

    test('8. Concurrent check deduplication (Mutex)', () async {
      final mockConnectivity = MockConnectivity([ConnectivityResult.wifi]);
      final mockReachability = MockReachabilityChecker(true);

      // Add controlled delay to reachability check
      final completer = Completer<void>();
      mockReachability.delayCompleter = completer;

      final service = NetworkService.createForTesting(
        connectivity: mockConnectivity,
        reachabilityChecker: mockReachability,
      );

      // Launch 3 concurrent calls
      final future1 = service.checkNow();
      final future2 = service.checkNow();
      final future3 = service.checkNow();

      // Release reachability check
      completer.complete();

      final results = await Future.wait([future1, future2, future3]);

      expect(results[0].status, equals(NetworkStatus.online));
      expect(results[1].status, equals(NetworkStatus.online));
      expect(results[2].status, equals(NetworkStatus.online));
      // Only 1 reachability probe should have executed across all 3 concurrent callers
      expect(mockReachability.checkCount, equals(1));
    });
  });
}
