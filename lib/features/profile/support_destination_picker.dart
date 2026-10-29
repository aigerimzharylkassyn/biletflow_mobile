import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';

/// Select context, never a recipient ID: the server owns support routing.
class SupportDestinationPicker extends StatefulWidget {
  const SupportDestinationPicker({super.key, required this.onChanged});
  final void Function(String? eventId, String? orderId) onChanged;
  @override
  State<SupportDestinationPicker> createState() =>
      _SupportDestinationPickerState();
}

class _SupportDestinationPickerState extends State<SupportDestinationPicker> {
  String? _destination, _selection, _error;
  bool _loading = true;
  List<Map<String, dynamic>> _events = [], _orders = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthService>().api;
      final result = await Future.wait([
        api.request('GET', '/events'),
        api.request('GET', '/orders'),
      ]);
      if (!mounted) return;
      setState(() {
        _events = (result[0] as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        _orders = (result[1] as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final titles = {
      for (final e in _events) e['id'] as String: e['title'] as String
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(
          key: const ValueKey('support-destination'),
          initialValue: _destination,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.supportWhoToContact),
          items: [
            DropdownMenuItem(value: 'event', child: Text(l.supportEventHelp)),
            DropdownMenuItem(
                value: 'general', child: Text(l.supportGeneralHelp)),
          ],
          validator: (v) => v == null ? l.supportChooseDestination : null,
          onChanged: (v) {
            setState(() {
              _destination = v;
              _selection = null;
            });
            widget.onChanged(null, null);
          }),
      if (_destination == 'event') ...[
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(color: AppColors.primary),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          TextButton(onPressed: _load, child: Text(l.commonRetry)),
        ],
        DropdownButtonFormField<String>(
            key: ValueKey('support-context-$_destination'),
            initialValue: _selection,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.supportChooseEventBooking),
            items: [
              for (final o in _orders)
                DropdownMenuItem(
                    value: 'order:${o['id']}',
                    child: Text(
                        '${titles[o['event_id']] ?? l.orderLabel} · ${l.orderLabel} #${(o['id'] as String).substring(0, (o['id'] as String).length.clamp(0, 8))}',
                        overflow: TextOverflow.ellipsis)),
              for (final e in _events)
                DropdownMenuItem(
                    value: 'event:${e['id']}',
                    child: Text(e['title'] as String,
                        overflow: TextOverflow.ellipsis)),
            ],
            validator: (v) => _destination == 'event' &&
                    (v == null || _loading || _error != null)
                ? l.supportChooseEventBooking
                : null,
            onChanged: _loading || _error != null
                ? null
                : (v) {
                    setState(() => _selection = v);
                    if (v!.startsWith('order:')) {
                      final order =
                          _orders.firstWhere((o) => 'order:${o['id']}' == v);
                      widget.onChanged(
                          order['event_id'] as String, order['id'] as String);
                    } else {
                      widget.onChanged(v.substring(6), null);
                    }
                  }),
        if (!_loading && _error == null && _events.isEmpty && _orders.isEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.supportNoEventBookings)),
      ],
      if (_destination != null) ...[
        const SizedBox(height: 12),
        Text(
            _destination == 'general'
                ? l.supportSentToPlatform
                : l.supportSentToOrganizer,
            style: const TextStyle(color: AppColors.primaryInk)),
      ],
      const SizedBox(height: 16),
    ]);
  }
}
