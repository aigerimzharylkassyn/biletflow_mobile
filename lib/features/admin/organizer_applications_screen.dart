import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';

class OrganizerApplicationsScreen extends StatefulWidget {
  const OrganizerApplicationsScreen({super.key});
  @override
  State<OrganizerApplicationsScreen> createState() =>
      _OrganizerApplicationsScreenState();
}

class _OrganizerApplicationsScreenState
    extends State<OrganizerApplicationsScreen> {
  List<dynamic> _applications = [];
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context
          .read<AuthService>()
          .api
          .request('GET', '/admin/organizer-applications');
      if (mounted) setState(() => _applications = result as List);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(String id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<AuthService>()
          .api
          .request('POST', '/admin/organizer-applications/$id/approve');
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.organizerApplications), actions: [
        IconButton(
            onPressed: _busy ? null : _load,
            tooltip: l.applicationRetry,
            icon: const Icon(Icons.refresh))
      ]),
      body: _busy
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
                if (_applications.isEmpty && _error == null)
                  Text(l.applicationEmpty),
                for (final a in _applications)
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['organization_name'],
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('${a['contact_name']} · ${a['contact_phone']}'),
                          const SizedBox(height: 8),
                          Text(a['description']),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: () => _approve(a['id']),
                              child: Text(l.applicationApprove)),
                        ]),
                  )),
              ],
            ),
    );
  }
}
