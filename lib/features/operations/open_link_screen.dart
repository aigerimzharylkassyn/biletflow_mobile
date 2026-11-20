import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/app_link.dart';
import '../../models/event.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../attendee/event_details_screen.dart';
import '../auth/login_screen.dart';
import '../organizer/ticket_scanner_screen.dart';

class OpenLinkScreen extends StatefulWidget {
  const OpenLinkScreen({super.key, this.link});
  final AppLink? link;
  @override
  State<OpenLinkScreen> createState() => _OpenLinkScreenState();
}

class _OpenLinkScreenState extends State<OpenLinkScreen> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  AppLink? _link;
  AppEvent? _event;
  String? _promo, _error;
  bool _busy = false, _done = false, _scanning = false;

  @override
  void initState() {
    super.initState();
    _link = widget.link;
    if (_link?.kind == AppLinkKind.campaign &&
        context.read<AuthService>().isAuthenticated) {
      _resolve();
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _open() {
    final link = AppLink.parse(_url.text);
    if (link == null) {
      setState(() => _error = context.l10n.linkInvalid);
      return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => OpenLinkScreen(link: link)));
  }

  Future<void> _scan() async {
    if (_scanning) return;
    final l = context.l10n;
    setState(() => _scanning = true);
    try {
      final value = await Navigator.push<String>(
          context,
          MaterialPageRoute(
              builder: (_) => TicketScannerScreen(
                  title: l.campaignQr, instruction: l.campaignHelp)));
      if (value == null || !mounted) return;
      _url.text = value;
      _open();
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _resolve() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = context.read<DataService>();
      final result = await data.api.request(
          'GET', '/campaigns/resolve/${Uri.encodeComponent(_link!.token)}');
      if (!mounted) return;
      if (result['state'] != 'active' || result['promo_code'] == null) {
        setState(() => _error =
            result['message'] as String? ?? context.l10n.linkCampaignInactive);
        return;
      }
      final event = await data.eventDetails(result['event_id'] as String);
      if (mounted) {
        setState(() {
          _event = event;
          _promo = result['promo_code'] as String;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    try {
      if (_link!.kind == AppLinkKind.verification) {
        final verified = await auth.api.request('POST', '/auth/verify-email',
            body: {'token': _link!.token});
        // Verification has succeeded even if refreshing a local session fails.
        if (mounted) setState(() => _done = true);
        // Do not replace a different signed-in person's profile with the link owner.
        if (auth.currentUser?.id == verified['id']) await auth.refreshUser();
      } else {
        await auth.api.request('POST', '/auth/reset-password',
            body: {'token': _link!.token, 'password': _password.text});
        // The server invalidates older sessions after a password change.
        auth.logout();
        _password.clear();
        _confirm.clear();
      }
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continue() {
    final user = context.read<AuthService>().currentUser;
    final route = switch (user?.role) {
      UserRole.admin => '/admin',
      UserRole.organizer => '/organizer',
      UserRole.staff => '/staff',
      UserRole.attendee => '/attendee',
      null => '/login',
    };
    final navigator = Navigator.of(context);
    navigator.pushNamedAndRemoveUntil(route, (_) => false);
    if (_event != null) {
      navigator.push(MaterialPageRoute(
          builder: (_) =>
              EventDetailsScreen(event: _event!, initialPromo: _promo!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_link?.kind == AppLinkKind.campaign &&
        !context.watch<AuthService>().isAuthenticated) {
      return LoginScreen(onAuthenticated: _resolve);
    }
    final reset = _link?.kind == AppLinkKind.passwordReset;
    return Scaffold(
      appBar: AppBar(title: Text(l.linkOpen)),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text(l.linkHelp),
                const SizedBox(height: 20),
                if (_link == null) ...[
                  TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: l.linkUrl),
                      onSubmitted: (_) => _open()),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _open, child: Text(l.linkOpen)),
                  OutlinedButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(l.campaignQr)),
                ] else if (_link!.kind == AppLinkKind.campaign) ...[
                  if (_event != null) ...[
                    Text(_event!.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text('${l.promoCode}: $_promo'),
                    Text(l.campaignHelp),
                    FilledButton(
                        onPressed: _continue, child: Text(l.linkContinue)),
                  ] else if (!_busy)
                    OutlinedButton(
                        onPressed: _resolve, child: Text(l.commonRetry)),
                ] else if (_done) ...[
                  Semantics(
                      liveRegion: true,
                      child: Text(reset ? l.linkResetDone : l.linkVerified)),
                  FilledButton(
                      onPressed: _continue, child: Text(l.linkContinue)),
                ] else
                  Form(
                      key: _form,
                      child: Column(children: [
                        if (reset) ...[
                          TextFormField(
                              controller: _password,
                              obscureText: true,
                              enabled: !_busy,
                              maxLength: 128,
                              decoration: InputDecoration(
                                  labelText: l.authPasswordLabel),
                              validator: (v) => (v ?? '').runes.length < 8 ||
                                      (v ?? '').runes.length > 128
                                  ? l.linkPasswordRule
                                  : null),
                          TextFormField(
                              controller: _confirm,
                              obscureText: true,
                              enabled: !_busy,
                              maxLength: 128,
                              decoration: InputDecoration(
                                  labelText: l.authConfirmPasswordLabel),
                              validator: (v) => v != _password.text
                                  ? l.authValidationPasswordMismatch
                                  : null),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(reset ? l.linkReset : l.linkVerify)),
                      ])),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ]))),
    );
  }
}
