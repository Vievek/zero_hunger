import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _tokenKey = 'auth_token';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _saveLoginKey = 'save_login';

  Future<void> saveAuthData(
    String token,
    String userData,
    bool saveLogin,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userDataKey, userData);
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setBool(_saveLoginKey, saveLogin);
  }

  Future<Map<String, dynamic>?> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldSave = prefs.getBool(_saveLoginKey) ?? true;

    if (!shouldSave) return null;

    final token = prefs.getString(_tokenKey);
    final userData = prefs.getString(_userDataKey);
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (token != null && userData != null && isLoggedIn) {
      return {'token': token, 'userData': userData};
    }
    return null;
  }

  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userDataKey);
    await prefs.setBool(_isLoggedInKey, false);
  }

  Future<bool> shouldSaveLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_saveLoginKey) ?? true;
  }
}
