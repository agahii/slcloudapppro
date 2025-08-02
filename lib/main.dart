import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart'; // Replace with your actual home screen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final expireStr = prefs.getString('tokenExpire');

    if (token == null || expireStr == null) return false;

    try {
      final expiry = DateTime.parse(expireStr);
      return DateTime.now().isBefore(expiry);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: isTokenValid(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return snapshot.data! ? HomeScreen() : LoginScreen();
        },
      ),
      routes: {

        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },

    );
  }
}
