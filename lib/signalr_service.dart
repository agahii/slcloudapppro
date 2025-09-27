import 'dart:io';
import 'package:signalr_core/signalr_core.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;

/// A simple singleton wrapper around [HubConnection] so a single
/// SignalR connection can be shared across the entire app lifecycle.
class SignalRService {
  SignalRService._internal();
  static final SignalRService instance = SignalRService._internal();

  HubConnection? _connection;

  bool get isConnected => _connection?.state == HubConnectionState.connected;

  HubConnectionState? get state => _connection?.state;

  Future<void> start(String userToken) async {
    // --- DEV ONLY: enable to test TLS chain problems ---
    // final insecureClient = IOClient(
    //   HttpClient()..badCertificateCallback = (cert, host, port) => true,
    // );

    // Prefer WebSockets automatically if the server advertises it via negotiate.
    bool preferWebSockets = false;
    try {
      final res = await http.post(
        Uri.parse('https://api.slcloud.3em.tech/chatHub/negotiate?negotiateVersion=1'),
        headers: { 'Authorization': 'Bearer $userToken' },
      ).timeout(const Duration(seconds: 10));
      final body = res.body;
      if (res.statusCode == 200 && body.contains('WebSockets')) {
        preferWebSockets = true;
      }
    } catch (_) {
      // If negotiate fails (offline etc.), fall back to the library defaults.
    }

    final options = HttpConnectionOptions(
      accessTokenFactory: () async => userToken,
      // If websockets are available, skip negotiation and go straight to WS.
      // Otherwise, let the client negotiate and pick SSE/LongPolling.
      transport: preferWebSockets ? HttpTransportType.webSockets : null,
      skipNegotiation: preferWebSockets,
    );

    _connection = HubConnectionBuilder()
        .withUrl('https://api.slcloud.3em.tech/chatHub', options)
        .withAutomaticReconnect()
        .build();

    // 4) Keepalive / timeouts
    _connection!.serverTimeoutInMilliseconds = 60000;
    _connection!.keepAliveIntervalInMilliseconds = 15000;

    // Optional logging
    _connection!.onclose((e) => print('SignalR closed: $e'));
    _connection!.onreconnected((_) => print('SignalR reconnected'));
    _connection!.onreconnecting((e) => print('SignalR reconnecting: $e'));

    // Start
    try {
      await _connection!.start();
      print('SignalR connected: ${_connection!.connectionId}');
    } on Exception catch (e) {
      print('SignalR start error: $e');
      rethrow;
    }
  }

  Future<void> stop() async => _connection?.stop();

  Future<void> sendToServer(String method, Object? arg) async {
    await _connection?.invoke(method, args: [arg]);
  }
}
