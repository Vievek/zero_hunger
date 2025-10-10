import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class ApiService {
  // ✅ SINGLETON PATTERN
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal(); // Private constructor

  static const String baseUrl = 'https://zero-hunger-three.vercel.app';
  String? _authToken;

  // Set authentication token
  void setAuthToken(String token) {
    debugPrint('🎯 setAuthToken() called with token: $token');
    debugPrint('🎯 Token length: ${token.length}');
    debugPrint(
        '🎯 Token first 10 chars: ${token.substring(0, min(10, token.length))}...');
    _authToken = token;
    debugPrint('🎯 _authToken after set: $_authToken');
  }

  // Get headers with auth
  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};

    debugPrint('🔐 _getHeaders() called - _authToken: $_authToken');
    debugPrint('🔐 Full _authToken value: "$_authToken"');
    debugPrint('🔐 _authToken is null: ${_authToken == null}');
    debugPrint('🔐 _authToken is empty: ${_authToken?.isEmpty ?? true}');

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
      debugPrint('🔐 Authorization header set: Bearer $_authToken');
    } else {
      debugPrint(
          '🔐 ❌ NO AUTH TOKEN AVAILABLE - Headers will not include Authorization');
    }

    debugPrint('🔐 Final headers: $headers');
    return headers;
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    debugPrint('Login response: ${response.body}');
    debugPrint('Status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return AuthResponse.fromJson(jsonResponse);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Login failed');
    }
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    required String address,
    Map<String, dynamic>? donorDetails,
    Map<String, dynamic>? recipientDetails,
    Map<String, dynamic>? volunteerDetails,
  }) async {
    final requestBody = {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'phone': phone,
      'address': address,
      if (donorDetails != null) 'donorDetails': donorDetails,
      if (recipientDetails != null) 'recipientDetails': recipientDetails,
      if (volunteerDetails != null) 'volunteerDetails': volunteerDetails,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    debugPrint('Register response: ${response.body}');
    debugPrint('Status code: ${response.statusCode}');

    if (response.statusCode == 201) {
      final jsonResponse = json.decode(response.body);
      return AuthResponse.fromJson(jsonResponse);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Registration failed');
    }
  }

  Future<User> getCurrentUser(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    debugPrint('Get user response: ${response.body}');
    debugPrint('Status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return User.fromJson(jsonResponse['user']);
    } else {
      throw Exception('Failed to get user data');
    }
  }

  Future<User> completeProfile({
    required String token,
    required String role,
    required String phone,
    required String address,
    Map<String, dynamic>? donorDetails,
    Map<String, dynamic>? recipientDetails,
    Map<String, dynamic>? volunteerDetails,
  }) async {
    final requestBody = {
      'role': role,
      'phone': phone,
      'address': address,
      if (donorDetails != null) 'donorDetails': donorDetails,
      if (recipientDetails != null) 'recipientDetails': recipientDetails,
      if (volunteerDetails != null) 'volunteerDetails': volunteerDetails,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/auth/complete-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(requestBody),
    );
    debugPrint(response.body);
    debugPrint('Status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return User.fromJson(jsonResponse['user']);
    } else {
      throw Exception('Profile completion failed');
    }
  }

  // Google authentication - ADDED BACK
  Future<AuthResponse> googleAuth(
      String googleId, String name, String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'googleId': googleId,
        'name': name,
        'email': email,
      }),
    );
    debugPrint(response.body);
    debugPrint('Status code: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonResponse = json.decode(response.body);
      return AuthResponse.fromJson(jsonResponse);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Google authentication failed');
    }
  }

  // Donation methods
  Future<dynamic> createDonation(Map<String, dynamic> donationData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/donations'),
      headers: _getHeaders(),
      body: json.encode(donationData),
    );

    return _handleResponse(response);
  }

  Future<dynamic> getMyDonations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/donations/my-donations'),
      headers: _getHeaders(),
    );

    return _handleResponse(response);
  }

  Future<dynamic> getDonationDetails(String donationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/donations/$donationId'),
      headers: _getHeaders(),
    );

    return _handleResponse(response);
  }

  Future<dynamic> acceptDonation(String donationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/donations/$donationId/accept'),
      headers: _getHeaders(),
    );
    return _handleResponse(response);
  }

// FoodSafe AI methods
  Future<dynamic> askFoodSafetyQuestion(
      String question, String foodType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/foodsafe/ask'),
      headers: _getHeaders(),
      body: json.encode({'question': question, 'foodType': foodType}),
    );
    return _handleResponse(response);
  }

  Future<dynamic> generateFoodLabel(
      String donationId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/foodsafe/generate-label/$donationId'),
      headers: _getHeaders(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> getFoodSafetyChecklist(String foodType) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/foodsafe/checklist?foodType=${Uri.encodeComponent(foodType)}'),
      headers: _getHeaders(),
    );
    return _handleResponse(response);
  }

  // Logistics methods - ADDED BACK
  Future<dynamic> getMyTasks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/my-tasks'),
      headers: _getHeaders(),
    );
    return _handleResponse(response);
  }

  Future<dynamic> updateTaskStatus(String taskId, String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/logistics/$taskId/status'),
      headers: _getHeaders(),
      body: json.encode({'status': status}),
    );
    return _handleResponse(response);
  }

  Future<dynamic> getOptimizedRoute(String taskId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/$taskId/route'),
      headers: _getHeaders(),
    );
    return _handleResponse(response);
  }

  // Image upload - SIMPLIFIED VERSION
  Future<String> uploadImage(String imagePath) async {
    // For now, return a placeholder URL
    // In production, implement actual multipart upload
    debugPrint('Image upload requested for: $imagePath');
    return 'https://example.com/uploaded-image.jpg';
  }

  // Upload multiple images
  Future<List<String>> uploadImages(List<String> imagePaths) async {
    try {
      List<String> uploadedUrls = [];

      for (String path in imagePaths) {
        try {
          final url = await uploadImage(path);
          uploadedUrls.add(url);
        } catch (e) {
          debugPrint('Failed to upload image $path: $e');
          // Continue with other images even if one fails
        }
      }

      if (uploadedUrls.isEmpty) {
        throw Exception('All image uploads failed');
      }

      return uploadedUrls;
    } catch (e) {
      debugPrint('Batch image upload error: $e');
      rethrow;
    }
  }

  // Helper methods
  Future<dynamic> _handleResponse(http.Response response) async {
    final data = json.decode(response.body);
    debugPrint('API Response: ${response.body}');
    debugPrint('Status code: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Something went wrong');
    }
  }

  // Health check
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      debugPrint('Health check: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check error: $e');
      return false;
    }
  }
}
