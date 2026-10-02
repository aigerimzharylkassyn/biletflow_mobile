import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';
import 'ticket_scanner_screen.dart';

class CheckinScreen extends StatefulWidget {
  final AppEvent? event;
  const CheckinScreen({super.key, this.event});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _code = TextEditingController();
  String? _eventId;
  bool _busy = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _eventId = widget.event?.id;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy || _scanning || _eventId == null) return;
    setState(() => _scanning = true);
    try {
      final credential = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const TicketScannerScreen()),
      );
      if (!mounted || credential == null) return;
      await _admit(credential);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _admit(String credential) async {
    if (_busy || _eventId == null || credential.trim().isEmpty) return;
    final l = context.l10n;
    if (!credential.trim().startsWith('ticket.')) {
      await _result(false, l.checkinInvalid);
      return;
    }
    setState(() => _busy = true);
    try {
      final name =
          await context.read<DataService>().admit(_eventId!, credential.trim());
      if (!mounted) return;
      _code.clear();
      await _result(true, l.organizerCheckinSuccess(name));
    } catch (error) {
      if (mounted) await _result(false, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _result(bool accepted, String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          icon: Icon(accepted ? Icons.check_circle : Icons.error_outline,
              color:
                  accepted ? Colors.green : Theme.of(context).colorScheme.error,
              size: 48),
          title: Text(accepted
              ? context.l10n.checkinAccepted
              : context.l10n.checkinRejected),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.checkinNext))
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final events = context.watch<DataService>().events;
    final l = context.l10n;
    final enabled = !_busy && !_scanning;
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.event?.title ?? l.organizerCheckinTitle)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (widget.event == null)
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _eventId,
            decoration: InputDecoration(labelText: l.navEvents),
            items: events
                .map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.title, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged:
                enabled ? (value) => setState(() => _eventId = value) : null,
          ),
        const SizedBox(height: 24),
        const Icon(Icons.qr_code_scanner, size: 100),
        const SizedBox(height: 16),
        Text(
            _eventId == null
                ? l.checkinSelectEvent
                : l.organizerScanInstruction,
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: enabled && _eventId != null ? _scan : null,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(_busy ? l.checkinBusy : l.checkinScan),
        ),
        const SizedBox(height: 32),
        Text(l.checkinManualHelp),
        const SizedBox(height: 16),
        TextField(
            controller: _code,
            enabled: enabled,
            decoration: InputDecoration(labelText: l.checkinCredential),
            minLines: 2,
            maxLines: 4),
        const SizedBox(height: 16),
        OutlinedButton(
            onPressed:
                enabled && _eventId != null ? () => _admit(_code.text) : null,
            child: Text(_busy ? l.checkinBusy : l.checkinSubmit)),
      ]),
    );
  }
}
