import 'dart:convert';
import 'package:biletflow_mobile/features/organizer/checkin_screen.dart';
import 'package:biletflow_mobile/models/event.dart';
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

final _event = AppEvent.fromJson({
  'id': 'event-id', 'organizer_id': 'org', 'title': 'Concert', 'description': 'd', 'category': 'music',
  'status': 'published', 'starts_at': '2026-11-10T13:00:00Z', 'ends_at': '2026-11-10T15:00:00Z',
  'venue': {'name': 'Hall', 'address': 'A', 'city': 'Almaty'}, 'available_ticket_types': [],
});

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
    await auth.reloadUser();
    expect(auth.currentUser!.emailVerified, isTrue);
  });

  test('checkout quotes and reserves with a normalized promo code, and cancels cleanly', () async {
    final backend = _backend({
      'POST /auth/login': (_) => _json({'access_token': 't', 'user': _user}),
      'POST /promo-codes/validate': (_) => _json({'subtotal_minor': 100000, 'discount_minor': 20000,
        'processing_fee_minor': 2400, 'total_minor': 82400, 'promo_code': 'CAMPUS20'}),
      'POST /checkout/sessions': (_) => _json({'id': 'order-id', 'total_minor': 82400}, 201),
      'POST /checkout/sessions/order-id/cancel': (_) => _json({'id': 'order-id', 'status': 'cancelled'}),
    });
    final auth = AuthService(backend.api);
    final data = DataService(backend.api, auth);
    await auth.login(email: 'aida@example.com', password: 'secret-pass');

    final quote = await data.quote(_event, 'type-id', promoCode: ' campus20 ');
    expect(quote['discount_minor'], 20000);
    final quoteBody = jsonDecode(backend.requests.last.body);
    expect(quoteBody['promo_code'], 'CAMPUS20');
    expect(quoteBody['items'], [{'ticket_type_id': 'type-id', 'quantity': 1}]);

    await data.checkout(_event, 'type-id', promoCode: '');
    expect(jsonDecode(backend.requests.last.body)['promo_code'], isNull);

    await data.cancelCheckout('order-id');
    expect(backend.requests.last.url.path, '/api/v1/checkout/sessions/order-id/cancel');
  });

  test('rejected promo codes surface the backend message', () async {
    final backend = _backend({
      'POST /promo-codes/validate': (_) => _json({'detail': 'Promo code OLD has expired.'}, 422),
    });
    final data = DataService(backend.api, AuthService(backend.api));
    await expectLater(
      data.quote(_event, 'type-id', promoCode: 'old'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Promo code OLD has expired.')),
    );
  });

  test('check-in validates, admits and reverses with an encoded payload', () async {
    const campaignUrl = 'https://biletflow.kz/campaign/abc?x=1';
    final backend = _backend({
      'POST /check-in/events/event-id/validate': (request) => _json(
        request.url.queryParameters['qr_payload'] == campaignUrl
            ? {'result': 'invalid', 'reason': 'CAMPAIGN_QR_NOT_ADMISSION',
               'message': 'This is a promotional Campaign QR code, not an admission ticket.'}
            : {'result': 'valid', 'ticket_id': 't', 'attendee_name': 'Aida'}),
      'POST /check-in/events/event-id/admit': (_) => _json({'result': 'valid', 'record_id': 'rec', 'attendee_name': 'Aida'}),
      'POST /check-in/records/rec/reverse': (_) => _json({'status': 'reversed'}),
      'GET /check-in/events/event-id/summary': (_) => _json({'registered': 10, 'checked_in': 4, 'absent': 6}),
    });
    final data = DataService(backend.api, AuthService(backend.api));

    final campaign = await data.validateTicket('event-id', campaignUrl);
    expect(outcomeFromResult(campaign['result']), CheckinOutcome.invalid);
    expect(campaign['message'], contains('not an admission ticket'));
    expect(backend.requests.last.url.queryParameters['qr_payload'], campaignUrl);

    expect(outcomeFromResult((await data.validateTicket('event-id', 'ticket.a.b'))['result']), CheckinOutcome.valid);
    expect((await data.admit('event-id', 'ticket.a.b'))['record_id'], 'rec');
    await data.reverseCheckIn('rec');
    expect(backend.requests.last.url.path, '/api/v1/check-in/records/rec/reverse');
    final summary = await data.checkInSummary('event-id');
    expect((summary.registered, summary.checkedIn), (10, 4));
  });

  test('check-in outcomes cover every backend result', () {
    expect(outcomeFromResult('already_used'), CheckinOutcome.alreadyUsed);
    expect(outcomeFromResult('cancelled'), CheckinOutcome.cancelled);
    expect(outcomeFromResult('refunded'), CheckinOutcome.refunded);
    expect(outcomeFromResult('wrong_event'), CheckinOutcome.wrongEvent);
    expect(outcomeFromResult('something_new'), CheckinOutcome.invalid);
  });
}
