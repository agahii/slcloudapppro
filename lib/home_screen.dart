import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String firstName = '';
  String lastName = '';

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      firstName = prefs.getString('firstName') ?? '';
      lastName = prefs.getString('lastName') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // get global theme

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        // No need to set color here — it uses AppBarTheme from global theme
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: theme.primaryColor, // use global primary color
              ),
              accountName: Text('$firstName $lastName'),
              accountEmail: const Text(''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  firstName.isNotEmpty ? firstName[0] : '',
                  style: TextStyle(
                    fontSize: 40,
                    color: theme.primaryColor, // consistent with theme
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: theme.iconTheme.color),
              title: const Text('Logout'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          'Welcome, $firstName $lastName!',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
        ),
      ),
    );
  }
}
