import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';

class RoleAuth extends AuthService {
  RoleAuth(super.api);
  UserRole role = UserRole.attendee;
  @override
  AppUser get currentUser => AppUser(
      id: 'same-account',
      name: 'Applicant',
      email: 'applicant@example.com',
      role: role);
  void updateRole(UserRole value) {
    role = value;
    notifyListeners();
  }
}

void main() {
  test('approval reloads organizer data when the same account gains its role',
      () async {
    final paths = <String>[];
    final api = ApiClient(client: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response('[]', 200);
    }));
    final auth = RoleAuth(api);
    final data = DataService(api, auth);
    auth.updateRole(UserRole.attendee);
    while (data.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(paths, contains('/api/v1/events'));
    paths.clear();
    auth.updateRole(UserRole.organizer);
    while (data.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(paths, ['/api/v1/organizer/events']);
    expect(data.errorMessage, isNull);
    data.dispose();
    auth.dispose();
  });
}
