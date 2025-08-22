
 import 'package:flutter_test/flutter_test.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 import 'package:signalr_core/signalr_core.dart';
 import 'package:slcloudapppro/api_service.dart';
 
 void main() {
   test('connects to SignalR hub', () async {
     // Prepare in-memory storage for SharedPreferences.
     SharedPreferences.setMockInitialValues({});
 
     // Attempt login using provided credentials.
     final loginResult =
         await ApiService.attemptLogin('923212255434', 'Ba@leno99');
     expect(loginResult['success'], true);
 
     final prefs = await SharedPreferences.getInstance();
     final token = prefs.getString('token') ?? '';
 
     final hubConnection = HubConnectionBuilder()
         .withUrl(
           '${ApiService.baseUrl}/notificationsHub',
           HttpConnectionOptions(
             accessTokenFactory: () async => token,
           ),
         )
         .build();
 
     await hubConnection.start();
     expect(hubConnection.state, HubConnectionState.connected);
 
     await hubConnection.stop();
   });
 }
