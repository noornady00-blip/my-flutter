// ==============================================================================
// 🌐 NETWORK QUALITY & CONNECTIVITY SERVICE
// ==============================================================================
// Accurately determines physical transport (Wi-Fi / Cellular / None / Multiple)
// and verifies real internet reachability via lightweight HTTPS 204 probes.
// ==============================================================================

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Physical transport interface used by the operating system.
enum NetworkTransportType {
  wifi,
  mobile,
  ethernet,
  vpn,
  multiple,
  none,
  unknown;

  String get arabicLabel {
    switch (this) {
      case NetworkTransportType.wifi:
        return 'Wi‑Fi';
      case NetworkTransportType.mobile:
        return 'بيانات الهاتف';
      case NetworkTransportType.ethernet:
        return 'إيثرنت';
      case NetworkTransportType.vpn:
        return 'شبكة خاصة (VPN)';
      case NetworkTransportType.multiple:
        return 'Wi‑Fi وبيانات الهاتف';
      case NetworkTransportType.none:
        return 'لا توجد شبكة';
      case NetworkTransportType.unknown:
        return 'شبكة غير معروفة';
    }
  }
}

/// Overall connection status states used throughout the application.
enum NetworkStatus {
  online,              // Physical link active AND verified real internet reachability
  connectedNoInternet, // Physical link active (Wi-Fi/cellular) BUT NO verified internet access
  noConnection,        // No physical network link (Wi-Fi and cellular both off / airplane mode)
  restored,            // Connection recently restored (triggers temporary green banner)
}

/// Comprehensive, immutable snapshot of the client's network state.
@immutable
class NetworkState {
  final NetworkTransportType transportType;
  final bool hasInternet;
  final bool isRestored;
  final NetworkStatus status;
  final String message;
  final DateTime timestamp;

  const NetworkState({
    required this.transportType,
    required this.hasInternet,
    this.isRestored = false,
    required this.status,
    required this.message,
    required this.timestamp,
  });

  /// Factory for initial state (defaults to online to prevent false offline flicker on launch)
  factory NetworkState.initial() => NetworkState(
        transportType: NetworkTransportType.unknown,
        hasInternet: true,
        isRestored: false,
        status: NetworkStatus.online,
        message: 'متصل بالإنترنت',
        timestamp: DateTime.now(),
      );

  NetworkState copyWith({
    NetworkTransportType? transportType,
    bool? hasInternet,
    bool? isRestored,
    NetworkStatus? status,
    String? message,
    DateTime? timestamp,
  }) {
    return NetworkState(
      transportType: transportType ?? this.transportType,
      hasInternet: hasInternet ?? this.hasInternet,
      isRestored: isRestored ?? this.isRestored,
      status: status ?? this.status,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkState &&
          runtimeType == other.runtimeType &&
          transportType == other.transportType &&
          hasInternet == other.hasInternet &&
          isRestored == other.isRestored &&
          status == other.status &&
          message == other.message;

  @override
  int get hashCode =>
      transportType.hashCode ^
      hasInternet.hashCode ^
      isRestored.hashCode ^
      status.hashCode ^
      message.hashCode;

  @override
  String toString() =>
      'NetworkState(transport: $transportType, hasInternet: $hasInternet, status: $status, isRestored: $isRestored, message: "$message")';
}

// ==============================================================================
// 🔌 ABSTRACTIONS FOR TESTABILITY & DEPENDENCY INJECTION
// ==============================================================================

/// Contract for real internet reachability probes.
abstract class InternetReachabilityChecker {
  Future<bool> checkReachability({Duration timeout = const Duration(milliseconds: 2800)});
}

/// Default probe implementation executing lightweight, parallel DNS & HTTPS 204 probes.
class DefaultInternetReachabilityChecker implements InternetReachabilityChecker {
  static const List<String> probeEndpoints = [
    'https://www.gstatic.com/generate_204',
    'https://clients3.google.com/generate_204',
    'https://cloudflare.com/cdn-cgi/trace',
  ];

  @override
  Future<bool> checkReachability({Duration timeout = const Duration(milliseconds: 2500)}) async {
    if (kIsWeb) return true;

    // 1. Ultra-fast DNS lookup (resolves in 15-40ms on healthy networks)
    try {
      final dnsResults = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 1200));
      if (dnsResults.isNotEmpty && dnsResults[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      // Proceed to HTTP probes if DNS is restricted or slow
    }

    // 2. Parallel HTTP 204 racing probes: returns true immediately when the FIRST endpoint responds
    try {
      final completer = Completer<bool>();
      int failures = 0;

      for (final url in probeEndpoints) {
        _probeUrl(url, timeout).then((ok) {
          if (ok && !completer.isCompleted) {
            completer.complete(true);
          } else {
            failures++;
            if (failures >= probeEndpoints.length && !completer.isCompleted) {
              completer.complete(false);
            }
          }
        }).catchError((_) {
          failures++;
          if (failures >= probeEndpoints.length && !completer.isCompleted) {
            completer.complete(false);
          }
        });
      }

      return await completer.future.timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeUrl(String url, Duration timeout) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      await response.drain().timeout(const Duration(milliseconds: 350)).catchError((_) {});
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }
}

/// Contract for physical network connectivity interface.
abstract class ConnectivityInterface {
  Future<List<ConnectivityResult>> checkConnectivity();
  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

/// Default wrapper around `connectivity_plus`.
class DefaultConnectivityWrapper implements ConnectivityInterface {
  final Connectivity _connectivity;
  DefaultConnectivityWrapper({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() =>
      _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}

// ==============================================================================
// 🌐 NETWORK SERVICE IMPLEMENTATION
// ==============================================================================

/// Service monitoring physical connectivity and verifying genuine internet access.
class NetworkService {
  static NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;

  final ConnectivityInterface _connectivity;
  final InternetReachabilityChecker _reachabilityChecker;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicTimer;
  Timer? _restoredTimer;

  Completer<NetworkState>? _activeCheckCompleter;
  NetworkStatus _previousStatus = NetworkStatus.online;

  // ---------------------------------------------------------------------------
  // Notifiers & Public State
  // ---------------------------------------------------------------------------
  /// Rich State Notifier
  final ValueNotifier<NetworkState> stateNotifier;

  /// Backward-compatible Status Notifier
  final ValueNotifier<NetworkStatus> statusNotifier;

  /// Backward-compatible Boolean Notifier
  final ValueNotifier<bool> isOnlineNotifier;

  /// Transport Type Notifier
  final ValueNotifier<NetworkTransportType> transportNotifier;

  NetworkState get currentState => stateNotifier.value;
  NetworkStatus get currentStatus => statusNotifier.value;
  NetworkTransportType get currentTransport => transportNotifier.value;

  bool get isOnline =>
      statusNotifier.value == NetworkStatus.online ||
      statusNotifier.value == NetworkStatus.restored;

  NetworkService._internal({
    ConnectivityInterface? connectivity,
    InternetReachabilityChecker? reachabilityChecker,
  })  : _connectivity = connectivity ?? DefaultConnectivityWrapper(),
        _reachabilityChecker =
            reachabilityChecker ?? DefaultInternetReachabilityChecker(),
        stateNotifier = ValueNotifier<NetworkState>(NetworkState.initial()),
        statusNotifier = ValueNotifier<NetworkStatus>(NetworkStatus.online),
        isOnlineNotifier = ValueNotifier<bool>(true),
        transportNotifier =
            ValueNotifier<NetworkTransportType>(NetworkTransportType.unknown);

  /// Factory for testing and dependency injection
  @visibleForTesting
  static NetworkService createForTesting({
    required ConnectivityInterface connectivity,
    required InternetReachabilityChecker reachabilityChecker,
  }) {
    final service = NetworkService._internal(
      connectivity: connectivity,
      reachabilityChecker: reachabilityChecker,
    );
    _instance = service;
    return service;
  }

  // ---------------------------------------------------------------------------
  // Initialization & Probing
  // ---------------------------------------------------------------------------
  /// Initializes background listeners, immediate status probe, and periodic heartbeats
  Future<void> init({Duration heartbeatInterval = const Duration(seconds: 15)}) async {
    // 1. Initial immediate probe
    await checkNow();

    // 2. Listen to OS connectivity interface changes
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      await _evaluateResults(results);
    });

    // 3. Periodic heartbeat to detect stealth drops behind captive portals / dead Wi-Fi
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(heartbeatInterval, (_) async {
      await checkNow();
    });
  }

  /// Maps physical ConnectivityResult list to NetworkTransportType
  NetworkTransportType determineTransport(List<ConnectivityResult> results) {
    final nonNone = results.where((r) => r != ConnectivityResult.none).toList();
    if (nonNone.isEmpty) return NetworkTransportType.none;

    final hasWifi = nonNone.contains(ConnectivityResult.wifi);
    final hasMobile = nonNone.contains(ConnectivityResult.mobile);
    final hasEthernet = nonNone.contains(ConnectivityResult.ethernet);
    final hasVpn = nonNone.contains(ConnectivityResult.vpn);

    if (hasWifi && hasMobile) return NetworkTransportType.multiple;
    if (hasWifi) return NetworkTransportType.wifi;
    if (hasMobile) return NetworkTransportType.mobile;
    if (hasEthernet) return NetworkTransportType.ethernet;
    if (hasVpn) return NetworkTransportType.vpn;
    if (nonNone.contains(ConnectivityResult.other)) return NetworkTransportType.unknown;

    return NetworkTransportType.unknown;
  }

  /// Computes human-friendly Arabic message matching the exact network scenario
  String computeArabicMessage({
    required NetworkTransportType transport,
    required bool hasInternet,
    required bool isRestored,
  }) {
    if (isRestored) {
      return 'تم استعادة الاتصال بالإنترنت';
    }

    if (!hasInternet) {
      switch (transport) {
        case NetworkTransportType.wifi:
          return 'متصل بشبكة Wi‑Fi بدون إنترنت';
        case NetworkTransportType.mobile:
          return 'بيانات الهاتف متصلة ولكن لا يوجد إنترنت';
        case NetworkTransportType.none:
          return 'لا يوجد اتصال Wi‑Fi أو بيانات';
        case NetworkTransportType.multiple:
          return 'متصل بالشبكة ولكن لا يوجد إنترنت';
        case NetworkTransportType.ethernet:
          return 'متصل بالشبكة المحلية بدون إنترنت';
        case NetworkTransportType.vpn:
        case NetworkTransportType.unknown:
          return 'الشبكة المتصل بها لا يتوفر بها إنترنت';
      }
    }

    switch (transport) {
      case NetworkTransportType.wifi:
        return 'متصل بالإنترنت عبر Wi‑Fi';
      case NetworkTransportType.mobile:
        return 'متصل بالإنترنت عبر بيانات الهاتف';
      case NetworkTransportType.multiple:
        return 'متصل بالإنترنت عبر Wi‑Fi أو البيانات';
      case NetworkTransportType.none:
        return 'لا يوجد اتصال Wi‑Fi أو بيانات';
      default:
        return 'متصل بالإنترنت';
    }
  }

  /// Evaluates incoming connectivity results and probes real internet
  Future<NetworkState> _evaluateResults(List<ConnectivityResult> results) async {
    final transport = determineTransport(results);

    // If no physical link, immediately return noConnection without wasting HTTP probes
    if (transport == NetworkTransportType.none) {
      final newState = NetworkState(
        transportType: NetworkTransportType.none,
        hasInternet: false,
        isRestored: false,
        status: NetworkStatus.noConnection,
        message: computeArabicMessage(
          transport: NetworkTransportType.none,
          hasInternet: false,
          isRestored: false,
        ),
        timestamp: DateTime.now(),
      );
      return _applyState(newState);
    }

    // Verify genuine internet reachability via HTTPS 204 probe
    final reachable = await _reachabilityChecker.checkReachability();

    final status = reachable
        ? NetworkStatus.online
        : NetworkStatus.connectedNoInternet;

    final newState = NetworkState(
      transportType: transport,
      hasInternet: reachable,
      isRestored: false,
      status: status,
      message: computeArabicMessage(
        transport: transport,
        hasInternet: reachable,
        isRestored: false,
      ),
      timestamp: DateTime.now(),
    );

    return _applyState(newState);
  }

  /// Explicit probe triggered manually or upon retry buttons.
  /// Prevents concurrent overlapping checks via mutex/completer.
  Future<NetworkState> checkNow() async {
    if (_activeCheckCompleter != null && !_activeCheckCompleter!.isCompleted) {
      return _activeCheckCompleter!.future;
    }

    _activeCheckCompleter = Completer<NetworkState>();

    try {
      final results = await _connectivity.checkConnectivity();
      final evaluated = await _evaluateResults(results);
      if (!_activeCheckCompleter!.isCompleted) {
        _activeCheckCompleter!.complete(evaluated);
      }
      return evaluated;
    } catch (_) {
      final fallback = stateNotifier.value;
      if (!_activeCheckCompleter!.isCompleted) {
        _activeCheckCompleter!.complete(fallback);
      }
      return fallback;
    } finally {
      _activeCheckCompleter = null;
    }
  }

  /// Convenience boolean check: returns true ONLY when genuine internet is verified.
  Future<bool> hasInternet() async {
    final state = await checkNow();
    return state.hasInternet;
  }

  // ---------------------------------------------------------------------------
  // State Machine & Change Dispatcher
  // ---------------------------------------------------------------------------
  NetworkState _applyState(NetworkState incoming) {
    // 1. Detect transition from offline to online (restored event)
    final bool wasOffline = _previousStatus == NetworkStatus.noConnection ||
        _previousStatus == NetworkStatus.connectedNoInternet;
    final bool isNowOnline = incoming.hasInternet && incoming.status == NetworkStatus.online;

    if (isNowOnline && wasOffline) {
      _restoredTimer?.cancel();
      final restoredState = incoming.copyWith(
        isRestored: true,
        status: NetworkStatus.restored,
        message: computeArabicMessage(
          transport: incoming.transportType,
          hasInternet: true,
          isRestored: true,
        ),
      );

      _emit(restoredState);
      _previousStatus = NetworkStatus.online;

      // Auto-transition from restored to online banner dismiss after 3.2 seconds
      _restoredTimer = Timer(const Duration(milliseconds: 3200), () {
        if (statusNotifier.value == NetworkStatus.restored) {
          final regularOnlineState = stateNotifier.value.copyWith(
            isRestored: false,
            status: NetworkStatus.online,
            message: computeArabicMessage(
              transport: stateNotifier.value.transportType,
              hasInternet: true,
              isRestored: false,
            ),
          );
          _emit(regularOnlineState);
        }
      });
      return restoredState;
    }

    // Normal state application
    if (incoming.status != NetworkStatus.restored) {
      _previousStatus = incoming.status;
    }
    _emit(incoming);
    return incoming;
  }

  void _emit(NetworkState newState) {
    // Prevent redundant notifications if state is unchanged
    if (stateNotifier.value != newState) {
      stateNotifier.value = newState;
    }
    if (statusNotifier.value != newState.status) {
      statusNotifier.value = newState.status;
    }
    final onlineVal = newState.status == NetworkStatus.online ||
        newState.status == NetworkStatus.restored;
    if (isOnlineNotifier.value != onlineVal) {
      isOnlineNotifier.value = onlineVal;
    }
    if (transportNotifier.value != newState.transportType) {
      transportNotifier.value = newState.transportType;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _periodicTimer?.cancel();
    _restoredTimer?.cancel();
    stateNotifier.dispose();
    statusNotifier.dispose();
    isOnlineNotifier.dispose();
    transportNotifier.dispose();
  }
}
