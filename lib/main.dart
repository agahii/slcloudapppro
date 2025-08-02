import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart'; // Replace with your actual home screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Define your global color scheme here
  static const Color primaryColor = Color(0xFF0D47A1); // Login screen blue
  static const Color accentColor = Colors.white;       // Text/Icon/Foreground

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

      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: accentColor,
        ),

        iconTheme: const IconThemeData(color: primaryColor),

        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),

        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: accentColor,
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
        ),
      ),

      home: FutureBuilder<bool>(
        future: isTokenValid(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return snapshot.data! ? const HomeScreen() : const LoginScreen();
        },
      ),

      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
