import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/profile/support_screen.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'event_attendees_test.dart' as fixtures;

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'case conversation and reply fit a narrow phone at text scale $scale',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final api = ApiClient(client: MockClient((r) async {
        if (r.url.path.endsWith('/history')) return http.Response('[]', 200);
        if (r.url.path.endsWith('/messages')) {
          return http.Response(
              jsonEncode([
                {
                  'sender_id': 'staff',
                  'sender_name': 'Demo Support Staff',
                  'body':
                      'We are checking your ticket email. You can access your ticket in My Tickets.',
                  'created_at': '2026-10-26T09:00:00Z'
                },
                {
                  'sender_id': 'user-id',
                  'sender_name': 'Demo Attendee',
                  'body': 'Thank you, I found my ticket.',
                  'created_at': '2026-10-26T09:05:00Z'
                },
              ]),
              200);
        }
        return http.Response(
            jsonEncode({
              'id': 'demo',
              'number': 'BF-DEMO',
              'subject': 'Ticket email has not arrived',
              'status': 'in_progress',
              'flow': 'attendee',
              'category': 'ticket_delivery',
              'assignee_name': 'Demo Support Staff',
              'event_title': 'Almaty Jazz Night',
              'order_id': '12345678-abcd-1234-abcd-123456789012',
              'can_manage': false,
              'can_refund': false
            }),
            200);
      }));
      await tester.pumpWidget(fixtures.app(
          api,
          UserRole.attendee,
          MediaQuery(
              data: MediaQueryData(
                  size: const Size(390, 844),
                  textScaler: TextScaler.linear(scale)),
              child: const SupportScreen(caseId: 'demo', view: 'mine'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
          find.widgetWithText(TextFormField, 'Message'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Message'),
          'Please check the delivery address.');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Send message'), findsOneWidget);
    });
    testWidgets(
        'inbox cards and filters fit a narrow phone at text scale $scale',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final api = ApiClient(
          client: MockClient((_) async => http.Response(
              jsonEncode([
                {
                  'id': 'demo',
                  'subject': 'Ticket email has not arrived',
                  'status': 'in_progress',
                  'category': 'ticket_delivery',
                  'event_title': 'Almaty Jazz Night',
                  'assigned_to': 'staff',
                  'assignee_name': 'Demo Support Staff'
                },
              ]),
              200)));
      final boundary = GlobalKey();
      await tester.pumpWidget(fixtures.app(
          api,
          UserRole.organizer,
          MediaQuery(
              data: MediaQueryData(
                  size: const Size(390, 844),
                  textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                  key: boundary, child: const SupportScreen(view: 'inbox')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scale == 1.0 && const bool.fromEnvironment('SUPPORT_PREVIEW')) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/biletflow-support-inbox.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.scrollUntilVisible(find.text('Filters'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester
          .ensureVisible(find.byKey(const ValueKey('support-status-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('support-status-filter')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
