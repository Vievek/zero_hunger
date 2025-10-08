import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = 'https://zero-hunger-three.vercel.app';

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
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Body: ${response.body}');
    debugPrint('Redirect Location: ${response.headers['location']}');

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

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return User.fromJson(jsonResponse['user']);
    } else {
      throw Exception('Profile completion failed');
    }
  }

  // Donation methods
  Future<dynamic> createDonation(Map<String, dynamic> donationData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/donations'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(donationData),
    );
    return _handleResponse(response);
  }

  Future<dynamic> getMyDonations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/donations/my-donations'),
    );
    return _handleResponse(response);
  }

  Future<dynamic> acceptDonation(String donationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/donations/$donationId/accept'),
    );
    return _handleResponse(response);
  }

  // FoodSafe AI methods
  Future<dynamic> askFoodSafetyQuestion(
    String question,
    String foodType,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/foodsafe/ask'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'question': question, 'foodType': foodType}),
    );
    return _handleResponse(response);
  }

  Future<dynamic> generateFoodLabel(
    String donationId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/foodsafe/generate-label/$donationId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  // Logistics methods
  Future<dynamic> getMyTasks() async {
    final response = await http.get(Uri.parse('$baseUrl/logistics/my-tasks'));
    return _handleResponse(response);
  }

  Future<dynamic> updateTaskStatus(String taskId, String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/logistics/$taskId/status'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );
    return _handleResponse(response);
  }

  Future<dynamic> getOptimizedRoute(String taskId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/$taskId/route'),
    );
    return _handleResponse(response);
  }

  // Helper methods
  Future<dynamic> _handleResponse(http.Response response) async {
    final data = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Something went wrong');
    }
  }

  // Image upload
  Future<String> uploadImage(String imagePath) async {
    // Simplified implementation - you'll need to implement actual upload
    // For now, return a dummy URL
    return 'https://example.com/uploaded-image.jpg';
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
