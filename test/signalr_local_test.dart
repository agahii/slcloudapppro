import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_core/signalr_core.dart';

class _TrustLocalhostHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      // Trust local/self-signed certs for localhost testing only.
      return host == 'localhost' || host == '127.0.0.1' || host == '::1';
    };
    return client;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = _TrustLocalhostHttpOverrides();
  });

  test('connects to local SignalR hub', () async {
    final base = const String.fromEnvironment('TEST_BASE_URL', defaultValue: 'https://localhost:7271');
    final username = const String.fromEnvironment('TEST_USERNAME');
    final password = const String.fromEnvironment('TEST_PASSWORD');
    if (username.isEmpty || password.isEmpty) {
      fail('Provide TEST_USERNAME and TEST_PASSWORD via --dart-define');
    }

    // 1) Login to local API
    final loginUri = Uri.parse('$base/api/Account/loginMobile');
    final loginResp = await http
        .post(loginUri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'mobile': username, 'password': password}))
        .timeout(const Duration(seconds: 15));
    expect(loginResp.statusCode, 200, reason: 'Login HTTP ${loginResp.statusCode}: ${loginResp.body}');
    final loginJson = jsonDecode(loginResp.body) as Map<String, dynamic>;
    expect(loginJson['responseCode'], 1000, reason: 'Login failed: ${loginResp.body}');
    final token = (loginJson['data'] as Map<String, dynamic>)['token'] as String;
    expect(token.isNotEmpty, true, reason: 'Missing token');

    // 2) Optional negotiate to discover transports
    final negResp = await http
        .post(Uri.parse('$base/chatHub/negotiate?negotiateVersion=1'), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
    expect(negResp.statusCode, 200, reason: 'Negotiate failed: ${negResp.body}');
    final neg = jsonDecode(negResp.body) as Map<String, dynamic>;
    final transports = ((neg['availableTransports'] ?? []) as List)
        .map((e) => (e as Map)['transport']?.toString() ?? '')
        .toList();

    // 3) Build hub connection, prefer websockets if available
    final preferWs = transports.any((t) => t.toLowerCase() == 'websockets');
    final options = HttpConnectionOptions(
      accessTokenFactory: () async => token,
      transport: preferWs ? HttpTransportType.webSockets : null,
      skipNegotiation: preferWs,
    );
    final hub = HubConnectionBuilder()
        .withUrl('$base/chatHub', options)
        .withAutomaticReconnect([0, 2000, 5000])
        .build();

    try {
      final dynamic startDyn = hub.start();
      final Future startFuture = startDyn as Future; // cast to sidestep nullable typing from package
      await startFuture.timeout(const Duration(seconds: 40));
      expect(hub.state, HubConnectionState.connected);
    } finally {
      await hub.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
