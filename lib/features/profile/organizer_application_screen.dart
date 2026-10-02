import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';

class OrganizerApplicationScreen extends StatefulWidget {
  const OrganizerApplicationScreen({super.key});
  @override
  State<OrganizerApplicationScreen> createState() =>
      _OrganizerApplicationScreenState();
}

class _OrganizerApplicationScreenState
    extends State<OrganizerApplicationScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = List.generate(4, (_) => TextEditingController());
  Map<String, dynamic>? _application;
  bool _loading = true;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<AuthService>()
          .api
          .request('GET', '/organizer-applications/me');
      if (mounted) {
        setState(() {
          _application =
              result == null ? null : Map<String, dynamic>.from(result);
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<AuthService>()
          .api
          .request('POST', '/organizer-applications', body: {
        'contact_name': _fields[0].text.trim(),
        'organization_name': _fields[1].text.trim(),
        'contact_phone': _fields[2].text.trim(),
        'description': _fields[3].text.trim(),
      });
      if (mounted) {
        setState(() => _application = Map<String, dynamic>.from(result));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.refreshUser();
      if (!mounted || !auth.isAuthenticated) return;
      final route =
          auth.currentUser!.role.name == 'admin' ? '/admin' : '/organizer';
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.applicationContact,
      l.applicationOrganization,
      l.applicationPhone,
      l.applicationDescription
    ];
    final minimum = [2, 2, 5, 10];
    final maximum = [200, 200, 40, 2000];
    return Scaffold(
      appBar: AppBar(title: Text(l.becomeOrganizer)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: _load, child: Text(l.applicationRetry)),
                ],
                if (_application != null) ...[
                  Icon(
                      _application!['status'] == 'approved'
                          ? Icons.check_circle_outline
                          : Icons.hourglass_top,
                      size: 48),
                  const SizedBox(height: 16),
                  Text(_application!['status'] == 'approved'
                      ? l.applicationApproved
                      : l.applicationPending),
                  const SizedBox(height: 16),
                  if (_application!['status'] == 'approved')
                    FilledButton(
                        onPressed: _open, child: Text(l.applicationOpen))
                  else
                    OutlinedButton(
                        onPressed: _load, child: Text(l.applicationRetry)),
                ] else if (_loaded)
                  Form(
                    key: _form,
                    child: Column(children: [
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: _fields[i],
                            decoration: InputDecoration(
                                labelText: labels[i],
                                border: const OutlineInputBorder()),
                            maxLength: maximum[i],
                            maxLines: i == 3 ? 4 : 1,
                            keyboardType: i == 2
                                ? TextInputType.phone
                                : TextInputType.text,
                            validator: (v) =>
                                (v ?? '').trim().length < minimum[i] ||
                                        (v ?? '').trim().length > maximum[i]
                                    ? l.applicationInvalid
                                    : null,
                          ),
                        ),
                      FilledButton(
                          onPressed: _submit, child: Text(l.applicationSubmit)),
                    ]),
                  ),
              ],
            ),
    );
  }
}
