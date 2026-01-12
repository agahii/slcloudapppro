import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:slcloudapppro/api_service.dart';

/// Fakes connectivity so platform channels aren’t invoked.
class FakeConnectivity extends ConnectivityPlatform {
  @override
  Future<ConnectivityResult> checkConnectivity() async => ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

void main() {
  // Sets up the binary messenger for plugin MethodChannels.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Use in-memory storage for SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    // Replace the real connectivity provider with the fake one.
    ConnectivityPlatform.instance = FakeConnectivity();
    // Allow real HTTP; Flutter test overrides block it by default.
    HttpOverrides.global = null;
  });

  test('connects to SignalR hub', () async {
    // Provide credentials via --dart-define; we avoid hardcoding secrets.
    final username = const String.fromEnvironment('TEST_USERNAME');
    final password = const String.fromEnvironment('TEST_PASSWORD');
    if (username.isEmpty || password.isEmpty) {
      // Skip if creds are not provided; prevents accidental secret leakage.
      print('SKIP: Provide TEST_USERNAME and TEST_PASSWORD via --dart-define.');
      return;
    }

    final login = await ApiService.attemptLogin(username, password);
    expect(login['success'], true, reason: 'Login failed');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    expect(token.isNotEmpty, true, reason: 'Missing JWT token after login');

    final hub = HubConnectionBuilder()
        .withUrl(
          'https://api.slcloud.3em.tech/chatHub',
          // No explicit transport: client negotiates and will prefer WebSockets when available.
          HttpConnectionOptions(accessTokenFactory: () async => token),
        )
        .withAutomaticReconnect([0, 2000, 5000])
        .build();

    try {
      // Allow more time for initial connect on long polling servers
      await hub.start();
      expect(hub.state, HubConnectionState.connected);
    } finally {
      await hub.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 70)));
}
