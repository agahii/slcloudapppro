import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collection_screen.dart';
import 'customer_ledger_screen.dart';
import 'good_recieve_note_screen.dart';
import 'grn_discard_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'my_cash_book_screen.dart';
import 'my_customers_screen.dart';
import 'my_stock_screen.dart';
import 'splash_screen.dart';
import 'my_sales_orders_screen.dart';
import 'my_sales_invoices_screen.dart';
import 'signalr_service.dart';
import 'allowed_ip_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If a JWT token is already stored, start the SignalR connection so it's
  // ready by the time the UI is rendered.
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  // if (token != null) {
  //   try {
  //     await SignalRService.instance.start(token);
  //   } catch (_) {
  //     // Ignore errors during early startup; login flow will retry if needed.
  //   }
  // }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Gracefully close the SignalR connection when the app is disposed.
    SignalRService.instance.stop();
    super.dispose();
  }

  // Your brand colors
  static const Color primaryColor = Color(0xFF0D47A1); // Buttons/AppBar
  static const Color accentColor = Colors.white;

  // Your login gradient colors reused app-wide
  static const List<Color> appGradient = [
    Color(0xFF0F2027),
    Color(0xFF203A43),
    Color(0xFF2C5364),
  ];

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
    final base = ThemeData(
      useMaterial3: true,
      // Transparent so the gradient behind shows through
      scaffoldBackgroundColor: Colors.transparent,
      // Keep your old primary-based styling
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark, // looks great over the dark gradient
        primary: primaryColor,
        onPrimary: accentColor,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      iconTheme: const IconThemeData(color: primaryColor),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.transparent),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIconColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base,
      // Paint the gradient BEHIND all screens
      builder: (context, child) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: appGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home' : (_) => const HomeScreen(),
        '/mySalesOrders': (_) => const MySalesOrdersScreen(),
        '/mySalesInvoices': (_) => const MySalesInvoicesScreen(),
        '/myCashBook': (_) => const MyCashBookScreen(),
        '/customerLedger': (_) => const CustomerLedgerScreen(),
        '/collections': (context) => const CollectionScreen(),
        '/myCustomers': (_) => const MyCustomersScreen(),
        '/allowedIPs': (_) => const AllowedIpScreen(),
        '/my_stock_screen': (_) => const MyStockScreen(),
        '/good_recieve_note_screen': (_) =>  PurchaseFormPage(),
        '/grn_discard_screen': (_) =>  DiscardFormPage(),
      },
    );
  }
}
