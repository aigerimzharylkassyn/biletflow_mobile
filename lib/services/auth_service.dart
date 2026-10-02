import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  AuthService(this.api) { api.onUnauthorized = logout; }
  final ApiClient api;
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> login({required String email, required String password}) async {
    return _authenticate(email: email, password: password);
  }
  Future<bool> register({required String name, required String email, required String password}) async {
    return _authenticate(email: email, password: password, name: name);
  }
  Future<bool> _authenticate({required String email, required String password, String? name}) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (name != null) {
        await api.request('POST', '/auth/register', body: {
          'full_name': name, 'email': email.trim(), 'password': password,
        });
      }
      final data = await api.request('POST', '/auth/login', body: {
        'email': email.trim(), 'password': password,
      });
      api.token = data['access_token'] as String;
      _currentUser = AppUser.fromJson(Map<String, dynamic>.from(data['user']));
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> refreshUser() async {
    final data = await api.request('GET', '/users/me');
    _currentUser = AppUser.fromJson(Map<String, dynamic>.from(data));
    notifyListeners();
  }

  void logout() {
    api.token = null;
    _currentUser = null;
    notifyListeners();
  }
}
