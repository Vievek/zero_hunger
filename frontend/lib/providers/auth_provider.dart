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

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

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
    notifyListeners();

    try {
      final authResponse = await _apiService.login(email, password);
      _user = authResponse.user;
      _token = authResponse.token;
      _isAuthenticated = true;

      if (saveLogin) {
        await _storageService.saveAuthData(
          _token!,
          _user!.toJson().toString(),
          saveLogin,
        );
      }

      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Manual registration
  Future<void> register(
    String name,
    String email,
    String password,
    String role,
    String phone,
    String address,
    bool saveLogin,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authResponse = await _apiService.register(
        name,
        email,
        password,
        role,
        phone,
        address,
      );
      _user = authResponse.user;
      _token = authResponse.token;
      _isAuthenticated = true;

      if (saveLogin) {
        await _storageService.saveAuthData(
          _token!,
          _user!.toJson().toString(),
          saveLogin,
        );
      }

      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Google sign-in
  Future<void> googleSignIn(bool saveLogin) async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await _googleAuthService.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }

      // For now, simulate Google auth
      _user = User(
        id: googleUser.id,
        name: googleUser.displayName ?? 'Google User',
        email: googleUser.email,
        role: 'donor',
        profileCompleted: false,
      );

      _isAuthenticated = true;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Complete profile after Google sign-in
  Future<void> completeGoogleProfile(
    String role,
    String phone,
    String address,
    bool saveLogin,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_user == null) {
        throw Exception('No user data available');
      }

      _user = _user!.copyWith(
        role: role,
        phone: phone,
        address: address,
        profileCompleted: true,
      );

      if (saveLogin) {
        await _storageService.saveAuthData(
          _token ?? 'google_token',
          _user!.toJson().toString(),
          saveLogin,
        );
      }

      notifyListeners();
    } catch (error) {
      _isLoading = false;
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
      notifyListeners();
    }
  }

  // Update user profile
  Future<void> updateProfile(String name, String phone, String address) async {
    try {
      _user = _user!.copyWith(name: name, phone: phone, address: address);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }
}
