import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final success = await auth.register(name: _nameController.text.trim(), email: _emailController.text.trim(), password: _passwordController.text);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? "Registration failed")));
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/attendee', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoading = context.watch<AuthService>().isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authRegisterTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: l10n.authNameLabel,
                  hint: l10n.authNameHint,
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.authValidationNameRequired : null,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: l10n.authEmailLabel,
                  hint: l10n.authEmailHint,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.authValidationEmailRequired;
                    if (!v.contains('@') || !v.contains('.')) return l10n.authValidationEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: l10n.authPasswordLabel,
                  hint: l10n.authPasswordHint,
                  controller: _passwordController,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.authValidationPasswordRequired;
                    if (v.length < 8) return "Use at least 8 characters";
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: l10n.authConfirmPasswordLabel,
                  hint: l10n.authConfirmPasswordHint,
                  controller: _confirmController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v != _passwordController.text) return l10n.authValidationPasswordMismatch;
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(label: l10n.authRegisterButton, onPressed: _submit, isLoading: isLoading),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.authAlreadyHaveAccount, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.authLoginButton),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
