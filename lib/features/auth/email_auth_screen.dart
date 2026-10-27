import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/demo_email_flow.dart';
import '../../shared/widgets/app_text_field.dart';

class EmailDemoNotice extends StatelessWidget {
  const EmailDemoNotice({super.key, this.showCode = false});
  final bool showCode;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.l10n.emailDemoTitle,
            style: const TextStyle(
                color: AppColors.primaryInk, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(context.l10n.emailDemoNotice, style: const TextStyle(height: 1.5)),
        if (showCode) ...[
          const SizedBox(height: 12),
          SelectableText(context.l10n.emailDemoCode,
              style: const TextStyle(
                  color: AppColors.primaryInk, fontWeight: FontWeight.w600)),
        ],
      ]));
}

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen(
      {super.key,
      this.resetPassword = false,
      this.newRegistration = false,
      this.initialEmail = '',
      this.demo});
  final bool resetPassword, newRegistration;
  final String initialEmail;
  final DemoEmailFlow? demo;
  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _form = GlobalKey<FormState>();
  late final DemoEmailFlow _demo;
  late final TextEditingController _email;
  final _code = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  Timer? _timer;
  bool _busy = false, _sent = false, _done = false;
  String? _error, _notice;
  EmailPurpose get _purpose => widget.resetPassword
      ? EmailPurpose.passwordReset
      : EmailPurpose.verification;
  int get _remaining => _demo.resendSeconds(_email.text, _purpose);

  @override
  void initState() {
    super.initState();
    _demo = widget.demo ?? DemoEmailFlow();
    _email = TextEditingController(
        text: widget.resetPassword
            ? widget.initialEmail
            : context.read<AuthService>().currentUser?.email ??
                widget.initialEmail);
    if (!widget.resetPassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestCode();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String _message(Object error) {
    final l = context.l10n;
    return switch (error) {
      DemoEmailFailure.expiredCode => l.emailCodeExpired,
      DemoEmailFailure.locked => l.emailCodeLocked,
      DemoEmailFailure.cooldown => l.emailCodeWait,
      _ => l.emailCodeInvalid,
    };
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    if (widget.resetPassword && !_sent && !_form.currentState!.validate()) {
      return;
    }
    final isResend = _sent;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await _demo.requestCode(_email.text, _purpose);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _sent = true;
        _notice = isResend ? context.l10n.emailCodeReady : null;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {});
        if (_remaining == 0) timer.cancel();
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      // Password fields are validated locally and never passed to the simulator,
      // logged, persisted, or submitted to the existing backend.
      await _demo.confirmCode(_email.text, _purpose, _code.text);
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
      _code.clear();
      _timer?.cancel();
      setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continue() {
    if (widget.newRegistration) {
      final role = context.read<AuthService>().currentUser!.role;
      final route = switch (role) {
        UserRole.attendee => '/attendee',
        UserRole.organizer => '/organizer',
        UserRole.staff => '/staff',
        UserRole.admin => '/admin',
      };
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reset = widget.resetPassword;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: AppColors.caseBackground,
          appBar: AppBar(
              automaticallyImplyLeading: !widget.newRegistration,
              title: Text(reset ? l.passwordResetTitle : l.emailVerifyTitle)),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  EmailDemoNotice(showCode: _sent && !_done),
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider)),
                      child: Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: Icon(
                                        _done
                                            ? Icons.task_alt_rounded
                                            : reset
                                                ? Icons.lock_reset_rounded
                                                : Icons
                                                    .mark_email_unread_outlined,
                                        color: AppColors.primaryInk,
                                        size: 32)),
                                const SizedBox(height: 16),
                                Text(
                                    _done
                                        ? (reset
                                            ? l.passwordDemoDone
                                            : l.emailDemoVerified)
                                        : (reset
                                            ? l.passwordResetTitle
                                            : l.emailVerifyTitle),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Text(
                                    _done
                                        ? (reset
                                            ? l.passwordDemoDoneHelp
                                            : l.emailDemoVerifiedHelp)
                                        : reset
                                            ? (_sent
                                                ? l.passwordCodeHelp
                                                : l.passwordResetHelp)
                                            : l.emailVerifyHelp,
                                    style: const TextStyle(
                                        height: 1.6,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 20),
                                if (!_done) ...[
                                  if (reset && !_sent)
                                    AppTextField(
                                        label: l.authEmailLabel,
                                        hint: l.authEmailHint,
                                        controller: _email,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (v) =>
                                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                    .hasMatch((v ?? '').trim())
                                                ? null
                                                : l.authValidationEmailInvalid)
                                  else if (_sent) ...[
                                    Text(_email.text,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                        key: const ValueKey('email-demo-code'),
                                        controller: _code,
                                        enabled: !_busy,
                                        keyboardType: TextInputType.number,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode
                                        ],
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6)
                                        ],
                                        decoration: InputDecoration(
                                            labelText: l.emailCodeLabel,
                                            errorMaxLines: 4),
                                        validator: (v) => RegExp(r'^\d{6}$')
                                                .hasMatch((v ?? '').trim())
                                            ? null
                                            : l.emailCodeRequired),
                                    if (reset) ...[
                                      const SizedBox(height: 20),
                                      AppTextField(
                                          label: l.passwordNewLabel,
                                          hint: l.passwordMinLength,
                                          controller: _password,
                                          obscureText: true,
                                          validator: (v) =>
                                              (v ?? '').runes.length >= 8 &&
                                                      (v ?? '').runes.length <=
                                                          128
                                                  ? null
                                                  : l.passwordMinLength),
                                      const SizedBox(height: 16),
                                      AppTextField(
                                          label: l.authConfirmPasswordLabel,
                                          hint: l.authConfirmPasswordHint,
                                          controller: _confirm,
                                          obscureText: true,
                                          validator: (v) => v == _password.text
                                              ? null
                                              : l.authValidationPasswordMismatch),
                                    ],
                                  ],
                                  if (_error != null) ...[
                                    const SizedBox(height: 16),
                                    Semantics(
                                        liveRegion: true,
                                        child: Text(_error!,
                                            style: const TextStyle(
                                                color: AppColors.error)))
                                  ],
                                  if (_notice != null) ...[
                                    const SizedBox(height: 16),
                                    Semantics(
                                        liveRegion: true,
                                        child: Text(_notice!,
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textSecondary)))
                                  ],
                                  const SizedBox(height: 24),
                                  FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : _sent
                                              ? _submit
                                              : _requestCode,
                                      child: Text(
                                          _busy
                                              ? l.commonLoading
                                              : _sent
                                                  ? (reset
                                                      ? l.passwordResetPreview
                                                      : l.emailVerifyAction)
                                                  : l.passwordSendDemoCode,
                                          textAlign: TextAlign.center)),
                                  if (_sent) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                        onPressed: _busy || _remaining > 0
                                            ? null
                                            : _requestCode,
                                        child: Text(
                                            _remaining > 0
                                                ? '${l.emailResend} (0:${_remaining.toString().padLeft(2, '0')})'
                                                : l.emailResend,
                                            textAlign: TextAlign.center)),
                                    if (reset)
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => setState(() {
                                                    _sent = false;
                                                    _code.clear();
                                                    _password.clear();
                                                    _confirm.clear();
                                                    _error = null;
                                                    _notice = null;
                                                  }),
                                          child: Text(l.passwordChangeEmail)),
                                  ],
                                ] else
                                  FilledButton(
                                      onPressed: _continue,
                                      child: Text(
                                          reset
                                              ? l.passwordBackLogin
                                              : l.emailContinue,
                                          textAlign: TextAlign.center)),
                                if (!reset && !_done)
                                  TextButton(
                                      onPressed: _busy ? null : _continue,
                                      child: Text(l.emailNotNow)),
                              ]))),
                ]),
          ))),
        ));
  }
}
