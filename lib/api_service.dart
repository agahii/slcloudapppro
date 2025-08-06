import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/Product.dart';
import 'package:slcloudapppro/Model/customer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  static const String baseUrl = 'http://api.slcloud.3em.tech';
  static const String imageBaseUrl = '$baseUrl/files/';



  static Future<bool> hasInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }



  static Future<Map<String, dynamic>> attemptLogin(String email, String password) async {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/account/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final int responseCode = json['responseCode'];

      if (responseCode == 1000) {
        final data = json['data'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('firstName', data['firstName']);
        await prefs.setString('lastName', data['lastName']);
        await prefs.setString('tokenExpire', data['tokenExpire']);

        return {'success': true};
      } else {
        return {'success': false, 'message': json['message']};
      }
    } else {
      return {'success': false, 'message': 'Server error: ${response.statusCode}'};
    }
  }










  static Future<List<Customer>> fetchCustomers(String managerID, String searchKey) async {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/PurchaseSalesOrderMaster/GetCustomer');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Token not found. Please login again.');
    }
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"managerID": managerID, "searchKey": searchKey}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data['data']['customerDropDownVM'] as List;
      return list.map((item) => Customer.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load customers');
    }
  }



  static Future<http.Response> finalizeSalesOrder(Map<String, dynamic> payload) async {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/PurchaseSalesOrderMaster/Add');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Token not found. Please login again.');
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response = await http.post(url, headers: headers, body: jsonEncode(payload));
    return response;
  }









  static Future<List<Product>> fetchProducts({
    required String managerID,
    int page = 1,
    int pageSize = 20,
    String searchKey = "",
  }) async {


    if (!await hasInternetConnection()) {
      throw Exception('No internet connection.');
    }


    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Token not found. Please login again.');
    }
    final url = Uri.parse('$baseUrl/api/PurchaseSalesOrderMaster/GetSKUPOS');
    final payload = {
      "managerID": managerID,
      "searchKey": searchKey,
      "barCode": "",
      "categoryID": "",
      "pageNumber": page,
      "pageSize": pageSize,
      "StockLocationID": ""
    };


    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List skuList = data['data']['skuVMPOS'];
      return skuList.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }



}
