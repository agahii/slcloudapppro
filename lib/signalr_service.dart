import 'dart:io';
import 'package:signalr_core/signalr_core.dart';
import 'package:http/io_client.dart';

/// A simple singleton wrapper around [HubConnection] so a single
/// SignalR connection can be shared across the entire app lifecycle.
class SignalRService {
  SignalRService._internal();
  static final SignalRService instance = SignalRService._internal();

  HubConnection? _connection;

  Future<void> start(String userToken) async {
    // --- DEV ONLY: enable to test TLS chain problems ---
    // final insecureClient = IOClient(
    //   HttpClient()..badCertificateCallback = (cert, host, port) => true,
    // );

    _connection = HubConnectionBuilder()
        .withUrl(
      'https://api.slcloud.3em.tech/chatHub',
      HttpConnectionOptions(
        accessTokenFactory: () async => userToken,
        transport: HttpTransportType.webSockets,
      ),
    )
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
