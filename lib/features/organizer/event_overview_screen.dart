import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../services/auth_service.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../models/event_creation.dart' show kazakhstanWallTime;
import '../../shared/widgets/outlined_app_button.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/event_status_badge.dart';
import '../../shared/widgets/responsive_cards.dart';
import 'checkin_screen.dart';
import 'event_management_screen.dart';
import 'management_confirmation.dart';
import 'assign_staff_dialog.dart';
import 'event_attendance_screen.dart';
import 'create_event_screen.dart';
import 'event_information_widgets.dart';
import 'ticket_inventory_screen.dart';
import '../operations/invitations_screen.dart';

class EventOverviewScreen extends StatefulWidget {
  final AppEvent event;
  const EventOverviewScreen({super.key, required this.event});

  @override
  State<EventOverviewScreen> createState() => _EventOverviewScreenState();
}

class _EventOverviewScreenState extends State<EventOverviewScreen> {
  AppEvent? _updatedEvent;
  bool _cancelling = false;
  AppEvent get event => _updatedEvent ?? widget.event;

  Future<void> _duplicate() async {
    final reason = await managementReason(context,
        context.l10n.managementDuplicate, context.l10n.managementDuplicateHelp,
        requireReason: false);
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final result = await context
          .read<DataService>()
          .api
          .request('POST', '/events/${event.id}/duplicate');
      if (!mounted) return;
      await context.read<DataService>().refresh();
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  CreateEventScreen(draftId: result['id'] as String)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _editEvent() async {
    if (_cancelling) return;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: Text(l.organizerEditEvent),
                content: Text(l.organizerUnpublishForEdit),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l.commonCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(l.organizerEditEvent))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await context.read<DataService>().unpublishEvent(event.id);
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => CreateEventScreen(draftId: event.id)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _cancelEvent() async {
    if (_cancelling) return;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l.organizerCancelEvent),
        content: Text(l.organizerCancelEventConfirm(event.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.commonCancel)),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.organizerCancelEvent)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final updated = await context.read<DataService>().cancelEvent(event.id);
      if (!mounted) return;
      setState(() => _updatedEvent = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.eventCancelled)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final event = context
            .watch<DataService>()
            .events
            .where((e) => e.id == this.event.id)
            .firstOrNull ??
        this.event;
    final currentUser = context.watch<AuthService>().currentUser;
    final cancelled = event.eventStatus == 'cancelled';
    final canCancel =
        context.watch<AuthService>().currentUser?.isOrganizer == true &&
            !cancelled &&
            event.eventStatus != 'suspended' &&
            event.eventStatus != 'completed';
    final dateFormat = DateFormat('EEE, d MMM yyyy · HH:mm',
        Localizations.localeOf(context).languageCode);
    // Keep the overview consistent with the editor, regardless of device timezone.
    final inKazakhstan = event.timeZone == 'Asia/Almaty';
    String scheduleDate(DateTime date) => dateFormat
        .format(inKazakhstan ? kazakhstanWallTime(date) : date.toUtc());
    final dateLabel = scheduleDate(event.date);

    return Scaffold(
      backgroundColor: AppColors.caseBackground,
      appBar: AppBar(title: Text(event.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EventInfoSection(
                            title: event.category.localizedLabel(l10n),
                            icon: event.icon,
                            highlight: true,
                            children: [
                              if (event.imageUrl?.isNotEmpty == true)
                                EventCover(url: event.imageUrl!),
                              Text(event.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: EventStatusBadge(
                                      status: event.eventStatus)),
                              const SizedBox(height: 12),
                              Text(dateLabel,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text('${event.venue}, ${event.city}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary)),
                            ]),
                        ResponsiveCards(children: [
                          StatCard(
                              label: l10n.organizerTicketSales,
                              value: l10n.organizerSoldOf(
                                  event.ticketsSold, event.ticketsTotal),
                              icon: Icons.confirmation_number_rounded),
                          StatCard(
                              label: l10n.organizerRevenue,
                              value:
                                  '${context.watch<DataService>().eventRevenue(event.id).toStringAsFixed(0)} ₸',
                              icon: Icons.payments_rounded,
                              color: AppColors.primaryInk),
                        ]),
                        const SizedBox(height: 24),
                        EventInfoSection(
                            title: l10n.eventManageSection,
                            icon: Icons.tune_outlined,
                            children: [
                              if (!cancelled &&
                                  event.eventStatus != 'suspended')
                                PrimaryButton(
                                  label: l10n.organizerCheckinTitle,
                                  icon: Icons.qr_code_scanner_rounded,
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            CheckinScreen(event: event)),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              if (!cancelled &&
                                  event.eventStatus != 'suspended')
                                OutlinedAppButton(
                                  label: l10n.organizerAssignStaff,
                                  icon: Icons.person_add_alt_outlined,
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => AssignStaffDialog(
                                        event: event,
                                        data: context.read<DataService>()),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              OutlinedAppButton(
                                label: l10n.organizerViewAttendees,
                                icon: Icons.groups_outlined,
                                onPressed: () => _showAttendees(context),
                              ),
                              if (currentUser?.isOrganizer == true ||
                                  currentUser?.isAdmin == true) ...[
                                const SizedBox(height: 12),
                                OutlinedAppButton(
                                    label: l10n.opsTickets,
                                    icon: Icons.confirmation_number_outlined,
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                TicketInventoryScreen(
                                                    eventId: event.id,
                                                    title: event.title)))),
                                if (event.visibility == 'private') ...[
                                  const SizedBox(height: 12),
                                  OutlinedAppButton(
                                      label: l10n.opsInvitations,
                                      icon: Icons.lock_outline,
                                      onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => InvitationsScreen(
                                                  eventId: event.id,
                                                  title: event.title)))),
                                ],
                              ],
                              if (currentUser?.isOrganizer == true ||
                                  currentUser?.isAdmin == true) ...[
                                const SizedBox(height: 12),
                                OutlinedAppButton(
                                    label: l10n.managementTitle,
                                    icon: Icons.insights_outlined,
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                EventManagementScreen(
                                                    eventId: event.id,
                                                    title: event.title)))),
                              ],
                              if (currentUser?.isOrganizer == true) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                    onPressed: _cancelling ? null : _duplicate,
                                    icon: const Icon(Icons.copy_outlined),
                                    label: Text(l10n.managementDuplicate)),
                              ],
                              if (cancelled) ...[
                                const SizedBox(height: 20),
                                Text(l10n.organizerCancelledEventHelp,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                              ],
                              if (canCancel) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                    onPressed: _cancelling ? null : _editEvent,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: Text(l10n.organizerEditEvent)),
                              ],
                              if (canCancel) ...[
                                const SizedBox(height: 28),
                                const Divider(),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _cancelling ? null : _cancelEvent,
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                          color: AppColors.error)),
                                  icon: _cancelling
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.event_busy_outlined),
                                  label: Text(_cancelling
                                      ? l10n.commonLoading
                                      : l10n.organizerCancelEvent),
                                ),
                              ],
                            ]),
                        EventInfoSection(
                            title: l10n.eventInfoSection,
                            icon: Icons.article_outlined,
                            children: [
                              Text(event.description,
                                  style: const TextStyle(height: 1.6)),
                            ]),
                        EventInfoSection(
                            title: l10n.eventScheduleSection,
                            icon: Icons.event_outlined,
                            children: [
                              Text(inKazakhstan ? l10n.creationTimezone : 'UTC',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              EventInfoRow(
                                  icon: Icons.schedule_outlined,
                                  label: l10n.creationStarts,
                                  value: dateLabel),
                              if (event.endsAt != null)
                                EventInfoRow(
                                    icon: Icons.schedule_outlined,
                                    label: l10n.creationEnds,
                                    value: scheduleDate(event.endsAt!)),
                              if (event.registrationOpensAt != null)
                                EventInfoRow(
                                    icon: Icons.how_to_reg_outlined,
                                    label: l10n.creationOpens,
                                    value: scheduleDate(
                                        event.registrationOpensAt!)),
                              if (event.registrationClosesAt != null)
                                EventInfoRow(
                                    icon: Icons.timer_outlined,
                                    label: l10n.creationCloses,
                                    value: scheduleDate(
                                        event.registrationClosesAt!)),
                            ]),
                        EventInfoSection(
                            title: l10n.eventVenueSection,
                            icon: Icons.place_outlined,
                            children: [
                              EventInfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: l10n.organizerVenueLabel,
                                  value: [
                                    event.venue,
                                    event.address,
                                    event.city
                                  ].where((v) => v.isNotEmpty).join('\n')),
                            ]),
                        EventInfoSection(
                            title: l10n.creationVisibility,
                            icon: Icons.groups_outlined,
                            children: [
                              EventInfoRow(
                                  icon: Icons.visibility_outlined,
                                  label: l10n.creationVisibility,
                                  value: switch (event.visibility) {
                                    'unlisted' => l10n.creationUnlisted,
                                    'private' => l10n.creationPrivate,
                                    _ => l10n.creationPublic
                                  }),
                            ]),
                        if (event.refundPolicy.isNotEmpty)
                          EventInfoSection(
                              title: l10n.refundPolicy,
                              icon: Icons.policy_outlined,
                              children: [
                                Text(event.refundPolicy,
                                    style: const TextStyle(height: 1.6))
                              ]),
                      ])))
        ],
      ),
    );
  }

  void _showAttendees(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EventAttendanceScreen(
                eventId: event.id, eventTitle: event.title)));
  }
}
