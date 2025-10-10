import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/google_auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  // Auto login on app start
  Future<void> autoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final authData = await _storageService.getAuthData();
      if (authData != null) {
        _token = authData['token'];
         debugPrint('🔄 LOGIN SUCCESS - Token received: $_token');
        debugPrint('🔄 Token length: ${_token?.length}');

        // ✅ Set the token in ApiService
        if (_token != null) {
          debugPrint('🔄 Calling _apiService.setAuthToken()');
          _apiService.setAuthToken(_token!);

          // ✅ VERIFY it was set
          debugPrint('🔄 Verifying token was set in ApiService...');
        } else {
          debugPrint('🔄 ❌ CRITICAL: _token is NULL after login!');
        }
        // Verify token by getting user data
        final user = await _apiService.getCurrentUser(_token!);
        _user = user;
        _isAuthenticated = true;

        if (kDebugMode) {
          print('Auto login successful: ${user.name}');
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Auto login failed: $error');
      }
      await _storageService.clearAuthData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Manual login
  Future<void> login(String email, String password, bool saveLogin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authResponse = await _apiService.login(email, password);
      _user = authResponse.user;
      _token = authResponse.token;
      _isAuthenticated = true;

      debugPrint('🔄 LOGIN SUCCESS - Token received: $_token');
      debugPrint('🔄 Token length: ${_token?.length}');

      // ✅ Set the token in ApiService
      if (_token != null) {
        debugPrint('🔄 Calling _apiService.setAuthToken()');
        _apiService.setAuthToken(_token!);

        // ✅ VERIFY it was set
        debugPrint('🔄 Verifying token was set in ApiService...');
      } else {
        debugPrint('🔄 ❌ CRITICAL: _token is NULL after login!');
      }

      if (saveLogin) {
        await _storageService.saveAuthData(
          _token!,
          _user!.toJson().toString(),
          saveLogin,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Enhanced registration with role-specific details
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    required String address,
    required bool saveLogin,
    Map<String, dynamic>? donorDetails,
    Map<String, dynamic>? recipientDetails,
    Map<String, dynamic>? volunteerDetails,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authResponse = await _apiService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
        address: address,
        donorDetails: donorDetails,
        recipientDetails: recipientDetails,
        volunteerDetails: volunteerDetails,
      );
      _user = authResponse.user;
      _token = authResponse.token;
      _isAuthenticated = true;
      debugPrint('🔄 REGISTER SUCCESS - Token received: $_token');
      debugPrint('🔄 Token length: ${_token?.length}');

      // ✅ Set the token in ApiService
      if (_token != null) {
        debugPrint('🔄 Calling _apiService.setAuthToken()');
        _apiService.setAuthToken(_token!);

        // ✅ VERIFY it was set
        debugPrint('🔄 Verifying token was set in ApiService...');
      } else {
        debugPrint('🔄 ❌ CRITICAL: _token is NULL after login!');
      }
      if (saveLogin) {
        await _storageService.saveAuthData(
          _token!,
          _user!.toJson().toString(),
          saveLogin,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Google sign-in
  Future<void> googleSignIn(bool saveLogin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final googleUser = await _googleAuthService.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }

      // Call backend Google auth endpoint
      final authResponse = await _apiService.googleAuth(
        googleUser.id,
        googleUser.displayName ?? 'Google User',
        googleUser.email,
      );

      _user = authResponse.user;
      _token = authResponse.token;
      _isAuthenticated = true;
      debugPrint('🔄 LOGIN SUCCESS - Token received: $_token');
      debugPrint('🔄 Token length: ${_token?.length}');

      // ✅ Set the token in ApiService
      if (_token != null) {
        debugPrint('🔄 Calling _apiService.setAuthToken()');
        _apiService.setAuthToken(_token!);

        // ✅ VERIFY it was set
        debugPrint('🔄 Verifying token was set in ApiService...');
      } else {
        debugPrint('🔄 ❌ CRITICAL: _token is NULL after login!');
      }

      if (saveLogin) {
        await _storageService.saveAuthData(
          _token!,
          _user!.toJson().toString(),
          saveLogin,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Complete profile after Google sign-in with role-specific details
  Future<void> completeGoogleProfile({
    required String role,
    required String phone,
    required String address,
    required bool saveLogin,
    Map<String, dynamic>? donorDetails,
    Map<String, dynamic>? recipientDetails,
    Map<String, dynamic>? volunteerDetails,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_user == null || _token == null) {
        throw Exception('No user data available');
      }

      final updatedUser = await _apiService.completeProfile(
        token: _token!,
        role: role,
        phone: phone,
        address: address,
        donorDetails: donorDetails,
        recipientDetails: recipientDetails,
        volunteerDetails: volunteerDetails,
      );

      _user = updatedUser;

      if (saveLogin) {
        await _storageService.saveAuthData(
          _token!,
          _user!.toJson().toString(),
          saveLogin,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleAuthService.signOut();
      await _storageService.clearAuthData();
    } catch (error) {
      if (kDebugMode) {
        print('Logout error: $error');
      }
    } finally {
      _user = null;
      _token = null;
      _isAuthenticated = false;
      _error = null;
      notifyListeners();
    }
  }

  // Update user profile
  Future<void> updateProfile(String name, String phone, String address) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = _user!.copyWith(name: name, phone: phone, address: address);
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Check if user needs to complete profile
  bool get needsProfileCompletion {
    return _user != null && !_user!.profileCompleted;
  }

  // Role-specific getters
  bool get isDonor => _user?.isDonor ?? false;
  bool get isRecipient => _user?.isRecipient ?? false;
  bool get isVolunteer => _user?.isVolunteer ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
}
