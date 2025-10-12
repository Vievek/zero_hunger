import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/google_auth_service.dart';
import '../services/token_manager.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  User? get user => _user;
  String? get token => _tokenManager.token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final TokenManager _tokenManager = TokenManager();

  // Auto login on app start
  Future<void> autoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load token from TokenManager
      await _tokenManager.loadToken();

      if (_tokenManager.isAuthenticated) {
        debugPrint(
            '🔄 AUTO LOGIN - Token found: ${_tokenManager.token?.substring(0, 10)}...');

        // Verify token by getting user data
        try {
          final user = await _apiService.getCurrentUser();
          _user = user;
          _isAuthenticated = true;

          if (kDebugMode) {
            print('Auto login successful: ${user.name}');
          }
        } catch (userError) {
          debugPrint('Auto login user fetch failed: $userError');
          await _storageService.clearAuthData();
          await _tokenManager.clearToken();
          _resetAuthState();
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Auto login failed: $error');
      }
      await _storageService.clearAuthData();
      await _tokenManager.clearToken();
      _resetAuthState();
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
      _isAuthenticated = true;

      // ✅ Set token via TokenManager (handles persistence and propagation)
      await _tokenManager.setToken(authResponse.token);
      debugPrint('🔄 LOGIN SUCCESS - Token set via TokenManager');

      if (saveLogin) {
        await _storageService.saveAuthData(
          authResponse.token,
          _user!.toJson().toString(),
          saveLogin,
        );
        debugPrint('🔄 Auth data saved to storage');
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
      _isAuthenticated = true;

      // ✅ Set token via TokenManager (handles persistence and propagation)
      await _tokenManager.setToken(authResponse.token);
      debugPrint('🔄 REGISTER SUCCESS - Token set via TokenManager');

      if (saveLogin) {
        await _storageService.saveAuthData(
          authResponse.token,
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
      _isAuthenticated = true;

      // ✅ Set token via TokenManager (handles persistence and propagation)
      await _tokenManager.setToken(authResponse.token);
      debugPrint('🔄 GOOGLE SIGNIN SUCCESS - Token set via TokenManager');

      if (saveLogin) {
        await _storageService.saveAuthData(
          authResponse.token,
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
      if (_user == null || !_tokenManager.isAuthenticated) {
        throw Exception('No user data available');
      }

      final updatedUser = await _apiService.completeProfile(
        // REMOVED: token: _tokenManager.token!,
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
          _tokenManager.token!,
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
  // Update user profile
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    Map<String, dynamic>? donorDetails,
    Map<String, dynamic>? recipientDetails,
    Map<String, dynamic>? volunteerDetails,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = await _apiService.updateProfile(
        name: name,
        phone: phone,
        address: address,
        donorDetails: donorDetails,
        recipientDetails: recipientDetails,
        volunteerDetails: volunteerDetails,
      );

      _user = updatedUser;

      // Update stored user data
      final authData = await _storageService.getAuthData();
      if (authData != null && _tokenManager.isAuthenticated) {
        await _storageService.saveAuthData(
          _tokenManager.token!,
          _user!.toJson().toString(),
          true,
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

// In AuthProvider class - Update the logout method
  Future<void> logout() async {
    try {
      // Clear all services in parallel
      await Future.wait([
        _googleAuthService.signOut(),
        _storageService.clearAuthData(),
        _tokenManager.clearToken(),
      ], eagerError: true);

      // Reset all auth state
      _resetAuthState();

      if (kDebugMode) {
        print('🔄 LOGOUT - All auth data cleared successfully');
      }
    } catch (error) {
      if (kDebugMode) {
        print('Logout error: $error');
      }
      // Even if there's an error, reset the local state
      _resetAuthState();
    } finally {
      notifyListeners();
    }
  }

// Ensure _resetAuthState completely clears everything
  void _resetAuthState() {
    _user = null;
    _isAuthenticated = false;
    _isLoading = false;
    _error = null;
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    try {
      if (!_tokenManager.isAuthenticated) return;

      final user = await _apiService.getCurrentUser();
      _user = user;
      notifyListeners();

      // Update stored user data
      final authData = await _storageService.getAuthData();
      if (authData != null && _tokenManager.isAuthenticated) {
        await _storageService.saveAuthData(
          _tokenManager.token!,
          _user!.toJson().toString(),
          true,
        );
      }
    } catch (error) {
      debugPrint('Failed to refresh user data: $error');
      // Don't throw error - this shouldn't break the app
    }
  }

  // Check token validity
  Future<bool> checkTokenValidity() async {
    try {
      if (!_tokenManager.isAuthenticated) return false;

      await _apiService.getCurrentUser();
      return true;
    } catch (error) {
      debugPrint('Token validity check failed: $error');
      await logout();
      return false;
    }
  }

  // Helper methods

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

  // User preferences
  Future<bool> get shouldSaveLogin async {
    return await _storageService.shouldSaveLogin();
  }

  // Validate session
  Future<bool> validateSession() async {
    if (!_tokenManager.isAuthenticated || _user == null) {
      return false;
    }

    try {
      await _apiService.getCurrentUser();
      return true;
    } catch (error) {
      debugPrint('Session validation failed: $error');
      await logout();
      return false;
    }
  }
}
