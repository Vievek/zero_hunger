import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized token management service implementing singleton pattern
/// Handles token lifecycle, persistence, and synchronization across the app
class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  String? _authToken;
  final StreamController<String?> _tokenStreamController =
      StreamController<String?>.broadcast();

  /// Stream for listening to token changes
  Stream<String?> get tokenStream => _tokenStreamController.stream;

  /// Current authentication token
  String? get token => _authToken;

  /// Whether user is authenticated (has valid token)
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  /// Set authentication token and notify all listeners
  Future<void> setToken(String? token) async {
    debugPrint(
        '🔐 TokenManager: Setting token ${token != null ? '(${token.length} chars)' : '(null)'}');

    _authToken = token;

    // Persist token to storage
    if (token != null && token.isNotEmpty) {
      await _persistToken(token);
    } else {
      await _clearPersistedToken();
    }

    // Notify all listeners
    _tokenStreamController.add(_authToken);
    debugPrint(
        '🔐 TokenManager: Token updated and broadcasted to all listeners');
  }

  /// Load token from persistent storage
  Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      debugPrint(
          '🔐 TokenManager: Loaded token from storage ${_authToken != null ? '(found)' : '(not found)'}');
    } catch (error) {
      debugPrint('🔐 TokenManager: Error loading token from storage: $error');
      _authToken = null;
    }
  }

  /// Clear authentication token
  Future<void> clearToken() async {
    debugPrint('🔐 TokenManager: Clearing token');
    await setToken(null);
  }

  /// Persist token to storage
  Future<void> _persistToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      debugPrint('🔐 TokenManager: Token persisted to storage');
    } catch (error) {
      debugPrint('🔐 TokenManager: Error persisting token: $error');
    }
  }

  /// Clear persisted token
  Future<void> _clearPersistedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      debugPrint('🔐 TokenManager: Persisted token cleared');
    } catch (error) {
      debugPrint('🔐 TokenManager: Error clearing persisted token: $error');
    }
  }

  /// Get authorization header value
  String? getAuthHeader() {
    return _authToken != null && _authToken!.isNotEmpty
        ? 'Bearer $_authToken'
        : null;
  }

  /// Validate token format (basic validation)
  bool isValidTokenFormat(String? token) {
    if (token == null || token.isEmpty) return false;
    // Basic JWT format check (3 parts separated by dots)
    final parts = token.split('.');
    return parts.length == 3;
  }

  /// Dispose resources
  void dispose() {
    _tokenStreamController.close();
  }
}
