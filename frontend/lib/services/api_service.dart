import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/donation_model.dart';
import '../models/logistics_model.dart';

class ApiService {
  static const String baseUrl =
      'http://localhost:5000/api'; // For iOS simulator
  // static const String baseUrl = 'http://10.0.2.2:5000/api'; // For Android emulator
  // static const String baseUrl = 'http://your-ip:5000/api'; // For real device

  // Helper method to get headers with token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> _getToken() async {
    // You'll need to implement token storage retrieval
    // This depends on your StorageService implementation
    return null;
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    final data = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Something went wrong');
    }
  }

  // ============ AUTH METHODS ============
  Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return AuthResponse.fromJson(jsonResponse);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Login failed');
    }
  }

  Future<AuthResponse> register(
    String name,
    String email,
    String password,
    String role,
    String phone,
    String address, {
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

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return User.fromJson(jsonResponse['user']);
    } else {
      throw Exception('Failed to get user data');
    }
  }

  Future<User> completeProfile(
    String token,
    String role,
    String phone,
    String address, {
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

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return User.fromJson(jsonResponse['user']);
    } else {
      throw Exception('Profile completion failed');
    }
  }

  // ============ DONATION METHODS ============
  Future<dynamic> createDonation(Map<String, dynamic> donationData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/donations'),
      headers: headers,
      body: json.encode(donationData),
    );
    return await _handleResponse(response);
  }

  Future<dynamic> getMyDonations() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/donations/my-donations'),
      headers: headers,
    );
    return await _handleResponse(response);
  }

  Future<dynamic> acceptDonation(String donationId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/donations/$donationId/accept'),
      headers: headers,
    );
    return await _handleResponse(response);
  }

  // ============ FOODSAFE AI METHODS ============
  Future<dynamic> askFoodSafetyQuestion(
    String question,
    String foodType,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/foodsafe/ask'),
      headers: headers,
      body: json.encode({'question': question, 'foodType': foodType}),
    );
    return await _handleResponse(response);
  }

  Future<dynamic> generateFoodLabel(
    String donationId,
    Map<String, dynamic> data,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/foodsafe/generate-label/$donationId'),
      headers: headers,
      body: json.encode(data),
    );
    return await _handleResponse(response);
  }

  // ============ LOGISTICS METHODS ============
  Future<dynamic> getMyTasks() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/my-tasks'),
      headers: headers,
    );
    return await _handleResponse(response);
  }

  Future<dynamic> updateTaskStatus(String taskId, String status) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/logistics/$taskId/status'),
      headers: headers,
      body: json.encode({'status': status}),
    );
    return await _handleResponse(response);
  }

  Future<dynamic> getOptimizedRoute(String taskId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/$taskId/route'),
      headers: headers,
    );
    return await _handleResponse(response);
  }

  // ============ NOTIFICATION METHODS ============
  Future<dynamic> getMyNotifications() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: headers,
    );
    return await _handleResponse(response);
  }

  Future<dynamic> markNotificationAsRead(String notificationId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: headers,
    );
    return await _handleResponse(response);
  }

  // ============ IMAGE UPLOAD ============
  Future<String> uploadImage(String imagePath) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);

    // Remove Content-Type from headers for multipart request
    final cleanHeaders = Map<String, String>.from(headers);
    cleanHeaders.remove('Content-Type');
    request.headers.addAll(cleanHeaders);

    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final data = json.decode(responseData);

    if (response.statusCode == 200) {
      return data['imageUrl'];
    } else {
      throw Exception(data['message'] ?? 'Image upload failed');
    }
  }

  // Health check
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
