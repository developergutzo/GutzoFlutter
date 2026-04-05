import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NodeApiService {
  final String baseUrl = "https://api.gutzo.in";
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

    http.Response response;
    if (method == "POST") {
      response = await http.post(url, headers: headers, body: jsonEncode(body));
    } else if (method == "PUT") {
      response = await http.put(url, headers: headers, body: jsonEncode(body));
    } else if (method == "DELETE") {
      response = await http.delete(url, headers: headers);
    } else {
      response = await http.get(url, headers: headers);
    }

    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(responseData["message"] ?? "HTTP ${response.statusCode}");
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

  Future<dynamic> getVendors() async {
    return _request("/vendors");
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
}

final nodeApiServiceProvider = Provider<NodeApiService>((ref) {
  final supabase = Supabase.instance.client;
  return NodeApiService(supabase);
});
