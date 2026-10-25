import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/data_service.dart';
import '../attendee/attendee_ui.dart';

class EventAttendanceScreen extends StatelessWidget {
  const EventAttendanceScreen(
      {super.key, required this.eventId, required this.eventTitle});
  final String eventId;
  final String eventTitle;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(eventTitle)),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AttendancePanel(eventId: eventId)),
      );
}

/// Shared ticket roster: statistics and manual actions always use issued tickets.
class AttendancePanel extends StatefulWidget {
  const AttendancePanel(
      {super.key,
      required this.eventId,
      this.revision = 0,
      this.enabled = true});
  final String eventId;
  final int revision;
  final bool enabled;
  @override
  State<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<AttendancePanel> {
  List<Map<String, dynamic>> _rows = [];
  String _query = '', _filter = '';
  String? _error;
  String? _busyTicket;
  bool _loading = true, _busy = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AttendancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.revision != widget.revision) {
      _load();
    }
  }

  Future<void> _load({bool preserveRows = false}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (!preserveRows) _rows = [];
    });
    try {
      final rows =
          await context.read<DataService>().eventAttendance(widget.eventId);
      if (mounted && request == _request) setState(() => _rows = rows);
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e.toString();
          _rows = [];
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _change(Map<String, dynamic> row) async {
    if (_busy || _loading || !widget.enabled) return;
    final reverse = row['status'] == 'checked_in';
    setState(() => _busy = true);
    if (reverse) {
      final confirmed = await showAdaptiveDialog<bool>(
          context: context,
          builder: (c) => AlertDialog.adaptive(
                  title: Text(c.l10n.attendanceReverse),
                  content: Text(
                      '${row['attendee_name']}\n${c.l10n.attendanceReverseConfirm}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(c.l10n.commonCancel)),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(c.l10n.attendanceReverse)),
                  ]));
      if (!mounted) return;
      if (confirmed != true) {
        setState(() {
          _busy = false;
          _busyTicket = null;
        });
        return;
      }
    }
    setState(() => _busyTicket = row['id'] as String);
    final data = context.read<DataService>();
    try {
      if (reverse) {
        await data.reverseCheckin(row['record_id'] as String);
      } else {
        await data.manualCheckin(widget.eventId, row['id'] as String);
      }
      if (mounted) await _load(preserveRows: true);
    } catch (e) {
      // Refresh even on conflict: another scanner may have just changed the ticket.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        await _load(preserveRows: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyTicket = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final expected = _rows
        .where((r) => r['status'] == 'valid' || r['status'] == 'checked_in')
        .length;
    final arrived = _rows.where((r) => r['status'] == 'checked_in').length;
    final rows = _rows
        .where((r) =>
            (_filter.isEmpty || r['status'] == _filter) &&
            ['attendee_name', 'attendee_email', 'id']
                .any((k) => '${r[k] ?? ''}'.toLowerCase().contains(_query)))
        .toList();
    final enabled = widget.enabled && !_busy && !_loading;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.organizerViewAttendees,
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      OutlinedButton.icon(
          onPressed: enabled ? _load : null,
          icon: const Icon(Icons.refresh),
          label: Text(l.attendanceRefresh)),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) ...[
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextButton(onPressed: _load, child: Text(l.commonRetry)),
      ],
      if ((!_loading || _rows.isNotEmpty) && _error == null) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _stat(context, l.attendanceExpected, '$expected'),
          _stat(context, l.attendanceCheckedIn, '$arrived'),
          _stat(context, l.attendanceAbsent, '${expected - arrived}'),
          _stat(context, l.attendanceRate,
              '${expected == 0 ? '0' : (100 * arrived / expected).toStringAsFixed(1)}%'),
        ]),
      ],
      const SizedBox(height: 20),
      TextField(
          key: const ValueKey('attendance-search'),
          decoration: InputDecoration(
              labelText: l.attendeeSearch,
              hintText: l.attendanceSearch,
              prefixIcon: const Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
          initialValue: _filter,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.attendeeOrderStatus),
          items: [
            for (final status in [
              '',
              'valid',
              'checked_in',
              'cancelled',
              'refunded'
            ])
              DropdownMenuItem(
                  value: status, child: Text(_label(context, status)))
          ],
          onChanged: (v) => setState(() => _filter = v!)),
      const SizedBox(height: 16),
      if (!_loading && _error == null && rows.isEmpty)
        Text(_rows.isEmpty ? l.attendanceEmpty : l.attendanceNoMatches),
      for (final row in rows)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: row['status'] == 'checked_in'
                    ? const Color(0xFFF0F8F2)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: row['status'] == 'checked_in'
                        ? const Color(0xFFB6DCC2)
                        : Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(row['attendee_name'] as String,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SelectableText(row['attendee_email'] as String),
                        const SizedBox(height: 8),
                        Text(row['ticket_type'] as String),
                        SelectableText('${l.attendanceTicketId}: ${row['id']}'),
                        const SizedBox(height: 8),
                        if (row['status'] != 'checked_in')
                          Text(_label(context, row['status'] as String)),
                        if (row['status'] == 'checked_in') ...[
                          const SizedBox(height: 8),
                          Semantics(
                              liveRegion: true,
                              child: Container(
                                  key: ValueKey(
                                      'attendance-success-${row['id']}'),
                                  constraints:
                                      const BoxConstraints(minHeight: 50),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFDCEFE2),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    const Icon(Icons.check_circle,
                                        color: Color(0xFF176B3A)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(l.attendanceCheckedIn,
                                            style: const TextStyle(
                                                color: Color(0xFF176B3A),
                                                fontWeight: FontWeight.w600)))
                                  ]))),
                        ],
                        if (row['status'] == 'valid' ||
                            (row['status'] == 'checked_in' &&
                                row['record_id'] != null)) ...[
                          const SizedBox(height: 12),
                          if (row['status'] == 'checked_in')
                            TextButton.icon(
                                key: ValueKey('attendance-action-${row['id']}'),
                                style: TextButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50)),
                                onPressed: enabled ? () => _change(row) : null,
                                icon: _busyTicket == row['id']
                                    ? _spinner()
                                    : const Icon(Icons.undo),
                                label: Text(_busyTicket == row['id']
                                    ? l.attendanceReversing
                                    : l.attendanceReverse)),
                          if (row['status'] == 'valid')
                            FilledButton.icon(
                                key: ValueKey('attendance-action-${row['id']}'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFB73430),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(50),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                onPressed: enabled ? () => _change(row) : null,
                                icon: _busyTicket == row['id']
                                    ? _spinner()
                                    : const Icon(Icons.person_add_alt_1),
                                label: Text(_busyTicket == row['id']
                                    ? l.attendanceAdmitting
                                    : l.attendanceAdmit)),
                        ],
                      ])),
            )),
    ]);
  }

  Widget _spinner() => const SizedBox(
      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));

  String _label(BuildContext c, String status) => switch (status) {
        '' => c.l10n.attendanceAll,
        'valid' => c.l10n.attendanceAbsent,
        'checked_in' => c.l10n.attendanceCheckedIn,
        _ => statusLabel(c, status),
      };
  Widget _stat(BuildContext c, String label, String value) => SizedBox(
      width: 145,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(c).textTheme.headlineSmall),
                    Text(label)
                  ]))));
}
