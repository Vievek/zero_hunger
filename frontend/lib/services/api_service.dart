import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'https://zero-hunger-three.vercel.app/api';
  String? _authToken;

  // Enhanced token management
  Future<void> setAuthToken(String token) async {
    debugPrint('🔐 SETTING AUTH TOKEN: ${token.substring(0, 10)}...');
    _authToken = token;

    // Persist token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    debugPrint('🔐 Token saved to shared preferences');
  }

  Future<void> loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    debugPrint('🔐 Loaded auth token from storage: ${_authToken != null}');
  }

  Future<void> clearAuthToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    debugPrint('🔐 Auth token cleared');
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
      debugPrint('🔐 Adding Authorization header to request');
    } else {
      debugPrint('🔐 No auth token available for request');
    }

    return headers;
  }

  // Enhanced request method with better error handling
  Future<dynamic> _makeRequest(
    String method,
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      if (requiresAuth && _authToken == null) {
        await loadAuthToken();
      }

      final url = Uri.parse('$baseUrl$endpoint');
      final headers = _getHeaders();

      debugPrint('🌐 API Request: $method $endpoint');
      if (body != null) {
        debugPrint('📦 Request Body: ${jsonEncode(body)}');
      }

      http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          response = await http.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      debugPrint('🌐 API Response: ${response.statusCode} $endpoint');
      if (response.body.isNotEmpty) {
        debugPrint('📦 Response Body: ${response.body}');
      }

      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        final errorMessage = responseData['message'] ??
            responseData['error'] ??
            'Request failed with status ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (error) {
      debugPrint('❌ API Error: $method $endpoint - $error');
      rethrow;
    }
  }

  // Authentication endpoints
  Future<AuthResponse> login(String email, String password) async {
    final response = await _makeRequest('POST', '/auth/login',
        body: {
          'email': email,
          'password': password,
        },
        requiresAuth: false);

    return AuthResponse.fromJson(response);
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

    final response = await _makeRequest('POST', '/auth/register',
        body: requestBody, requiresAuth: false);

    return AuthResponse.fromJson(response);
  }

  Future<User> getCurrentUser() async {
    final response = await _makeRequest('GET', '/auth/me');
    return User.fromJson(response['user']);
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
    final response =
        await _makeRequest('POST', '/auth/complete-profile', body: {
      'role': role,
      'phone': phone,
      'address': address,
      if (donorDetails != null) 'donorDetails': donorDetails,
      if (recipientDetails != null) 'recipientDetails': recipientDetails,
      if (volunteerDetails != null) 'volunteerDetails': volunteerDetails,
    });

    return User.fromJson(response['user']);
  }

  Future<User> updateProfile({
    String? name,
    String? phone,
    String? address,
    Map<String, dynamic>? donorDetails,
    Map<String, dynamic>? recipientDetails,
    Map<String, dynamic>? volunteerDetails,
  }) async {
    final response = await _makeRequest('PATCH', '/auth/profile', body: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (donorDetails != null) 'donorDetails': donorDetails,
      if (recipientDetails != null) 'recipientDetails': recipientDetails,
      if (volunteerDetails != null) 'volunteerDetails': volunteerDetails,
    });

    return User.fromJson(response['user']);
  }

  // Donation endpoints
  Future<dynamic> createDonation(Map<String, dynamic> donationData) async {
    return await _makeRequest('POST', '/donations', body: donationData);
  }

  Future<dynamic> getMyDonations() async {
    return await _makeRequest('GET', '/donations/my-donations');
  }

  Future<dynamic> getAvailableDonations({
    int page = 1,
    int limit = 10,
    String? query,
    List<String>? categories,
  }) async {
    String endpoint = '/donations/available?page=$page&limit=$limit';

    if (query != null && query.isNotEmpty) {
      endpoint += '&query=${Uri.encodeComponent(query)}';
    }

    if (categories != null && categories.isNotEmpty) {
      endpoint += '&categories=${categories.join(',')}';
    }

    return await _makeRequest('GET', endpoint);
  }

  Future<dynamic> acceptDonation(String donationId) async {
    return await _makeRequest('POST', '/donations/$donationId/accept');
  }

  Future<dynamic> uploadImages(List<File> imageFiles) async {
    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/donations/upload-images'));

      // Add authorization header
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      // Add images
      for (var imageFile in imageFiles) {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          imageFile.path,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Image upload failed');
      }
    } catch (error) {
      debugPrint('Image upload error: $error');
      rethrow;
    }
  }

  Future<dynamic> getDonationDetails(String donationId) async {
    return await _makeRequest('GET', '/donations/$donationId');
  }

  Future<dynamic> updateDonationStatus(String donationId, String status) async {
    return await _makeRequest('PATCH', '/donations/$donationId/status',
        body: {'status': status});
  }

  Future<dynamic> getDonationStats() async {
    return await _makeRequest('GET', '/donations/stats/overview');
  }

  Future<dynamic> searchDonations(
    String query, {
    List<String>? categories,
    double? maxDistance,
  }) async {
    String endpoint =
        '/donations/search/available?query=${Uri.encodeComponent(query)}';

    if (categories != null && categories.isNotEmpty) {
      endpoint += '&categories=${categories.join(',')}';
    }

    if (maxDistance != null) {
      endpoint += '&maxDistance=$maxDistance';
    }

    return await _makeRequest('GET', endpoint);
  }

  // FoodSafe AI endpoints
  Future<dynamic> askFoodSafetyQuestion(
      String question, String foodType) async {
    return await _makeRequest('POST', '/foodsafe/ask', body: {
      'question': question,
      'foodType': foodType,
    });
  }

  Future<dynamic> generateFoodLabel(
      String donationId, Map<String, dynamic> data) async {
    return await _makeRequest('POST', '/foodsafe/generate-label/$donationId',
        body: data);
  }

  Future<dynamic> getFoodSafetyChecklist([String? foodType]) async {
    String endpoint = '/foodsafe/checklist';
    if (foodType != null) {
      endpoint += '?foodType=${Uri.encodeComponent(foodType)}';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<dynamic> getFoodSafetyQuickReference([String? foodType]) async {
    String endpoint = '/foodsafe/quick-reference';
    if (foodType != null) {
      endpoint += '?foodType=${Uri.encodeComponent(foodType)}';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Logistics endpoints
  Future<dynamic> getMyTasks() async {
    return await _makeRequest('GET', '/logistics/my-tasks');
  }

  Future<dynamic> updateTaskStatus(String taskId, String status) async {
    return await _makeRequest('PUT', '/logistics/$taskId/status',
        body: {'status': status});
  }

  Future<dynamic> getOptimizedRoute(String taskId) async {
    return await _makeRequest('GET', '/logistics/$taskId/route');
  }

  Future<dynamic> getVolunteerStats() async {
    return await _makeRequest('GET', '/logistics/stats/volunteer');
  }

  Future<dynamic> updateVolunteerLocation(double lat, double lng,
      {String? address}) async {
    return await _makeRequest('PUT', '/logistics/location/update', body: {
      'lat': lat,
      'lng': lng,
      if (address != null) 'address': address,
    });
  }

  Future<dynamic> getTaskDetails(String taskId) async {
    return await _makeRequest('GET', '/logistics/tasks/$taskId/details');
  }

  Future<dynamic> updateSafetyChecklist(
      String taskId, List<Map<String, dynamic>> checklist) async {
    return await _makeRequest(
        'PUT', '/logistics/tasks/$taskId/safety-checklist',
        body: {'checklist': checklist});
  }

  Future<dynamic> getRouteUpdate(
      String taskId, double currentLat, double currentLng) async {
    return await _makeRequest('GET',
        '/logistics/tasks/$taskId/route/update?currentLat=$currentLat&currentLng=$currentLng');
  }

  Future<dynamic> submitTaskFeedback(
    String taskId, {
    required int rating,
    String? feedback,
    int? completionTime,
  }) async {
    return await _makeRequest('POST', '/logistics/tasks/$taskId/feedback',
        body: {
          'rating': rating,
          if (feedback != null) 'feedback': feedback,
          if (completionTime != null) 'completionTime': completionTime,
        });
  }

  Future<dynamic> getPerformanceMetrics() async {
    return await _makeRequest('GET', '/logistics/performance/metrics');
  }

  // Google Auth endpoint (placeholder - implement based on your backend)
  Future<AuthResponse> googleAuth(
      String googleId, String displayName, String email) async {
    // This would call your backend Google auth endpoint
    // For now, using regular login as placeholder
    return await login(email, 'google_auth_placeholder');
  }

  // Health check
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check error: $e');
      return false;
    }
  }

  // Enhanced error handling helper
  String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
}
