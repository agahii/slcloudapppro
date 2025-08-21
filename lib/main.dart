import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collection_screen.dart';
import 'customer_ledger_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'my_cash_book_screen.dart';
import 'my_customers_screen.dart';
import 'my_sales_invoices_screen.dart';
import 'my_sales_orders_screen.dart';
import 'splash_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
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
      theme: AppTheme.dark(),
      // Paint the gradient BEHIND all screens
      builder: (context, child) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/mySalesOrders': (_) => const MySalesOrdersScreen(),
        '/mySalesInvoices': (_) => const MySalesInvoicesScreen(),
        '/myCashBook': (_) => const MyCashBookScreen(),
        '/customerLedger': (_) => const CustomerLedgerScreen(),
        '/collections': (context) => const CollectionScreen(),
        '/myCustomers': (_) => const MyCustomersScreen(),
      },
    );
  }
}
