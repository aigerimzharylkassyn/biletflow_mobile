import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController();
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row =
          await context.read<AuthService>().api.request('GET', '/users/me');
      if (!mounted) return;
      _name.text = row['full_name'] ?? '';
      _phone.text = row['phone'] ?? '';
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.api.request('PATCH', '/users/me', body: {
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim()
      });
      await auth.refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.profileSaved)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        appBar: AppBar(title: Text(l.profileEdit)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(20), children: [
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                      onPressed: _busy ? null : _load,
                      child: Text(l.commonRetry))
                ],
                Form(
                    key: _form,
                    child: Column(children: [
                      TextFormField(
                          controller: _name,
                          maxLength: 200,
                          enabled: !_busy,
                          decoration:
                              InputDecoration(labelText: l.authNameLabel),
                          validator: (v) => (v ?? '').trim().length < 2
                              ? l.authValidationNameRequired
                              : null),
                      const SizedBox(height: 20),
                      TextFormField(
                          controller: _phone,
                          maxLength: 40,
                          enabled: !_busy,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(labelText: l.phoneLabel)),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: _busy ? null : _save,
                          child: Text(_busy ? l.commonLoading : l.commonSave)),
                    ])),
              ]));
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error, _busy;
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
      final rows = await context
          .read<AuthService>()
          .api
          .request('GET', '/notifications') as List;
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(String id) async {
    if (_busy != null) return;
    setState(() => _busy = id);
    try {
      await context
          .read<AuthService>()
          .api
          .request('POST', '/notifications/$id/read');
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        appBar: AppBar(title: Text(l.profileNotifications)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_error != null) ...[
                        Text(_error!),
                        TextButton(onPressed: _load, child: Text(l.commonRetry))
                      ],
                      if (_rows.isEmpty) Text(l.notificationsEmpty),
                      for (final row in _rows)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(row['title'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 8),
                                      Text(row['message']),
                                      if (row['is_read'] != true)
                                        TextButton(
                                            onPressed: _busy != null
                                                ? null
                                                : () => _read(row['id']),
                                            child: Text(l.markRead)),
                                    ]))),
                    ])));
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.policy});
  final String? policy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final role =
        policy == null ? context.watch<AuthService>().currentUser?.role : null;
    final questions = switch (role) {
      UserRole.attendee => [
          (l.faqAttendeeBooking, l.faqAttendeeBookingBody),
          (l.faqTickets, l.faqTicketsBody),
          (l.faqCheckin, l.faqCheckinBody),
          (l.refundPolicy, l.faqRefundBody),
          (l.faqAttendeePayment, l.faqAttendeePaymentBody),
          (l.becomeOrganizer, l.faqAttendeeOrganizerBody),
        ],
      UserRole.organizer => [
          (l.faqOrganizerPublish, l.faqOrganizerPublishBody),
          (l.faqOrganizerPaid, l.faqOrganizerPaidBody),
          (l.faqOrganizerStaff, l.faqOrganizerStaffBody),
          (l.faqOrganizerCheckin, l.faqOrganizerCheckinBody),
          (l.faqOrganizerSales, l.faqOrganizerSalesBody),
          (l.faqOrganizerSupport, l.faqOrganizerSupportBody),
        ],
      _ => <(String, String)>[],
    };
    final title = policy ??
        switch (role) {
          UserRole.attendee => l.faqAttendeeTitle,
          UserRole.organizer => l.faqOrganizerTitle,
          _ => l.profileFaq,
        };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (policy != null)
          Text(l.policyUnavailable)
        else
          for (final question in questions)
            ExpansionTile(
              key: ValueKey(question.$1),
              title: Text(question.$1),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(question.$2),
                ),
              ],
            ),
      ]),
    );
  }
}
