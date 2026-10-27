import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../auth/email_auth_screen.dart';
import 'attendee_ui.dart';

/// Confirmation/delivery preview only; never submits an email or alters an order.
class TicketEmailPanel extends StatefulWidget {
  const TicketEmailPanel(
      {super.key,
      required this.orderId,
      required this.email,
      required this.event,
      required this.attendeeName,
      required this.totalMinor,
      required this.ticketIds});
  final String orderId, email, attendeeName;
  final AppEvent event;
  final num totalMinor;
  final List<String> ticketIds;
  @override
  State<TicketEmailPanel> createState() => _TicketEmailPanelState();
}

class _TicketEmailPanelState extends State<TicketEmailPanel> {
  bool _sent = false;
  void _preview() {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) {
          final l = sheetContext.l10n;
          return FractionallySizedBox(
              heightFactor: .88,
              child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(l.emailConfirmationTitle,
                                        style: Theme.of(sheetContext)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 16),
                                    const EmailDemoNotice(),
                                    const SizedBox(height: 20),
                                    Text(
                                        '${l.emailPreviewRecipient}: ${widget.email}',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary)),
                                    const Divider(height: 32),
                                    const Text('BiletFlow',
                                        style: TextStyle(
                                            color: AppColors.primaryInk,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 16),
                                    Text(widget.event.title,
                                        style: Theme.of(sheetContext)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 12),
                                    Text(
                                        '${DateFormat.yMMMd(Localizations.localeOf(sheetContext).languageCode).format(widget.event.date)} · ${widget.event.startTime} – ${widget.event.endTime}'),
                                    const SizedBox(height: 8),
                                    Text(
                                        '${widget.event.venue}\n${widget.event.address}\n${widget.event.city}'),
                                    const SizedBox(height: 16),
                                    Text(widget.attendeeName),
                                    const SizedBox(height: 8),
                                    Text('${l.orderLabel}: ${widget.orderId}'),
                                    const SizedBox(height: 8),
                                    Text(
                                        '${l.totalLabel}: ${money(widget.totalMinor)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const Divider(height: 32),
                                    Text(l.emailPreviewAttachments,
                                        style: Theme.of(sheetContext)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    Text(l.emailPreviewAttachmentHelp,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary)),
                                    for (final id in widget.ticketIds)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                  color:
                                                      AppColors.caseBackground,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Row(children: [
                                                const Icon(
                                                    Icons
                                                        .picture_as_pdf_outlined,
                                                    color:
                                                        AppColors.primaryInk),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                    child: Text(
                                                        'ticket-$id.pdf',
                                                        style: const TextStyle(
                                                            fontSize: 13))),
                                              ]))),
                                    const SizedBox(height: 20),
                                    OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(sheetContext),
                                        child: Text(l.commonOk)),
                                  ]))))));
        });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AttendeePanel(children: [
      Row(children: [
        const Icon(Icons.mail_outline_rounded, color: AppColors.primaryInk),
        const SizedBox(width: 10),
        Expanded(
            child: Text(l.emailDeliveryTitle,
                style: Theme.of(context).textTheme.titleMedium)),
      ]),
      const SizedBox(height: 12),
      Text(widget.email, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Text(l.emailDeliveryHelp, style: const TextStyle(height: 1.5)),
      const SizedBox(height: 12),
      Text(l.emailDemoNotice,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: _preview,
          icon: const Icon(Icons.preview_outlined),
          label: Text(l.emailPreviewAction, textAlign: TextAlign.center)),
      const SizedBox(height: 8),
      TextButton.icon(
          onPressed: _sent ? null : () => setState(() => _sent = true),
          icon: const Icon(Icons.send_outlined),
          label: Text(l.emailSimulateSend, textAlign: TextAlign.center)),
      if (_sent) ...[
        const SizedBox(height: 8),
        Semantics(
            liveRegion: true,
            child: Text(l.emailDemoSent,
                style: const TextStyle(color: AppColors.primaryInk))),
      ],
    ]);
  }
}
