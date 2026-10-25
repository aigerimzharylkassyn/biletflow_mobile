import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../services/event_creation_service.dart';
import '../../models/event_creation.dart';
import 'event_creation_helpers.dart';

class PaidActivationPanel extends StatefulWidget {
  const PaidActivationPanel(
      {super.key, required this.session, required this.onActive});
  final EventCreationService session;
  final ValueChanged<bool> onActive;
  @override
  State<PaidActivationPanel> createState() => _PaidActivationPanelState();
}

class _PaidActivationPanelState extends State<PaidActivationPanel> {
  final _identityForm = GlobalKey<FormState>();
  final _payoutForm = GlobalKey<FormState>();
  late final TextEditingController _contact;
  final _organization = TextEditingController(),
      _phone = TextEditingController(),
      _reference = TextEditingController();
  final _feeKey = creationKey(), _activateKey = creationKey();
  Map<String, dynamic>? _data;
  String? _error, _receipt;
  bool _loading = true, _busy = false, _terms = false;
  @override
  void initState() {
    super.initState();
    _contact = TextEditingController(
        text: context.read<AuthService>().currentUser?.name);
    _load();
  }

  @override
  void dispose() {
    _contact.dispose();
    _organization.dispose();
    _phone.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.session.checklist();
      if (!mounted) return;
      setState(() => _data = data);
      widget.onActive(data['status'] == 'active');
    } catch (e) {
      if (mounted) setState(() => _error = creationError(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = creationError(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final api = widget.session.api;
    final id = widget.session.id;
    if (_loading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    final status = _data?['status'];
    final checks = _data?['checklist'] as Map? ?? {};
    return _spaced([
      Text(l.paidChecklist, style: Theme.of(context).textTheme.titleLarge),
      if (_error != null) ...[
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextButton(onPressed: _busy ? null : _load, child: Text(l.commonRetry))
      ],
      if (status == 'active')
        Text(l.paidActive)
      else if (status == 'suspended')
        Text(l.paidSuspended)
      else if (_data != null) ...[
        Text(l.paidSandboxHelp),
        _section(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in [
                  ('has_paid_ticket', l.paidTicketReady),
                  ('identity_verified', l.paidIdentityReady),
                  ('payout_connected', l.paidPayoutReady),
                  ('activation_fee_paid', l.paidFeeReady),
                  ('terms_accepted', l.paidTermsReady)
                ])
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(
                            checks[row.$1] == true
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: checks[row.$1] == true
                                ? Colors.green
                                : Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(row.$2))
                      ])),
              ],
            )),
        if (checks['identity_verified'] != true)
          _section(
              context,
              Form(
                  key: _identityForm,
                  child: _spaced([
                    TextFormField(
                        controller: _contact,
                        enabled: !_busy,
                        maxLength: 200,
                        buildCounter: (_,
                                {required currentLength,
                                required isFocused,
                                required maxLength}) =>
                            null,
                        decoration: InputDecoration(
                            labelText: l.applicationContact,
                            helperText:
                                creationTextHint(context, min: 2, max: 200),
                            helperMaxLines: 4,
                            errorMaxLines: 4),
                        validator: (v) =>
                            creationTextError(context, v, min: 2, max: 200)),
                    TextFormField(
                        controller: _organization,
                        enabled: !_busy,
                        maxLength: 200,
                        buildCounter: (_,
                                {required currentLength,
                                required isFocused,
                                required maxLength}) =>
                            null,
                        decoration: InputDecoration(
                            labelText: l.paidOrganization,
                            helperText: creationTextHint(context, max: 200),
                            helperMaxLines: 4,
                            errorMaxLines: 4),
                        validator: (v) =>
                            creationTextError(context, v, max: 200)),
                    TextFormField(
                        controller: _phone,
                        enabled: !_busy,
                        maxLength: 40,
                        buildCounter: (_,
                                {required currentLength,
                                required isFocused,
                                required maxLength}) =>
                            null,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                            labelText: l.paidPhone,
                            helperText: creationTextHint(context, max: 40),
                            helperMaxLines: 4,
                            errorMaxLines: 4),
                        validator: (v) =>
                            creationTextError(context, v, max: 40)),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14)),
                        onPressed: _busy
                            ? null
                            : () {
                                if (!_identityForm.currentState!.validate()) {
                                  return;
                                }
                                _act(() async {
                                  await api.request('PUT', '/organizer-profile',
                                      body: {
                                        'contact_name': _contact.text.trim(),
                                        'organization_name':
                                            _organization.text.trim().isEmpty
                                                ? null
                                                : _organization.text.trim(),
                                        'contact_phone':
                                            _phone.text.trim().isEmpty
                                                ? null
                                                : _phone.text.trim()
                                      });
                                  await api.request('POST',
                                      '/organizer-profile/verification/submit');
                                });
                              },
                        child: Text(l.paidVerify)),
                  ]))),
        if (checks['identity_verified'] == true &&
            checks['payout_connected'] != true)
          _section(
              context,
              Form(
                  key: _payoutForm,
                  child: _spaced([
                    TextFormField(
                        controller: _reference,
                        enabled: !_busy,
                        decoration: InputDecoration(
                            labelText: l.paidPayoutReference,
                            hintText: 'DEMO-0001'),
                        validator: (v) => RegExp(r'^DEMO-[A-Za-z0-9-]{4,40}$')
                                .hasMatch((v ?? '').trim())
                            ? null
                            : l.paidPayoutError),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14)),
                        onPressed: _busy
                            ? null
                            : () {
                                if (!_payoutForm.currentState!.validate()) {
                                  return;
                                }
                                _act(() async {
                                  await api.request(
                                      'PUT',
                                      '/organizer-profile/payout-account?${Uri(queryParameters: {
                                            'account_reference':
                                                _reference.text.trim()
                                          }).query}');
                                });
                              },
                        child: Text(l.paidConnect)),
                  ]))),
        if (checks['terms_accepted'] != true)
          _section(
              context,
              _spaced([
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l.paidTermsText),
                    value: _terms,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _terms = v ?? false)),
                OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14)),
                    onPressed: _busy || !_terms
                        ? null
                        : () => _act(() async {
                              await api.request('POST',
                                  '/events/$id/paid-sales/accept-terms');
                            }),
                    child: Text(l.paidAcceptTerms)),
              ])),
        if (checks['activation_fee_paid'] != true)
          OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              onPressed: _busy ||
                      checks['identity_verified'] != true ||
                      checks['payout_connected'] != true ||
                      checks['terms_accepted'] != true
                  ? null
                  : () => _act(() async {
                        final result = await api.request(
                            'POST', '/events/$id/paid-sales/activation-fee',
                            body: {'outcome': 'success'},
                            idempotencyKey: _feeKey);
                        if (result['status'] != 'succeeded') {
                          throw StateError(l.paidActionFailed);
                        }
                        if (mounted) {
                          setState(() => _receipt =
                              '${l.paidFeeReady}: ${(result['amount_minor'] as num) / 100} ₸ · ${l.demoPaymentHelp}');
                        }
                      }),
              child: Text(l.paidPayFee)),
        if (_receipt != null) Text(_receipt!),
        FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _busy || _data?['can_activate'] != true
                ? null
                : () => _act(() async {
                      final result = await api.request(
                          'POST', '/events/$id/paid-sales/activate',
                          idempotencyKey: _activateKey);
                      if (result['status'] != 'active') {
                        throw StateError(l.paidActionFailed);
                      }
                    }),
            child: Text(_busy ? l.commonLoading : l.paidActivate)),
      ],
    ]);
  }

  Widget _spaced(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ]
        ],
      );

  Widget _section(BuildContext context, Widget child) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );
}
