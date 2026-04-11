import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NodeApiService {
  //final String baseUrl = kIsWeb ? "http://localhost:5000" : "http://10.0.2.2:5000";
  final String baseUrl = "http://192.168.1.37:5000";
  final SupabaseClient _supabase;

  NodeApiService(this._supabase);

  String _formatPhone(String phone) {
    if (phone.isEmpty) return "";
    final clean = phone.replaceAll(RegExp(r'[^\d]'), "");
    if (clean.length >= 10) {
      return "+91${clean.substring(clean.length - 10)}";
    }
    return "+91$clean";
  }

  Future<Map<String, String>> _getHeaders({String? overridePhone}) async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;
    final headers = {
      "Content-Type": "application/json",
    };

    if (session?.accessToken != null) {
      headers["Authorization"] = "Bearer ${session!.accessToken}";
    }

    final phone = overridePhone ?? user?.phone;
    if (phone != null && phone.isNotEmpty) {
      headers["x-user-phone"] = _formatPhone(phone);
    }

    return headers;
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    String method = "GET",
    Map<String, dynamic>? body,
    String? overridePhone,
  }) async {
    final url = Uri.parse("$baseUrl${endpoint.startsWith('/api') ? endpoint : '/api${endpoint.startsWith('/') ? endpoint : '/$endpoint'}'}");
    final headers = await _getHeaders(overridePhone: overridePhone);

    print('🚀 NodeAPI Request: $method $url');
    print('📋 Headers: $headers');
    if (body != null) {
      final jsonBody = jsonEncode(body);
      print('📦 Body: $jsonBody');
      if (jsonBody.contains('"location":')) {
        print('🚨 WARNING: Body contains "location" key! This might cause Supabase 500 error.');
      }
    }

    http.Response response;
    try {
      const timeoutDuration = Duration(seconds: 10);
      if (method == "POST") {
        response = await http.post(url, headers: headers, body: jsonEncode(body)).timeout(timeoutDuration);
      } else if (method == "PUT") {
        response = await http.put(url, headers: headers, body: jsonEncode(body)).timeout(timeoutDuration);
      } else if (method == "PATCH") {
        response = await http.patch(url, headers: headers, body: jsonEncode(body)).timeout(timeoutDuration);
      } else if (method == "DELETE") {
        response = await http.delete(url, headers: headers).timeout(timeoutDuration);
      } else {
        response = await http.get(url, headers: headers).timeout(timeoutDuration);
      }
    } catch (e) {
      String errorMessage = 'Connection failed. Please check if your computer (${url.host}) is reachable from your mobile device.';
      if (e.toString().contains('SocketException')) {
        errorMessage = 'Network unreachable. Check if you are on the same Wi-Fi and the firewall allows port ${url.port}.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timed out. Host ${url.host}:${url.port} is not responding.';
      }
      print('❌ NodeAPI Error: $errorMessage ($e)');
      throw Exception(errorMessage);
    }

    print('✅ NodeAPI Response: ${response.statusCode}');
    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(responseData["message"] ?? "HTTP ${response.statusCode}: ${response.reasonPhrase}");
    }

    return responseData;
  }

  // --- Auth ---
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    return _request("/auth/send-otp", method: "POST", body: {"phone": _formatPhone(phone)});
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    return _request("/auth/verify-otp", method: "POST", body: {
      "phone": _formatPhone(phone),
      "otp": otp,
    });
  }

  Future<Map<String, dynamic>> getUser(String phone) async {
    return _request("/auth/status", overridePhone: phone);
  }

  Future<String?> uploadAvatar(String filePath, String phone) async {
    final url = Uri.parse("$baseUrl/upload/avatar-image");
    final headers = await _getHeaders(overridePhone: phone);
    
    // Convert to multipart specific
    headers.remove("Content-Type"); 

    var request = http.MultipartRequest("POST", url);
    request.headers.addAll({...headers}); // Convert FutureMap to Map or directly add all
    
    for (final entry in headers.entries) {
        request.headers[entry.key] = entry.value;
    }
    
    request.fields['phone'] = _formatPhone(phone);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(responseData["message"] ?? "Failed to upload avatar");
    }

    return responseData["data"]?["url"];
  }

  // --- Marketplace ---
  Future<dynamic> getHomeBanners() async {
    return _request("/banners");
  }

  Future<dynamic> getCategories() async {
    return _request("/categories");
  }

  Future<dynamic> getHealthFilters() async {
    return _request("/categories/health-filters");
  }

  Future<dynamic> getMoodCategories() async {
    return _request("/mood-categories");
  }

  Future<dynamic> getVendors({double? lat, double? lng}) async {
    final queryParams = <String>[];
    if (lat != null) queryParams.add('lat=$lat');
    if (lng != null) queryParams.add('lng=$lng');
    final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return _request("/vendors$query");
  }

  Future<dynamic> getVendor(String vendorId) async {
    return _request("/vendors/$vendorId");
  }

  Future<dynamic> getVendorProducts(String vendorId) async {
    return _request("/vendors/$vendorId/products");
  }

  Future<dynamic> getProductsByIds(List<String> productIds) async {
    // Polyfill for batch fetching products
    try {
      final List<dynamic> products = [];
      for (final id in productIds) {
        try {
          final res = await _request("/products/$id");
          if (res != null) products.add(res["data"] ?? res);
        } catch (_) {}
      }
      return {"success": true, "data": products};
    } catch (e) {
      return {"success": false, "data": []};
    }
  }

  // --- Users & Addresses ---
  Future<dynamic> getUserAddresses(String phone) async {
    return _request("/users/addresses", overridePhone: phone);
  }

  Future<dynamic> createAddress(String phone, Map<String, dynamic> addressData) async {
    return _request("/users/addresses", method: "POST", body: addressData, overridePhone: phone);
  }

  Future<dynamic> updateAddress(String phone, String addressId, Map<String, dynamic> addressData) async {
    return _request("/users/addresses/$addressId", method: "PUT", body: addressData, overridePhone: phone);
  }

  Future<dynamic> deleteAddress(String phone, String addressId) async {
    return _request("/users/addresses/$addressId", method: "DELETE", overridePhone: phone);
  }

  Future<dynamic> setDefaultAddress(String phone, String addressId) async {
    return _request("/users/addresses/$addressId/default", method: "PATCH", overridePhone: phone);
  }

  // --- Cart ---
  Future<dynamic> getUserCart(String phone) async {
    return _request("/cart", overridePhone: phone);
  }

  Future<dynamic> saveUserCart(String phone, List<Map<String, dynamic>> items) async {
    return _request("/cart/sync", method: "POST", body: {"items": items}, overridePhone: phone);
  }

  Future<dynamic> clearUserCart(String phone) async {
    return _request("/cart", method: "DELETE", overridePhone: phone);
  }

  Future<dynamic> addToCart(String phone, Map<String, dynamic> item) async {
    return _request("/cart", method: "POST", body: item, overridePhone: phone);
  }

  Future<dynamic> updateCartItem(String phone, String id, Map<String, dynamic> data) async {
    return _request("/cart/$id", method: "PUT", body: data, overridePhone: phone);
  }

  Future<dynamic> removeCartItem(String phone, String id) async {
    return _request("/cart/$id", method: "DELETE", overridePhone: phone);
  }

  // --- Delivery & Serviceability ---
  Future<dynamic> getDeliveryServiceability(Map<String, dynamic> pickup, Map<String, dynamic> drop) async {
    return _request("/delivery/serviceability", method: "POST", body: {
      "pickup_details": pickup,
      "drop_details": drop,
    });
  }

  // --- Orders & Tracking ---
  Future<dynamic> createOrder({required Map<String, dynamic> orderData, String? overridePhone}) async {
    return _request("/orders", method: "POST", body: orderData, overridePhone: overridePhone);
  }

  Future<dynamic> getOrderTracking(String orderId) async {
    return _request("/orders/$orderId/track");
  }

  Future<dynamic> getUserOrders({int page = 1, int limit = 20, String? overridePhone}) async {
    return _request("/orders?page=$page&limit=$limit", overridePhone: overridePhone);
  }

  Future<dynamic> triggerMockPayment(String orderNumber, {bool mockShadowfax = true, String? overridePhone}) async {
    return _request("/payments/mock-success", method: "POST", body: {
      "orderId": orderNumber,
      "mockShadowfax": mockShadowfax
    }, overridePhone: overridePhone);
  }

  // --- Partner/Vendor Methods ---
  Future<Map<String, dynamic>> checkVendorStatus(String phone) async {
    return _request("/vendor-auth/check-status", method: "POST", body: {"phone": phone});
  }

  Future<Map<String, dynamic>> getVendorProfile(String vendorId) async {
    return _request("/vendor-auth/$vendorId");
  }

  Future<Map<String, dynamic>> vendorLogin(String email, String password) async {
    return _request("/vendor-auth/login", method: "POST", body: {
      "email": email,
      "password": password,
    });
  }

  Future<Map<String, dynamic>> updateVendorStatus(String vendorId, bool isOpen) async {
    return _request("/vendor-auth/$vendorId/status", method: "POST", body: {"isOpen": isOpen});
  }

  Future<Map<String, dynamic>> getPartnerVendorOrders(String vendorId, {String? status}) async {
    String endpoint = "/vendor-auth/$vendorId/orders";
    if (status != null) {
      endpoint += "?status=$status";
    }
    return _request(endpoint);
  }

  Future<Map<String, dynamic>> getVendorDashboardStats(String vendorId) async {
    return _request("/vendor-auth/$vendorId/dashboard-stats");
  }

  Future<Map<String, dynamic>> updateVendorOrderStatus(String vendorId, String orderId, String status) async {
    return _request("/vendor-auth/$vendorId/orders/$orderId/status", method: "PATCH", body: {"status": status});
  }

  Future<Map<String, dynamic>> getPartnerVendorMenu(String vendorId) async {
    return _request("/vendor-auth/$vendorId/products");
  }

  Future<Map<String, dynamic>> addVendorProduct(String vendorId, Map<String, dynamic> data) async {
    return _request("/vendor-auth/$vendorId/products", method: "POST", body: data);
  }

  Future<Map<String, dynamic>> updateVendorProduct(String vendorId, String productId, Map<String, dynamic> data) async {
    return _request("/vendor-auth/$vendorId/products/$productId", method: "PUT", body: data);
  }

  Future<Map<String, dynamic>> deleteVendorProduct(String vendorId, String productId) async {
    return _request("/vendor-auth/$vendorId/products/$productId", method: "DELETE");
  }

  Future<Map<String, dynamic>> updateVendorProfile(String vendorId, Map<String, dynamic> data) async {
    return _request("/vendor-auth/$vendorId/profile", method: "PUT", body: data);
  }

  Future<Map<String, dynamic>> getVendorGSTReport(String vendorId, String from, String to) async {
    return _request("/vendor-auth/$vendorId/gst-report?from=$from&to=$to");
  }

  Future<Map<String, dynamic>> createShadowfaxOrder(String orderId) async {
    return _request("/shadowfax/create-order", method: "POST", body: {"orderId": orderId});
  }
}

final nodeApiServiceProvider = Provider<NodeApiService>((ref) {
  final supabase = Supabase.instance.client;
  return NodeApiService(supabase);
});
