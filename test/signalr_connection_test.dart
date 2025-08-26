import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:slcloudapppro/api_service.dart';
// Mock connectivity_plus
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';

class FakeConnectivity extends ConnectivityPlatform {
  @override
  Future<ConnectivityResult> checkConnectivity() async => ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}



void main() {
  // MUST be first: sets up binary messenger for MethodChannels
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // SharedPreferences in-memory store
    SharedPreferences.setMockInitialValues({});
    // Make connectivity_plus return 'wifi' instead of hitting platform
    ConnectivityPlatform.instance = FakeConnectivity();
  });

  test('connects to SignalR hub', () async {
    // ⚠️ Avoid hardcoding creds in repo. Prefer --dart-define (see notes below)
    final loginResult = await ApiService.attemptLogin('923212255434', 'Ba@leno99');
    expect(loginResult['success'], true, reason: 'Login failed');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    expect(token.isNotEmpty, true, reason: 'Missing JWT token after login');

    final hub = HubConnectionBuilder()
        .withUrl(
      'https://api.slcloud.3em.tech/chatHub',
      HttpConnectionOptions(
        transport: HttpTransportType.webSockets,           // optional but helps
        accessTokenFactory: () async => token,            // send JWT
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
