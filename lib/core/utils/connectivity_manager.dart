import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../errors/exceptions.dart';

/// Connection state
enum ConnectionState {
  connected,
  disconnected,
  unknown,
}

/// Connectivity state with detailed info
class ConnectivityState {
  final ConnectionState state;
  final ConnectivityResult type;
  final DateTime timestamp;

  const ConnectivityState({
    required this.state,
    required this.type,
    required this.timestamp,
  });

  bool get isConnected => state == ConnectionState.connected;
  bool get isWifi => type == ConnectivityResult.wifi;
  bool get isMobile => type == ConnectivityResult.mobile;
  bool get isEthernet => type == ConnectivityResult.ethernet;

  static const ConnectivityState unknown = ConnectivityState(
    state: ConnectionState.unknown,
    type: ConnectivityResult.none,
    timestamp: null as dynamic, // Will be set by constructor
  );
}

/// Manages connectivity state and provides utilities for connectivity-aware operations
class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  
  final StreamController<ConnectivityState> _stateController = 
    StreamController<ConnectivityState>.broadcast();
  
  ConnectivityState _currentState = ConnectivityState(
    state: ConnectionState.unknown,
    type: ConnectivityResult.none,
    timestamp: DateTime.now(),
  );

  Stream<ConnectivityState> get stateStream => _stateController.stream;
  ConnectivityState get currentState => _currentState;
  bool get isConnected => _currentState.isConnected;

  Future<void> initialize() async {
    // Get initial state
    final result = await _connectivity.checkConnectivity();
    _updateState(result);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateState);
  }

  void _updateState(ConnectivityResult result) {
    final state = ConnectivityState(
      state: result == ConnectivityResult.none 
        ? ConnectionState.disconnected 
        : ConnectionState.connected,
      type: result,
      timestamp: DateTime.now(),
    );

    _currentState = state;
    _stateController.add(state);
  }

  /// Check if connected, throw if not
  Future<void> ensureConnected() async {
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      throw const NoConnectionException();
    }
  }

  /// Wait for connectivity to return
  Future<bool> waitForConnection({Duration? timeout}) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    StreamSubscription<ConnectivityState>? sub;

    sub = stateStream.listen((state) {
      if (state.isConnected) {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    if (timeout != null) {
      Future.delayed(timeout, () {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    return completer.future;
  }

  /// Execute operation with connectivity check
  Future<T> withConnection<T>(
    Future<T> Function() operation, {
    bool waitForConnection = false,
    Duration? waitTimeout,
    String? offlineMessage,
  }) async {
    if (!isConnected) {
      if (waitForConnection) {
        final connected = await this.waitForConnection(timeout: waitTimeout);
        if (!connected) {
          throw NoConnectionException(
            message: offlineMessage ?? 'No internet connection available',
          );
        }
      } else {
        throw NoConnectionException(
          message: offlineMessage ?? 'No internet connection available',
        );
      }
    }

    return operation();
  }

  void dispose() {
    _subscription?.cancel();
    _stateController.close();
  }
}

/// Mixin for making services connectivity-aware
mixin ConnectivityAware {
  ConnectivityManager get connectivityManager;

  Future<T> withConnectionCheck<T>(
    Future<T> Function() operation, {
    String? offlineMessage,
  }) async {
    return connectivityManager.withConnection(
      operation,
      offlineMessage: offlineMessage,
    );
  }
}
