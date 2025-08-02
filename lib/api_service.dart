import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://api.slcloudpos.3em.tech';

  static Future<bool> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/account/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      // You can extract token or user info here if returned
      print('Login successful: ${response.body}');
      return true;
    } else {
      print('Login failed: ${response.statusCode} ${response.body}');
      return false;
    }
  }
}
