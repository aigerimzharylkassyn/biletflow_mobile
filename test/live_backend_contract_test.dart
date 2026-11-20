import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';

/// Opt in only against scripts/run_mobile_contract_backend.py, never a real DB.
void main() {
  test(
      'mobile HTTP contracts complete campaign purchase, email, moderation and admission',
      () async {
    final base = Uri.parse(ApiClient.baseUrl);
    expect(base.host, '127.0.0.1');
    expect(base.port, 18001);
    Future<ApiClient> login(String name) async {
      final api = ApiClient();
      final auth = AuthService(api);
      expect(
          await auth.login(
              email: 'mobile.qa.$name@example.com', password: 'MobileQa123!'),
          isTrue,
          reason: auth.errorMessage);
      return api;
    }

    final admin = await login('admin');
    final organizer = await login('organizer');
    final staff = await login('staff');
    final buyer = ApiClient();
    final email =
        'mobile.qa.buyer.${DateTime.now().microsecondsSinceEpoch}@example.com';
    final registered = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': 'MobileQa123!',
          'full_name': 'Mobile QA Buyer'
        }));
    expect(registered.statusCode, 201);
    final verification = registered.headers['x-demo-verification-token'];
    expect(verification, isNotNull);
    expect(
        (await buyer.request('POST', '/auth/verify-email',
            body: {'token': verification}))['email_verified'],
        isTrue);
    final auth = AuthService(buyer);
    expect(await auth.login(email: email, password: 'MobileQa123!'), isTrue);
    final data = DataService(buyer, auth);
    addTearDown(data.dispose);
    addTearDown(auth.dispose);
    final now = DateTime.now().toUtc();
    final start = now.add(const Duration(days: 3));
    final event = await organizer.request('POST', '/events', body: {
      'title': 'Mobile contract event',
      'description': 'Disposable integration fixture',
      'category': 'music',
      'venue': {'name': 'QA Hall', 'address': '1 QA Street', 'city': 'Almaty'},
      'starts_at': start.toIso8601String(),
      'ends_at': start.add(const Duration(hours: 2)).toIso8601String(),
      'registration_opens_at':
          now.subtract(const Duration(hours: 1)).toIso8601String(),
      'registration_closes_at': start.toIso8601String(),
      'capacity': 100,
      'refund_policy': 'Contact the organizer before the event.',
    });
    final id = event['id'] as String;
    final ticket =
        await organizer.request('POST', '/events/$id/ticket-types', body: {
      'name': 'Standard',
      'kind': 'paid',
      'price_minor': 100000,
      'quantity': 20,
      'max_per_order': 5,
      'sales_start': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'sales_end': now.add(const Duration(days: 2)).toIso8601String(),
    });
    final type = ticket['id'] as String;
    await organizer.request('PUT', '/organizer-profile',
        body: {'contact_name': 'Mobile QA Organizer'});
    await organizer.request('POST', '/organizer-profile/verification/submit');
    await organizer.request('PUT',
        '/organizer-profile/payout-account?account_reference=KZ-QA-123456');
    for (final step in ['accept-terms', 'activation-fee', 'apply']) {
      await organizer.request('POST', '/events/$id/paid-sales/$step');
    }
    await admin.request('POST', '/admin/paid-event-applications/$id/approve',
        body: {});
    await organizer.request('POST', '/events/$id/paid-sales/activate');
    await organizer.request('POST', '/events/$id/publish');
    final campaign =
        await organizer.request('POST', '/events/$id/campaigns', body: {
      'name': 'Mobile offer',
      'code': 'M${DateTime.now().microsecondsSinceEpoch}',
      'discount_type': 'percentage',
      'discount_value': 50,
      'valid_from': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      'valid_until': now.add(const Duration(days: 1)).toIso8601String(),
      'max_redemptions': 10,
      'applicable_ticket_type_ids': [type],
    });
    final resolved = await buyer.request(
        'GET', '/campaigns/resolve/${campaign['opaque_token']}');
    expect(resolved['state'], 'active');
    final code = resolved['promo_code'] as String;
    final items = [
      {'ticket_type_id': type, 'quantity': 1}
    ];
    final quote = await data.quote(id, items, code);
    expect(quote['discount_minor'], 50000);
    final reservation = await data.reserveTickets(id, items,
        name: 'Mobile QA Buyer',
        email: email,
        key: 'mobile-qa-checkout',
        promo: code);
    final order = await data.confirmReservation(
        reservation['id'] as String, 'mobile-qa-confirm');
    expect(order['status'], 'confirmed');
    final orderId = order['id'] as String;
    await buyer.request('POST', '/orders/$orderId/resend-confirmation');
    final tickets = await buyer.request('GET', '/tickets') as List;
    final issued = tickets.single as Map;
    final pdf = await buyer.download('/tickets/${issued['id']}/pdf');
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    final qr =
        await organizer.download('/events/$id/campaigns/${campaign['id']}/qr');
    expect(qr.take(4).toList(), [137, 80, 78, 71]);
    await organizer.request('PATCH', '/events/$id/campaigns/${campaign['id']}',
        body: {'enabled': false});
    expect(
        (await buyer.request('GET',
            '/campaigns/resolve/${campaign['opaque_token']}'))['promo_code'],
        isNull);
    await organizer.request('PATCH', '/events/$id/campaigns/${campaign['id']}',
        body: {'enabled': true});
    final analytics = await organizer.request(
        'GET', '/organizer/analytics/campaigns?event_id=$id') as List;
    expect(analytics.single['orders'], 1);
    expect(analytics.single['discount_minor'], 50000);
    final report = await buyer.request('POST', '/events/$id/reports',
        body: {'reason': 'QA moderation review'});
    await admin.request('GET', '/admin/event-reports');
    await admin.request('PATCH', '/admin/event-reports/${report['id']}',
        body: {'status': 'resolved', 'resolution': 'QA event details checked'});
    expect(
        (await buyer.request('GET', '/reports/mine') as List).single['status'],
        'resolved');
    expect((await buyer.request('GET', '/events/$id'))['status'], 'published');
    final dispute = await buyer.request('POST', '/orders/$orderId/disputes',
        body: {'reason': 'QA payment review'});
    await admin.request('GET', '/admin/disputes');
    await admin.request('PATCH', '/admin/disputes/${dispute['id']}',
        body: {'status': 'resolved', 'resolution': 'QA payment verified'});
    expect(
        (await buyer.request('GET', '/disputes/mine') as List).single['status'],
        'resolved');
    expect((await data.orderDetails(orderId))['status'], 'confirmed');
    await organizer.request(
        'POST', '/events/$id/staff?email=mobile.qa.staff%40example.com');
    expect(
        (await staff.request('GET', '/check-in/events') as List)
            .any((e) => e['id'] == id),
        isTrue);
    final staffData = DataService(staff, AuthService(staff));
    addTearDown(staffData.dispose);
    await staffData.admit(id, issued['qr_credential'] as String);
    await expectLater(staffData.admit(id, issued['qr_credential'] as String),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)));
    await expectLater(staffData.admit(id, campaign['campaign_url'] as String),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)));
    final reset = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}));
    final resetToken = reset.headers['x-demo-reset-token'];
    expect(resetToken, isNotNull);
    await buyer.request('POST', '/auth/reset-password',
        body: {'token': resetToken, 'password': 'ChangedQa123!'});
    auth.logout();
    expect(await auth.login(email: email, password: 'ChangedQa123!'), isTrue);
    await expectLater(
        buyer.request('POST', '/auth/reset-password',
            body: {'token': resetToken, 'password': 'ChangedAgain123!'}),
        throwsA(isA<ApiException>()));
  },
      skip: !const bool.fromEnvironment('RUN_LIVE_API_TESTS'),
      timeout: const Timeout(Duration(minutes: 2)));
}
