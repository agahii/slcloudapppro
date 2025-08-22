import 'dart:async';
import 'package:signalr_core/signalr_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignalRService {
  SignalRService._internal();
  static final SignalRService instance = SignalRService._internal();

  // Prefer HTTPS in emulator/production. If you MUST use http, allow cleartext in Manifest.
  static const String _hubUrl = 'https://api.slcloud.3em.tech/chatHub';

  HubConnection? _connection;

  // Coalesce concurrent start() calls
  Completer<void>? _startCompleter;

  HubConnection? get connection => _connection;

  Future<void> start() async {
    // If a start is already in-flight, await it instead of starting again.
    if (_startCompleter != null) {
      return _startCompleter!.future;
    }

    // If already connected or connecting/reconnecting, do nothing.
    if (_connection != null &&
        _connection!.state != HubConnectionState.disconnected) {
      return;
    }

    final completer = Completer<void>();
    _startCompleter = completer;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await prefs.getString('token');
      print('[SignalR] using token=$token');
      // Build a fresh connection every time we start from a fully stopped state.
      _connection =  HubConnectionBuilder()
          .withUrl(
        _hubUrl,
        HttpConnectionOptions(
          transport: HttpTransportType.webSockets,
          accessTokenFactory: () async => token,

        ),
      )
          .withAutomaticReconnect([0, 2000, 5000, 10000, 20000, 30000])
          .build();

      // Keep-alive / timeouts
      _connection!.keepAliveIntervalInMilliseconds = 15000;
      _connection!.serverTimeoutInMilliseconds = 60000;

      // Lightweight logging
      _connection!.onreconnecting((e) => print('[SignalR] reconnecting $e'));
      _connection!.onreconnected((id) => print('[SignalR] reconnected id=$id'));
      _connection!.onclose((e) => print('[SignalR] closed $e'));

      await _connection!.start();
      print('[SignalR] started. state=${_connection!.state}');
      if (!completer.isCompleted) completer.complete();
    } catch (e, st) {
      print('[SignalR] start failed: $e');
      print(st);
      // Complete with error exactly once
      if (!completer.isCompleted) completer.completeError(e, st);
      rethrow;
    } finally {
      // Allow new starts AFTER this one has finished (success or error)
      _startCompleter = null;
    }
  }

  Future<void> stop() async {
    // If a start is in-flight, wait for it to settle to avoid racing stop vs start.
    final sc = _startCompleter;
    if (sc != null) {
      try { await sc.future; } catch (_) {/* ignore start error here */ }
    }

    final c = _connection;
    if (c != null) {
      try {
        await c.stop();
        print('[SignalR] stopped.');
      } finally {
        _connection = null;
      }
    }
  }
}