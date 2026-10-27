import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';

String money(num minor) => '${NumberFormat('#,##0.##').format(minor / 100)} ₸';
String statusLabel(BuildContext context, String status) {
  final l = context.l10n;
  return switch (status) {
    'valid' => l.statusValid,
    'checked_in' => l.statusCheckedIn,
    'cancelled' => l.statusCancelled,
    'refunded' => l.statusRefunded,
    'confirmed' || 'succeeded' => l.statusConfirmed,
    'pending' => l.statusPending,
    'expired' => l.statusExpired,
    'payment_failed' || 'failed' => l.statusFailed,
    'partially_refunded' => l.statusPartialRefund,
    _ => status.replaceAll('_', ' '),
  };
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = ['valid', 'confirmed'].contains(status)
        ? Colors.green
        : ['refunded', 'cancelled', 'expired', 'payment_failed']
                .contains(status)
            ? Colors.red
            : Colors.blueGrey;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(statusLabel(context, status),
            style: TextStyle(color: color, fontWeight: FontWeight.w600)));
  }
}

class AttendeePanel extends StatelessWidget {
  const AttendeePanel({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)));
}

class MoneySummary extends StatelessWidget {
  const MoneySummary({super.key, required this.order});
  final Map<String, dynamic> order;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(children: [
      for (final row in [
        (l.subtotalLabel, 'subtotal_minor'),
        (l.discountLabel, 'discount_minor'),
        (l.feeLabel, 'processing_fee_minor'),
        (l.totalLabel, 'total_minor')
      ])
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                  child: Text(row.$1,
                      style: TextStyle(
                          fontWeight: row.$2 == 'total_minor'
                              ? FontWeight.bold
                              : null))),
              const SizedBox(width: 12),
              Flexible(
                  child: Text(
                      '${row.$2 == 'discount_minor' ? '−' : ''}${money(order[row.$2] as num? ?? 0)}',
                      textAlign: TextAlign.end)),
            ])),
    ]);
  }
}

Future<void> runAttendeeAction(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.requestFailed}\n$e')));
    }
  }
}

Future<void> openEventMap(AppEvent event) async {
  final uri = Uri.https('www.google.com', '/maps/search/',
      {'api': '1', 'query': '${event.venue} ${event.address} ${event.city}'});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('Unable to open maps');
  }
}

String eventCalendar(AppEvent event) {
  String escape(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll('\r', '')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');
  String date(DateTime v) =>
      DateFormat("yyyyMMdd'T'HHmmss'Z'").format(v.toUtc());
  final start = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      int.tryParse(event.startTime.split(':').first) ?? 0,
      int.tryParse(event.startTime.split(':').last) ?? 0);
  final raw = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BiletFlow//Mobile//EN',
    'BEGIN:VEVENT',
    'UID:${escape(event.id)}@biletflow.kz',
    'DTSTAMP:${date(DateTime.now())}',
    'DTSTART:${date(start)}',
    'DTEND:${date(event.endsAt ?? start.add(const Duration(hours: 2)))}',
    'SUMMARY:${escape(event.title)}',
    'DESCRIPTION:${escape(event.description)}',
    'LOCATION:${escape('${event.venue}, ${event.address}, ${event.city}')}',
    if (event.eventStatus == 'cancelled') 'STATUS:CANCELLED',
    'END:VEVENT',
    'END:VCALENDAR'
  ];
  // RFC 5545 content lines are folded at UTF-8 octet boundaries.
  final folded = <String>[];
  for (final line in raw) {
    var current = '';
    var bytes = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (bytes + size > 75) {
        folded.add(current);
        current = ' ';
        bytes = 1;
      }
      current += char;
      bytes += size;
    }
    folded.add(current);
  }
  return '${folded.join('\r\n')}\r\n';
}

Future<void> shareCalendar(BuildContext context, AppEvent event) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(Uint8List.fromList(utf8.encode(eventCalendar(event))),
            mimeType: 'text/calendar')
      ],
      fileNameOverrides: [
        'event.ics'
      ],
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size));
}

Future<void> exportTicket(ApiClient api, String ticketId) async {
  final bytes = await api.download('/tickets/$ticketId/pdf');
  await Printing.sharePdf(
      bytes: bytes, filename: 'biletflow-ticket-$ticketId.pdf');
}

class CancelledEventNotice extends StatelessWidget {
  const CancelledEventNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.event_busy_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer),
        const SizedBox(width: 12),
        Expanded(
            child: Text(context.l10n.attendeeCancelledEventHelp,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer))),
      ]));
}
