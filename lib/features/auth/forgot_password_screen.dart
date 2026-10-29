import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/primary_button.dart';

/// Requests a password-reset email. The emailed link opens the web app's
/// /reset-password page, where the new password is chosen.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().forgotPassword(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotPasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.authForgotPasswordBody,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 24),
                AppTextField(
                  label: l10n.authEmailLabel,
                  hint: l10n.authEmailHint,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return l10n.authValidationEmailRequired;
                    if (!value.contains('@') || !value.contains('.')) return l10n.authValidationEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_sent)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mark_email_read_outlined, color: AppColors.success),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.authForgotPasswordSent)),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                PrimaryButton(label: l10n.authForgotPasswordSubmit, onPressed: _submit, isLoading: _busy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
