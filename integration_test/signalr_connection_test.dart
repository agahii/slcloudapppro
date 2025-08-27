import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:slcloudapppro/api_service.dart';

/// A fake implementation of [ConnectivityPlatform] so the test does not
/// depend on host platform channels.
class FakeConnectivity extends ConnectivityPlatform {
  @override
  Future<ConnectivityResult> checkConnectivity() async => ConnectivityResult.wifi;

  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

void main() {
  // Ensure all integration test bindings are set up.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Use in-memory storage for SharedPreferences.
    SharedPreferences.setMockInitialValues({});

    // Force connectivity_plus to think we have WiFi.
    ConnectivityPlatform.instance = FakeConnectivity();
  });

  testWidgets('connects to SignalR hub online', (tester) async {
    // Attempt to log in to retrieve the JWT token used by the SignalR hub.
    final login = await ApiService.attemptLogin('923212255434', 'Ba@leno99');
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

