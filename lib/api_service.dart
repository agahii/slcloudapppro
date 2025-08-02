import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      final Map<String, dynamic> json = jsonDecode(response.body);
      final data = json['data'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('firstName', data['firstName']);
      await prefs.setString('lastName', data['lastName']);
      await prefs.setString('tokenExpire', data['tokenExpire']);

      return true;
    } else {
      return false;
    }
  }
}
