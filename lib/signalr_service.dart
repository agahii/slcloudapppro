import 'dart:async';

import 'package:signalr_core/signalr_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles connection to the SignalR chat hub with automatic reconnection.
class SignalRService {
  SignalRService._internal();
  static final SignalRService instance = SignalRService._internal();

  static const String _hubUrl = 'http://api.slcloud.3em.tech/chatHub';

  HubConnection? _connection;
  bool _isStarting = false;

  /// Returns current SignalR connection if available.
  HubConnection? get connection => _connection;

  /// Starts the SignalR connection using the stored token.
  Future<void> start() async {
    if (_isStarting) return;
    if (_connection != null &&
        _connection!.state != HubConnectionState.disconnected) {
      return;
    }
    _isStarting = true;

    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('token') ?? prefs.getString('accessToken') ?? '';

    _connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.onreconnecting((error) {
      // ignore: avoid_print
      print('SignalR reconnecting: ' + (error?.toString() ?? '')); 
    });

    _connection!.onreconnected((connectionId) {
      // ignore: avoid_print
      print('SignalR reconnected: ' + (connectionId ?? ''));
    });

    _connection!.onclose((error) {
      // ignore: avoid_print
      print('SignalR connection closed: ' + (error?.toString() ?? ''));
    });

    // Attempt to start the connection until it succeeds.
    while (_connection!.state == HubConnectionState.disconnected) {
      try {
        await _connection!.start();
      } catch (_) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    _isStarting = false;
  }

  /// Stops the SignalR connection if active.
  Future<void> stop() async {
    if (_connection != null) {
      await _connection!.stop();
      _connection = null;
    }
  }
}

