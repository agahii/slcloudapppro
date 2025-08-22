import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_core/signalr_core.dart';

import 'package:slcloudapppro/signalr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hardcodedToken = 'REPLACE_WITH_VALID_TOKEN';

  test('SignalR connects with hardcoded token', () async {
    SharedPreferences.setMockInitialValues({'token': hardcodedToken});

    await SignalRService.instance.start();

    expect(SignalRService.instance.connection?.state, HubConnectionState.connected);

    await SignalRService.instance.stop();
  }, skip: hardcodedToken == 'REPLACE_WITH_VALID_TOKEN');
}
