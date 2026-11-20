import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/features/attendee/attendee_ui.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';

import 'attendee_flow_test.dart' as fixtures;

http.Response session(String id) => http.Response(
  jsonEncode({
    'access_token': 'token-$id',
    'user': {
      'id': id,
      'email': '$id@example.com',
      'full_name': id,
      'roles': ['attendee'],
    },
  }),
  200,
);

void main() {
  test(
    'disposing the data service invalidates its outstanding refresh',
    () async {
      final pending = Completer<http.Response>();
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) return session('buyer');
          if (r.url.path.endsWith('/events')) return pending.future;
          return http.Response('[]', 200);
        }),
      );
      final auth = AuthService(api);
      await auth.login(email: 'buyer@example.com', password: 'password');
      final data = DataService(api, auth);
      final refresh = data.refresh();
      data.dispose();
      pending.complete(http.Response('[]', 200));
      await refresh;
      auth.dispose();
    },
  );
  test(
    'calendar preserves offset and seconds, backend UID and cancellation',
    () {
      final event = AppEvent.fromJson({
        ...fixtures.eventJson,
        'starts_at': '2030-01-02T23:30:45+05:00',
        'ends_at': '2030-01-03T01:00:15+05:00',
        'status': 'cancelled',
      });
      final calendar = eventCalendar(event);
      expect(calendar, contains('DTSTART:20300102T183045Z'));
      expect(calendar, contains('DTEND:20300102T200015Z'));
      expect(calendar, contains('UID:event-event-id@biletflow.kz'));
      expect(calendar, contains('STATUS:CANCELLED'));
    },
  );

  test(
    'late 401 from an old session cannot sign out the current session',
    () async {
      final pending = Completer<http.Response>();
      final api = ApiClient(client: MockClient((_) => pending.future));
      api.token = 'old';
      var invalidated = false;
      api.onUnauthorized = () => invalidated = true;
      final request = api.request('GET', '/tickets');
      api.token = 'new';
      pending.complete(http.Response('{"detail":"expired"}', 401));
      await expectLater(request, throwsA(isA<ApiException>()));
      expect(invalidated, isFalse);
      expect(api.token, 'new');
    },
  );

  test('PDF or QR download 401 invalidates its expired session', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('expired', 401)),
    );
    api.token = 'old';
    var invalidated = false;
    api.onUnauthorized = () => invalidated = true;
    await expectLater(
      api.download('/tickets/t/pdf'),
      throwsA(isA<ApiException>()),
    );
    expect(invalidated, isTrue);
  });

  test('non-JSON gateway errors become retryable API errors', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response('<html>Bad gateway</html>', 502),
      ),
    );
    await expectLater(
      api.request('GET', '/events'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)),
    );
  });

  test('logout during login cannot resurrect the signed-out session', () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(client: MockClient((_) => pending.future));
    final auth = AuthService(api);
    final login = auth.login(email: 'old@example.com', password: 'password');
    auth.logout();
    pending.complete(session('old'));
    expect(await login, isFalse);
    expect(auth.currentUser, isNull);
    expect(api.token, isNull);
    auth.dispose();
  });

  test('late profile refresh cannot replace a newer account', () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/users/me')) return pending.future;
        return session(jsonDecode(r.body)['email'].toString().split('@').first);
      }),
    );
    final auth = AuthService(api);
    await auth.login(email: 'old@example.com', password: 'password');
    final refresh = auth.refreshUser();
    auth.logout();
    await auth.login(email: 'new@example.com', password: 'password');
    pending.complete(
      http.Response(
        jsonEncode({
          'id': 'old',
          'email': 'old@example.com',
          'full_name': 'old',
          'roles': ['attendee'],
        }),
        200,
      ),
    );
    await refresh;
    expect(auth.currentUser!.id, 'new');
    auth.dispose();
  });
}
