import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen(
      {super.key, this.caseId, this.subject, this.eventId, this.orderId});
  final String? caseId, subject, eventId, orderId;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController(), _message = TextEditingController();
  List<dynamic> _rows = [];
  bool _loading = true, _busy = false, _creating = false;
  String? _error;
  String _category = 'ticket_delivery';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = widget.caseId == null
          ? '/support/cases'
          : '/support/cases/${widget.caseId}/messages';
      final rows =
          await context.read<AuthService>().api.request('GET', path) as List;
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<AuthService>().api;
      if (widget.caseId != null) {
        await api.request('POST', '/support/cases/${widget.caseId}/messages',
            body: {'body': _message.text.trim()});
      } else {
        await api.request('POST', '/support/cases', body: {
          'subject': _subject.text.trim(),
          'category': _category,
          'message': _message.text.trim(),
          if (widget.eventId != null) 'event_id': widget.eventId,
          if (widget.orderId != null) 'order_id': widget.orderId
        });
      }
      if (!mounted) return;
      _message.clear();
      _subject.clear();
      setState(() => _creating = false);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final own = context.read<AuthService>().currentUser?.id;
    return Scaffold(
        appBar: AppBar(title: Text(widget.subject ?? l.profileContactUs)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_error != null) ...[
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        TextButton(
                            onPressed: _busy ? null : _load,
                            child: Text(l.commonRetry))
                      ],
                      if (widget.caseId == null) ...[
                        if (!_creating)
                          FilledButton.icon(
                              onPressed: () => setState(() => _creating = true),
                              icon: const Icon(Icons.add),
                              label: Text(l.supportNew)),
                        if (_rows.isEmpty && !_creating)
                          Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(l.supportEmpty)),
                        for (final row in _rows)
                          Card(
                              child: ListTile(
                                  title: Text(row['subject']),
                                  subtitle: Text((row['status'] as String)
                                      .replaceAll('_', ' ')),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => SupportScreen(
                                              caseId: row['id'],
                                              subject: row['subject']))))),
                      ] else
                        for (final row in _rows)
                          Align(
                              alignment: row['sender_id'] == own
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(row['body'])))),
                      if (widget.caseId != null || _creating)
                        Form(
                            key: _form,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 20),
                                  if (widget.caseId == null) ...[
                                    TextFormField(
                                        controller: _subject,
                                        enabled: !_busy,
                                        maxLength: 200,
                                        decoration: InputDecoration(
                                            labelText: l.supportSubject),
                                        validator: (v) =>
                                            (v ?? '').trim().length < 3
                                                ? l.applicationInvalid
                                                : null),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                        initialValue: _category,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: l.supportCategory),
                                        items: [
                                          for (final item in [
                                            (
                                              'ticket_delivery',
                                              l.supportTicket
                                            ),
                                            ('payment', l.supportPayment),
                                            ('refund', l.supportRefund),
                                            ('account', l.supportAccount),
                                            ('technical', l.supportTechnical)
                                          ])
                                            DropdownMenuItem(
                                                value: item.$1,
                                                child: Text(item.$2))
                                        ],
                                        onChanged: _busy
                                            ? null
                                            : (v) =>
                                                setState(() => _category = v!)),
                                  ],
                                  const SizedBox(height: 16),
                                  TextFormField(
                                      controller: _message,
                                      enabled: !_busy,
                                      maxLength: 10000,
                                      minLines: 3,
                                      maxLines: 6,
                                      decoration: InputDecoration(
                                          labelText: l.supportMessage),
                                      validator: (v) => (v ?? '').trim().isEmpty
                                          ? l.applicationInvalid
                                          : null),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                      onPressed: _busy ? null : _send,
                                      child: Text(_busy
                                          ? l.commonLoading
                                          : l.supportSend)),
                                  if (widget.caseId == null)
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => setState(
                                                () => _creating = false),
                                        child: Text(l.commonCancel)),
                                ])),
                    ])));
  }
}
