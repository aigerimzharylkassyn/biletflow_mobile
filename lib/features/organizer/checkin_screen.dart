import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';

enum CheckinOutcome { valid, alreadyUsed, cancelled, refunded, wrongEvent, invalid, admitted }

/// Maps the backend's validate `result` field; unknown values are treated as invalid.
CheckinOutcome outcomeFromResult(String? result) => switch (result) {
  'valid' => CheckinOutcome.valid,
  'already_used' => CheckinOutcome.alreadyUsed,
  'cancelled' => CheckinOutcome.cancelled,
  'refunded' => CheckinOutcome.refunded,
  'wrong_event' => CheckinOutcome.wrongEvent,
  _ => CheckinOutcome.invalid,
};

class _CheckinResult {
  final CheckinOutcome outcome;
  final String credential;
  final String? detail;
  final String? recordId;
  const _CheckinResult(this.outcome, this.credential, {this.detail, this.recordId});
}

class CheckinScreen extends StatefulWidget {
  final AppEvent? event;
  const CheckinScreen({super.key, this.event});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  static const _repeatScanWindow = Duration(seconds: 3);
  final _code = TextEditingController();
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  String? _eventId;
  bool _busy = false;
  _CheckinResult? _result;
  ({int registered, int checkedIn})? _summary;
  String? _lastCode;
  DateTime _lastCodeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _eventId = widget.event?.id;
    _loadSummary();
  }

  @override
  void dispose() {
    _code.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final eventId = _eventId;
    if (eventId == null) return;
    try {
      final summary = await context.read<DataService>().checkInSummary(eventId);
      if (mounted && eventId == _eventId) setState(() => _summary = summary);
    } catch (_) {
      // Counts are informational; scanning keeps working without them.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (value == null || _busy || _result != null) return;
    // The same physical ticket often stays in view; ignore it briefly after a result is dismissed.
    final now = DateTime.now();
    if (value == _lastCode && now.difference(_lastCodeAt) < _repeatScanWindow) return;
    _lastCode = value;
    _lastCodeAt = now;
    _check(value);
  }

  Future<void> _run(Future<void> Function(DataService data) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(context.read<DataService>());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check(String credential) => _run((data) async {
    if (_eventId == null || credential.trim().isEmpty) return;
    final response = await data.validateTicket(_eventId!, credential.trim());
    if (!mounted) return;
    setState(() => _result = _CheckinResult(
      outcomeFromResult(response['result'] as String?),
      credential.trim(),
      detail: (response['attendee_name'] ?? response['message']) as String?,
    ));
  });

  Future<void> _admit() => _run((data) async {
    final current = _result!;
    final response = await data.admit(_eventId!, current.credential);
    if (!mounted) return;
    _code.clear();
    setState(() => _result = _CheckinResult(
      CheckinOutcome.admitted,
      current.credential,
      detail: response['attendee_name'] as String?,
      recordId: response['record_id'] as String?,
    ));
    await _loadSummary();
  });

  Future<void> _undo() => _run((data) async {
    final current = _result!;
    await data.reverseCheckIn(current.recordId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.checkinUndone)));
    setState(() => _result = _CheckinResult(CheckinOutcome.valid, current.credential, detail: current.detail));
    await _loadSummary();
  });

  void _scanNext() {
    _lastCodeAt = DateTime.now();
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final events = context.watch<DataService>().events;
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(title: Text(widget.event?.title ?? l10n.navCheckin)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.event == null) ...[
          DropdownButtonFormField<String>(
            initialValue: _eventId,
            decoration: InputDecoration(labelText: l10n.checkinEventLabel),
            items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _busy ? null : (value) {
              setState(() { _eventId = value; _result = null; _summary = null; });
              _loadSummary();
            },
          ),
          const SizedBox(height: 16),
        ],
        if (summary != null)
          Row(children: [
            Expanded(child: _Count(label: l10n.checkinRegistered, value: summary.registered)),
            const SizedBox(width: 12),
            Expanded(child: _Count(label: l10n.checkinCheckedIn, value: summary.checkedIn)),
          ]),
        const SizedBox(height: 16),
        if (_eventId == null)
          Text(l10n.checkinChooseEvent, style: const TextStyle(color: AppColors.textSecondary))
        else ...[
          if (_result == null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: AspectRatio(
                aspectRatio: 1,
                child: MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraError(
                    message: error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? l10n.checkinCameraDenied
                        : l10n.checkinCameraUnavailable,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.checkinScanHint, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          ] else
            _ResultPanel(
              result: _result!,
              busy: _busy,
              onAdmit: _admit,
              onUndo: _result!.recordId == null ? null : _undo,
              onNext: _scanNext,
            ),
          const SizedBox(height: 24),
          Text(l10n.checkinManualHint, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            decoration: InputDecoration(labelText: l10n.checkinManualLabel),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _check(_code.text),
            child: Text(l10n.checkinManualCheck),
          ),
        ],
      ]),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  const _Count({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _CameraError extends StatelessWidget {
  final String message;
  const _CameraError({required this.message});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.no_photography_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}

/// Full-width verdict that uses colour, icon and text together so it is readable at a glance.
class _ResultPanel extends StatelessWidget {
  final _CheckinResult result;
  final bool busy;
  final VoidCallback onAdmit;
  final VoidCallback? onUndo;
  final VoidCallback onNext;
  const _ResultPanel({required this.result, required this.busy, required this.onAdmit, required this.onUndo, required this.onNext});

  static (Color, IconData, String) _style(CheckinOutcome outcome, AppLocalizations l10n) => switch (outcome) {
    CheckinOutcome.valid => (AppColors.success, Icons.check_circle_rounded, l10n.checkinResultValid),
    CheckinOutcome.admitted => (AppColors.success, Icons.how_to_reg_rounded, l10n.checkinCheckedIn),
    CheckinOutcome.alreadyUsed => (AppColors.warning, Icons.history_rounded, l10n.checkinResultAlreadyUsed),
    CheckinOutcome.cancelled => (AppColors.error, Icons.block_rounded, l10n.checkinResultCancelled),
    CheckinOutcome.refunded => (AppColors.error, Icons.money_off_rounded, l10n.checkinResultRefunded),
    CheckinOutcome.wrongEvent => (AppColors.error, Icons.event_busy_rounded, l10n.checkinResultWrongEvent),
    CheckinOutcome.invalid => (AppColors.error, Icons.gpp_bad_rounded, l10n.checkinResultInvalid),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (color, icon, title) = _style(result.outcome, l10n);
    final detail = result.outcome == CheckinOutcome.admitted && result.detail != null
        ? l10n.checkinAdmitted(result.detail!)
        : result.detail;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 72),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ],
          const SizedBox(height: 16),
          if (result.outcome == CheckinOutcome.valid)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: busy ? null : onAdmit,
                icon: const Icon(Icons.login_rounded),
                label: Text(l10n.checkinAdmit),
              ),
            ),
          if (onUndo != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onUndo,
                icon: const Icon(Icons.undo_rounded),
                label: Text(l10n.checkinUndo),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: busy ? null : onNext, child: Text(l10n.checkinScanNext)),
          ),
        ]),
      ),
    );
  }
}
