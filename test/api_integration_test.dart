import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/models/user.dart';

void main() {
  test('Registration sends password and login takes role from backend', () async {
    final paths = <String>[];
    final api = ApiClient(client: MockClient((request) async {
      paths.add(request.url.path);
      expect(jsonDecode(request.body)['password'], 'secure-password');
      if (request.url.path.endsWith('/register')) return http.Response('{}', 201);
      return http.Response(jsonEncode({'access_token': 'test-token', 'user': {
        'id': 'user-id', 'full_name': 'Test User', 'email': 'test@example.com',
        'roles': ['attendee', 'organizer'],
      }}), 200);
    }));
    final auth = AuthService(api);
    expect(await auth.register(name: 'Test User', email: 'test@example.com', password: 'secure-password'), isTrue);
    expect(paths, ['/api/v1/auth/register', '/api/v1/auth/login']);
    expect(auth.currentUser!.role, UserRole.organizer);
    expect(api.headers['Authorization'], 'Bearer test-token');
    auth.logout();
    expect(api.token, isNull);
    expect(auth.currentUser, isNull);
  });
  test('Failed registration remains signed out and exposes server error', () async {
    final api = ApiClient(client: MockClient((_) async => http.Response('{"detail":"EMAIL_ALREADY_REGISTERED"}', 409)));
    final auth = AuthService(api);
    expect(await auth.register(name: 'Test User', email: 'test@example.com', password: 'secure-password'), isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.errorMessage, 'EMAIL_ALREADY_REGISTERED');
    expect(auth.isLoading, isFalse);
  });
  test('Unauthorized requests invalidate the active session', () async {
    final api = ApiClient(client: MockClient((_) async => http.Response('{"detail":"Expired"}', 401)));
    var expired = false;
    api.token = 'expired-token';
    api.onUnauthorized = () => expired = true;
    await expectLater(api.request('GET', '/tickets'), throwsA(isA<ApiException>()));
    expect(expired, isTrue);
  });
}
