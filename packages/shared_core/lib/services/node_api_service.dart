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
    final headers = {
      "Content-Type": "application/json",
    };

    if (session?.accessToken != null) {
      headers["Authorization"] = "Bearer ${session!.accessToken}";
    }

    if (overridePhone != null) {
      headers["x-user-phone"] = _formatPhone(overridePhone);
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

  Future<dynamic> getVendorProducts(String vendorId) async {
    return _request("/vendors/$vendorId/products");
  }

  // --- Orders & Tracking ---
  Future<dynamic> createOrder(Map<String, dynamic> orderData) async {
    return _request("/orders", method: "POST", body: orderData);
  }

  Future<dynamic> getOrderTracking(String orderId) async {
    return _request("/orders/$orderId/track");
  }

  Future<dynamic> getUserOrders({int page = 1, int limit = 20}) async {
    return _request("/orders?page=$page&limit=$limit");
  }

  Future<dynamic> triggerMockPayment(String orderNumber) async {
    return _request("/payments/mock-success", method: "POST", body: {
      "orderId": orderNumber,
      "mockShadowfax": true
    });
  }
}

final nodeApiServiceProvider = Provider<NodeApiService>((ref) {
  final supabase = Supabase.instance.client;
  return NodeApiService(supabase);
});
