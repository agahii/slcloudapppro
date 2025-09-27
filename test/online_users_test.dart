import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slcloudapppro/api_service.dart';
import 'package:slcloudapppro/signalr_service.dart';
import 'package:slcloudapppro/chat/chat_service.dart';
import 'package:http/http.dart' as http;

class FakeConnectivity extends ConnectivityPlatform {
  @override
  Future<ConnectivityResult> checkConnectivity() async => ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ConnectivityPlatform.instance = FakeConnectivity();
    HttpOverrides.global = null; // default allow real HTTP (will override for localhost below)
  });

  test('gets online users list', () async {
    final username = const String.fromEnvironment('TEST_USERNAME');
    final password = const String.fromEnvironment('TEST_PASSWORD');
    if (username.isEmpty || password.isEmpty) {
      fail('Provide TEST_USERNAME and TEST_PASSWORD via --dart-define');
    }

    // 1) Login to get token (supports optional TEST_BASE_URL override)
    final base = const String.fromEnvironment('TEST_BASE_URL');
    String token;
    if (base.isNotEmpty) {
      final uri = Uri.parse('$base/api/Account/loginMobile');
      if (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1') {
        // Trust local dev certs for this test run
        HttpOverrides.global = _TrustLocalhost();
      }
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'mobile': username, 'password': password}))
          .timeout(const Duration(seconds: 15));
      expect(resp.statusCode, 200, reason: 'Login HTTP ${resp.statusCode}: ${resp.body}');
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      expect(j['responseCode'], 1000, reason: 'Login failed: ${resp.body}');
      token = (j['data'] as Map<String, dynamic>)['token'] as String;
      expect(token.isNotEmpty, true, reason: 'Missing token');
      // Store for any code paths that read SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
    } else {
      final login = await ApiService.attemptLogin(username, password);
      expect(login['success'], true, reason: 'Login failed');
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token') ?? '';
      expect(token.isNotEmpty, true, reason: 'Missing token after login');
    }

    // 2) Start SignalR connection
    await SignalRService.instance.start(token);
    expect(SignalRService.instance.isConnected, true, reason: 'Hub not connected');

    // 3) Register chat handlers and request online users
    ChatService.instance.ensureRegistered();

    final snapshotFuture = ChatService.instance.usersSnapshotStream.first.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Timed out waiting for users snapshot'),
    );

    await ChatService.instance.requestUsersSnapshot();

    final users = await snapshotFuture;

    // Print what we got for quick visibility
    // ignore: avoid_print
    print('Online users count: ${users.length}');
    for (final u in users.take(10)) {
      // ignore: avoid_print
      print(' - ${u.id} | ${u.displayName} | online=${u.isOnline}');
    }

    expect(users, isA<List>(), reason: 'Response should be a list');
  }, timeout: const Timeout(Duration(seconds: 60)));
}

class _TrustLocalhost extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) =>
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    return client;
  }
}
