import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/Product.dart';
import 'package:slcloudapppro/Model/customer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:slcloudapppro/Model/MySalesInvoice.dart';
import 'package:slcloudapppro/Model/cash_book.dart';
import 'Model/PagedCustomers.dart';
import 'Model/SalesOrderItem.dart';
import 'Model/chart_account.dart';
import 'Model/customer_lite.dart';
import 'Model/ledger_entry.dart';
import 'collection_screen.dart';

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

  static Future<http.Response> _post(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    try {
      return await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(408, 'Request timed out');
    } catch (e) {
      throw ApiException(-1, e.toString());
    }
  }

  static Future<http.Response> _put(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    try {
      return await http
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(408, 'Request timed out');
    } catch (e) {
      throw ApiException(-1, e.toString());
    }
  }
  static Future<Map<String, dynamic>> attemptLogin(
      String email, String password) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/Account/loginMobile');

    final response = await _post(
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
        await prefs.setString('employeeID', data['employeeID']);
        await prefs.setString('provisionalReceiptManagerID', data['provisionalReceiptManagerID']);
        if (data['provisionalReceiptDebitAccountsVM'] != null) {
          await prefs.setString('provisionalReceiptDebitAccountsVM', jsonEncode(data['provisionalReceiptDebitAccountsVM']));
        }
        if (data['banks'] != null) {
          await prefs.setString('banks', jsonEncode(data['banks']));
        }
        return {'success': true};
      } else {
        return {'success': false, 'message': json['message']};
      }
    } else {
      throw ApiException(
          response.statusCode, extractServerMessage(response));
    }
  }
  static Future<List<Customer>> fetchPOCustomers(String managerID, String searchKey) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final url =
        Uri.parse('$baseUrl/api/PurchaseSalesOrderMaster/GetCustomer');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }
    final response = await _post(
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
      throw ApiException(
          response.statusCode, extractServerMessage(response));
    }
  }



  static Future<List<Customer>> fetchInvCustomers(String managerID, String searchKey) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/InvoiceMaster/GetCustomer');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }
    final response = await _post(
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
      throw ApiException(
          response.statusCode, extractServerMessage(response));
    }
  }





  static Future<http.Response> finalizeSalesOrder(Map<String, dynamic> payload) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/PurchaseSalesOrderMaster/Add');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response =
        await _post(url, headers: headers, body: jsonEncode(payload));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      throw ApiException(response.statusCode, extractServerMessage(response));
    }
  }





  static Future<http.Response> addProvisionalReceipt(
      Map<String, dynamic> payload) async {



    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final url = Uri.parse('$baseUrl/api/VoucherMaster/AddProvisionalReceipt');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response =
        await _post(url, headers: headers, body: jsonEncode(payload));

    final bodyText = _utf8Body(response);
    dynamic jsonBody;
    try {
      jsonBody = json.decode(bodyText);
    } catch (_) {
      // may be plain text/HTML
    }
    if (jsonBody != null) {
      print('addProvisionalReceipt response: $jsonBody');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      throw ApiException(response.statusCode, extractServerMessage(response));
    }
  }




  static Future<http.Response> finalizeInvoice(Map<String, dynamic> payload) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/InvoiceMaster/AddPos');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response =
        await _post(url, headers: headers, body: jsonEncode(payload));
    final bodyText = _utf8Body(response);
    dynamic jsonBody;
    try {
      jsonBody = json.decode(bodyText);
    } catch (_) {
      // may be plain text/HTML
    }
    if (jsonBody != null) {
      print('finalizeInvoice response: $jsonBody');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      throw ApiException(response.statusCode, extractServerMessage(response));
    }
  }
  static Future<List<Product>> fetchProductsFromOrderManager({
    required String managerID,
    required String stockLocationID,

    int page = 1,
    int pageSize = 20,
    String searchKey = "",
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }
    final url = Uri.parse('$baseUrl/api/PurchaseSalesOrderMaster/GetSKUPOS');
    final payload = {

      "managerID": managerID,
      "searchKey": searchKey,
      "barCode": "",
      "categoryID": "",
      "pageNumber": page,
      "pageSize": pageSize,
      "stockLocationID": stockLocationID
    };


    final response = await _post(
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
      throw ApiException(
          response.statusCode, extractServerMessage(response));
    }
  }




  static Future<List<Product>> fetchProductsFromInvoiceManager({
    required String managerID,
    required String stockLocationID,
    int page = 1,
    int pageSize = 20,
    String searchKey = "",
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }
    final url = Uri.parse('$baseUrl/api/InvoiceMaster/GetSKUPOS');
    final payload = {
      "managerID": managerID,
      "searchKey": searchKey,
      "barCode": "",
      "categoryID": "",
      "pageNumber": page,
      "pageSize": pageSize,
      "stockLocationID": stockLocationID
    };


    final response = await _post(
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
      throw ApiException(
          response.statusCode, extractServerMessage(response));
    }
  }










  static Future<List<SalesInvoice>> fetchMySalesInvoices({
    required String managerID,
    required String searchKey,
    required int pageNumber,
    required int pageSize,
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }

    final payload = {
      "managerID": managerID,
      "searchKey": searchKey,
      "pageNumber": pageNumber,
      "pageSize": pageSize,
    };

    final res = await _post(
      Uri.parse("$baseUrl/api/InvoiceMaster/GetEmployeeInvoice"),
      headers: {
        "Content-Type": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final List data = json['data'] ?? [];
      return data.map((e) => SalesInvoice.fromJson(e)).toList();
    } else {
      throw ApiException(res.statusCode, extractServerMessage(res));
    }
  }



  static Future<List<SalesOrder>> fetchMySalesOrders({
    required String managerID,
    required int page,
    required int pageSize,
    required String searchKey,
    required String status, // "ALL" | "OPEN" | "CLOSED"
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }

    // If your backend expects POST with body:
    final uri = Uri.parse(
        "$baseUrl/api/PurchaseSalesOrderMaster/GetEmployeeOrder"); // <-- TODO: confirm endpoint

    final body = {
      "managerID": managerID,
      "pageNumber": page,
      "pageSize": pageSize,
      "searchKey": searchKey,
      "status": status, // tell backend how you encode filters; otherwise ignore
    };

    final resp = await _post(
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
      throw ApiException(resp.statusCode, extractServerMessage(resp));
    }
  }




  static Future<List<CashBookEntry>> fetchMyCashBook({
    required String accountID,
    required int page,
    required int pageSize,
    String searchKey = "",
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }

    // Same pattern as fetchMySalesOrders
    final uri = Uri.parse("$baseUrl/api/Ledger/GetPOSLedger"); // <-- confirm endpoint

    final body = {
      "accountID": accountID,
      "pageNumber": page,
      "pageSize": pageSize,
      "searchKey": searchKey,
    };

    final resp = await _post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);

      // Adjust to your API shape (prefers 'data', but falls back if backend changes)
      final List list = (decoded['data'] ??
          decoded['ledger'] ??
          decoded['entries'] ??
          decoded) as List;

      return list
          .map((e) => CashBookEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiException(resp.statusCode, extractServerMessage(resp));
    }
  }



  String _fmtApiDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }





  static Future<List<LedgerEntry>> fetchCustomerLedger({

    required String customerID,
    required DateTime fromDate,
    required DateTime toDate,
    required int page,
    required int pageSize,
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }

    // TODO: adjust endpoint path if your backend differs
    final uri = Uri.parse('$baseUrl/api/Ledger/GetPOSCustomerLedger');

    final body = {
      "accountID": customerID,
      "pageNumber": page,
      "pageSize": pageSize,
      "searchKey": "",
    };

    final resp = await _post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, extractServerMessage(resp));
    }

    final decoded = jsonDecode(resp.body);
    // Adjust to your API shape. Common shapes:
    // 1) { data: { items: [...] } }
    // 2) { data: [...] }
    // 3) [ ... ]
    final dynamic container = decoded['data'] ?? decoded;
    final List list =
    (container is Map && container['items'] is List) ? container['items'] :
    (container is List) ? container :
    (container is Map && container['ledger'] is List) ? container['ledger'] :
    <dynamic>[];

    return list.map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
  }



  static Future<List<ChartAccount>> getProvisionalReceiptCreditAccounts({
    required String managerID,
    String searchKey = '',
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final prefs = await SharedPreferences.getInstance();

    final token =
        prefs.getString('token') ?? prefs.getString('accessToken') ?? '';

    final uri = Uri.parse(
        '$baseUrl/api/VoucherMaster/GetProvisionalReceiptCreditAccounts');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'managerID': managerID,
      'type': "d", // always "d"
      'searchKey': searchKey,
    });

    final res = await _post(uri, headers: headers, body: body);

    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, extractServerMessage(res));
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final listJson =
        (decoded['data']?['chartOfAccountsDropDownVM'] as List?) ?? [];





    return listJson
        .whereType<Map<String, dynamic>>()
        .map((e) => ChartAccount.fromJson(e))
        .toList();
  }




  static Future<List<DiscountPolicy>> getDiscountPolicyPOS() async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final url = Uri.parse('$baseUrl/api/DiscountPolicy/GetDiscountPolicyPOS');
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('token') ?? prefs.getString('accessToken') ?? '';

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final res = await _post(url, headers: headers, body: jsonEncode({}));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final list = (json['data'] ?? []) as List;
      return list
          .map((e) => DiscountPolicy.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      throw ApiException(res.statusCode, extractServerMessage(res));
    }
  }

  static Future<PagedCustomers> getCustomersPaged({
    required String managerIDInvoice,
    required String managerIDPO,
    String searchKey = "",
    required int pageNumber, // 1-based page number expected by your sample payload
    int pageSize = 20,
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final uri = Uri.parse("$baseUrl/api/Customer/GetCustomer");
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('token') ?? prefs.getString('accessToken') ?? '';
    final payload = {
      "ManagerIDInvoice": managerIDInvoice,
      "ManagerIDPO": managerIDPO,
      "searchKey": searchKey,
      "pageNumber": pageNumber,
      "pageSize": pageSize,
    };

    final resp = await _post(
      uri,
      headers: {
        "Content-Type": "application/json",
        // Add auth header if your project uses it:
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, extractServerMessage(resp));
    }

    final Map<String, dynamic> json = jsonDecode(resp.body);

    final data = (json['data'] ?? {}) as Map<String, dynamic>;
    final list = (data['customerDropDownVM'] ?? []) as List<dynamic>;

    final items = list
        .map((e) => CustomerLite.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // pull paging/meta from response if present (with sensible fallbacks)
    final int totalRecords = (json['totalRecords'] ?? 0) as int;
    final int pageSizeResp = (json['pageSize'] ?? pageSize) as int;
    // NOTE: API sample shows `pageIndex` — might be 0- or 1-based. We’ll trust as-is.
    final int pageIndex = (json['pageIndex'] ?? pageNumber) as int;
    final int totalInResp = (json['totalRecordsInResponse'] ?? items.length) as int;

    return PagedCustomers(
      items: items,
      pageIndex: pageIndex,
      pageSize: pageSizeResp,
      totalRecords: totalRecords,
      totalRecordsInResponse: totalInResp,
    );
  }


  static Future<void> addCustomerGeoTag({
    required String id,
    required double latitude,
    required double longitude,
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final uri = Uri.parse("$baseUrl/api/Customer/AddCustomerGeoTag");
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('token') ?? prefs.getString('accessToken') ?? '';
    final payload = {
      "id": id,
      "latitude": latitude,
      "longitude": longitude,
    };

    final resp = await _put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, extractServerMessage(resp));
    }
  }


}
