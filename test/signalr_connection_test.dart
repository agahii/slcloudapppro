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
    // Use in‑memory storage for SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    // Replace the real connectivity provider with the fake one.
    ConnectivityPlatform.instance = FakeConnectivity();
  });

  test('connects to SignalR hub', () async {
    // Credentials can be supplied via --dart-define to avoid hardcoding.
    final login = await ApiService.attemptLogin(
      const String.fromEnvironment('TEST_USERNAME', defaultValue: '923212255434'),
      const String.fromEnvironment('TEST_PASSWORD', defaultValue: 'Ba@leno99'),
    );
    expect(login['success'], true, reason: 'Login failed');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    expect(token.isNotEmpty, true, reason: 'Missing JWT token after login');

    final hub = HubConnectionBuilder()
        .withUrl(
      'https://api.slcloud.3em.tech/chatHub',
      HttpConnectionOptions(
        transport: HttpTransportType.webSockets,
        accessTokenFactory: () async => token,
      ),
    )
        .withAutomaticReconnect([0, 2000, 5000])
        .build();

    try {
      await hub.start();
      expect(hub.state, HubConnectionState.connected);
    } finally {
      await hub.stop();
    }
  });
}
