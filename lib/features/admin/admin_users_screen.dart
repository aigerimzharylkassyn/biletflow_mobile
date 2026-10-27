import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/app_avatar.dart';
import '../operations/operations_ui.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<DataService>().api;
    try {
      final result = await api.request(
          'GET',
          Uri(path: '/admin/users', queryParameters: {'q': _search.text.trim()})
              .toString());
      if (mounted && version == _request) {
        setState(() => _rows =
            (result as List).map((r) => Map<String, dynamic>.from(r)).toList());
      }
    } catch (e) {
      if (mounted && version == _request) setState(() => _error = e.toString());
    } finally {
      if (mounted && version == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = context.watch<AuthService>().currentUser;
    return Scaffold(
        appBar: AppBar(title: Text(l.adminManageUsers), actions: [
          IconButton(
              tooltip: l.refreshStatus,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OperationsCard(children: [
                                  TextField(
                                      controller: _search,
                                      decoration: InputDecoration(
                                          labelText: l.opsSearchUsers,
                                          prefixIcon: const Icon(Icons.search)),
                                      onChanged: (_) {
                                        _debounce?.cancel();
                                        ++_request;
                                        _debounce = Timer(
                                            const Duration(milliseconds: 300),
                                            _load);
                                      })
                                ]),
                                if (_loading) const LinearProgressIndicator(),
                                if (_error != null)
                                  OperationsCard(children: [
                                    Text(_error!),
                                    TextButton(
                                        onPressed: _load,
                                        child: Text(l.commonRetry))
                                  ]),
                                if (!_loading &&
                                    _error == null &&
                                    _rows.isEmpty)
                                  OperationsCard(children: [
                                    const Icon(Icons.person_search_outlined,
                                        size: 32),
                                    Text(l.managementNoData)
                                  ]),
                                if (_error == null)
                                  for (final r in _rows)
                                    OperationsCard(children: [
                                      Row(children: [
                                        AppAvatar(
                                            initials:
                                                AppUser.fromJson(r).initials,
                                            size: 40),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(
                                                r['full_name'] ?? r['email'],
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium))
                                      ]),
                                      Text(r['email']),
                                      Text((r['roles'] as List)
                                          .map((role) => switch (role) {
                                                'organizer' =>
                                                  l.adminRoleOrganizer,
                                                'platform_admin' =>
                                                  l.adminRoleAdmin,
                                                'event_admin' =>
                                                  l.adminRoleStaff,
                                                _ => l.adminRoleAttendee
                                              })
                                          .join(' · ')),
                                      if (r['id'] != me?.id)
                                        OutlinedButton.icon(
                                            onPressed: _loading
                                                ? null
                                                : () async {
                                                    final active =
                                                        r['is_active'] != false;
                                                    final api = context
                                                        .read<DataService>()
                                                        .api;
                                                    final result = await operationsForm(
                                                        context,
                                                        title: active
                                                            ? l.adminSuspendUser
                                                            : l
                                                                .adminActivateUser,
                                                        help: l
                                                            .managementUserHelp,
                                                        fields: [
                                                          OperationField('reason',
                                                              l.managementReason,
                                                              multiline: true,
                                                              validate: (v) =>
                                                                  v.length >= 3
                                                                      ? null
                                                                      : l.opsInvalid)
                                                        ],
                                                        save: (f) => api.request(
                                                            'POST',
                                                            '/admin/users/${r['id']}/${active ? 'suspend' : 'restore'}',
                                                            body: f));
                                                    if (result != null &&
                                                        mounted) {
                                                      await _load();
                                                    }
                                                  },
                                            icon: Icon(r['is_active'] == false
                                                ? Icons.person_add_alt
                                                : Icons.person_off_outlined),
                                            label: Text(r['is_active'] == false
                                                ? l.adminActivateUser
                                                : l.adminSuspendUser)),
                                    ]),
                              ])))
                ])));
  }
}
