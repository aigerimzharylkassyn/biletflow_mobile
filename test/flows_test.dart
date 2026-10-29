import 'dart:convert';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _user = {
  'id': 'user-id', 'full_name': 'Aida', 'email': 'aida@example.com',
  'roles': ['attendee'], 'email_verified': false,
};

/// Records every request and answers from [routes] keyed by "METHOD path".
({ApiClient api, List<http.Request> requests}) _backend(Map<String, http.Response Function(http.Request)> routes) {
  final requests = <http.Request>[];
  final api = ApiClient(client: MockClient((request) async {
    requests.add(request);
    final handler = routes['${request.method} ${request.url.path.replaceFirst('/api/v1', '')}'];
    return handler?.call(request) ?? http.Response('[]', 200);
  }));
  return (api: api, requests: requests);
}

http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);

void main() {
  test('user parses email verification state', () {
    expect(AppUser.fromJson(_user).emailVerified, isFalse);
    expect(AppUser.fromJson({..._user, 'email_verified': true}).emailVerified, isTrue);
  });

  test('forgot password and resend verification post the email', () async {
    final backend = _backend({
      'POST /auth/login': (_) => _json({'access_token': 't', 'user': _user}),
      'POST /auth/forgot-password': (_) => _json({'message': 'ok'}, 202),
      'POST /auth/resend-verification': (_) => _json({'message': 'ok'}, 202),
      'GET /users/me': (_) => _json({..._user, 'email_verified': true}),
    });
    final auth = AuthService(backend.api);
    await auth.forgotPassword('  aida@example.com ');
    expect(jsonDecode(backend.requests.last.body), {'email': 'aida@example.com'});
    await auth.login(email: 'aida@example.com', password: 'secret-pass');
    await auth.resendVerification();
    expect(backend.requests.last.url.path, '/api/v1/auth/resend-verification');
    expect(jsonDecode(backend.requests.last.body), {'email': 'aida@example.com'});
    await auth.refreshUser();
    expect(auth.currentUser!.emailVerified, isTrue);
  });

  test('promo quotes and reservations send a normalized code', () async {
    final backend = _backend({
      'POST /auth/login': (_) => _json({'access_token': 't', 'user': _user}),
      'POST /promo-codes/validate': (_) => _json({'subtotal_minor': 100000, 'discount_minor': 20000,
        'processing_fee_minor': 2400, 'total_minor': 82400, 'promo_code': 'CAMPUS20'}),
      'POST /checkout/sessions': (_) => _json({'id': 'order-id', 'total_minor': 82400}, 201),
    });
    final auth = AuthService(backend.api);
    final data = DataService(backend.api, auth);
    await auth.login(email: 'aida@example.com', password: 'secret-pass');
    final items = [{'ticket_type_id': 'type-id', 'quantity': 2}];

    final quote = await data.quote('event-id', items, ' campus20 ');
    expect(quote['discount_minor'], 20000);
    final quoteBody = jsonDecode(backend.requests.last.body);
    expect(quoteBody['promo_code'], 'CAMPUS20');
    expect(quoteBody['items'], items);

    await data.reserveTickets('event-id', items,
        name: 'Aida', email: 'aida@example.com', key: 'k1', promo: 'campus20');
    expect(jsonDecode(backend.requests.last.body)['promo_code'], 'CAMPUS20');
  });

  test('rejected promo codes surface the backend message', () async {
    final backend = _backend({
      'POST /promo-codes/validate': (_) => _json({'detail': 'Promo code OLD has expired.'}, 422),
    });
    final data = DataService(backend.api, AuthService(backend.api));
    await expectLater(
      data.quote('event-id', [{'ticket_type_id': 'type-id', 'quantity': 1}], 'old'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Promo code OLD has expired.')),
    );
  });

  test('scanning a Campaign QR at check-in surfaces the backend rejection', () async {
    const campaignUrl = 'https://biletflow.kz/campaign/abc?x=1';
    final backend = _backend({
      'POST /check-in/events/event-id/admit': (_) => _json(
          {'detail': 'This is a promotional Campaign QR code, not an admission ticket.'}, 409),
    });
    final data = DataService(backend.api, AuthService(backend.api));
    await expectLater(
      data.admit('event-id', campaignUrl),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('not an admission ticket'))),
    );
    expect(backend.requests.last.url.queryParameters['qr_payload'], campaignUrl);
  });
}
