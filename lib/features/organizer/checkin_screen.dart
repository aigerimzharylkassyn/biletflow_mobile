import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';

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
  @override
  void initState() { super.initState(); _eventId = widget.event?.id; }
  @override
  void dispose() { _code.dispose(); super.dispose(); }
  Future<void> _admit() async {
    if (_busy || _eventId == null || _code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final name = await context.read<DataService>().admit(_eventId!, _code.text.trim());
      if (!mounted) return;
      _code.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checked in: $name')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final events = context.watch<DataService>().events;
    return Scaffold(
      appBar: AppBar(title: Text(widget.event?.title ?? 'Check-in')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (widget.event == null) DropdownButtonFormField<String>(
          initialValue: _eventId,
          decoration: const InputDecoration(labelText: 'Event'),
          items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _busy ? null : (value) => setState(() => _eventId = value),
        ),
        const SizedBox(height: 24),
        const Icon(Icons.qr_code_scanner, size: 100),
        const SizedBox(height: 24),
        const Text('Paste the admission credential from the attendee’s ticket. Each ticket can be admitted only once.'),
        const SizedBox(height: 16),
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'Admission credential'), minLines: 2, maxLines: 4),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _admit, child: Text(_busy ? 'Checking…' : 'Check in')),
      ]),
    );
  }
}
