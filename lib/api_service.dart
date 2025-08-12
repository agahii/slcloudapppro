import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/Product.dart';
import 'package:slcloudapppro/Model/customer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'Model/SalesOrderItem.dart';
import 'my_sales_orders_screen.dart';
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;
  ApiException(this.statusCode, this.message, {this.data});
  @override
  String toString() => 'ApiException($statusCode): $message';
}
class ApiService {
  static const String baseUrl = 'http://api.slcloud.3em.tech';
  //static const String baseUrl = 'http://localhost:7271';
  static const String imageBaseUrl = '$baseUrl/files/';
  static Future<bool> hasInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }





  static String _utf8Body(http.Response r) =>
      utf8.decode(r.bodyBytes, allowMalformed: true);

  static String extractServerMessage(http.Response r) {
    final text = _utf8Body(r);
    try {
      final j = json.decode(text);
      if (j is Map<String, dynamic>) {
        // Postman screenshot shows: { "responseCode": 2000, "message": "..." }
        if (j['message'] is String && (j['message'] as String).isNotEmpty) {
          return j['message'];
        }
        // fallbacks some APIs use
        if (j['Message'] is String) return j['Message'];
        if (j['error'] is String) return j['error'];
        if (j['detail'] is String) return j['detail'];
      }
    } catch (_) {
      // not JSON; return raw text if any
    }
    return text.isNotEmpty
        ? text
        : (r.reasonPhrase ?? 'Request failed (${r.statusCode}).');
  }








  static Future<Map<String, dynamic>> attemptLogin(String email, String password) async {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/Account/loginMobile');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mobile': email, 'password': password}),
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
        await prefs.setString('salesPurchaseOrderManagerID', data['salesPurchaseOrderManagerID']);
        await prefs.setString('invoiceManagerID', data['invoiceManagerID']);
        await prefs.setString('walkInCustomerID', data['walkInCustomerID']);
        await prefs.setString('cashBookID', data['cashBookID']);
        await prefs.setString('stockLocationID', data['stockLocationID']);

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




  static Future<http.Response> finalizeInvoice(Map<String, dynamic> payload) async {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/InvoiceMaster/AddPos');
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
    final bodyText = _utf8Body(response);
    dynamic jsonBody;
    try { jsonBody = json.decode(bodyText); } catch (_) { /* may be plain text/HTML */ }

    return response;
  }








  static Future<List<Product>> fetchProductsFromOrderManager({
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




  static Future<List<Product>> fetchProductsFromInvoiceManager({
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
    final url = Uri.parse('$baseUrl/api/InvoiceMaster/GetSKUPOS');
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





  static Future<List<SalesOrder>> fetchMySalesOrders({
    required int page,
    required int pageSize,
    required String searchKey,
    required String status, // "ALL" | "OPEN" | "CLOSED"
  }) async {

    if (!await hasInternetConnection()) {
      throw Exception('No internet connection.');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Token not found. Please login again.');
    }



    // If your backend expects POST with body:
    final uri = Uri.parse("$baseUrl/api/PurchaseSalesOrderMaster/GetEmployeeOrder"); // <-- TODO: confirm endpoint

    final body = {

      "pageNumber": page,
      "pageSize": pageSize,
      "searchKey": searchKey,
      "status": status, // tell backend how you encode filters; otherwise ignore
    };

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);

      // Adjust to your API shape:
      final List list = (decoded['data'] ??
          decoded['orders'] ??
          decoded['purchaseSalesOrderVM'] ??
          decoded) as List;

      return list
          .map((e) => SalesOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception("Server ${resp.statusCode}: ${resp.body}");
    }
  }










}
