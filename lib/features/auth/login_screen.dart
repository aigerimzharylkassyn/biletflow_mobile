import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/language_selector.dart';
import '../../shared/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final success = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? l10n.authLoginErrorInvalid)),
      );
      return;
    }

    final role = auth.currentUser!.role;
    final route = switch (role) {
      UserRole.attendee => '/attendee',
      UserRole.organizer => '/organizer',
      UserRole.staff => '/staff',
      UserRole.admin => '/admin',
    };
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoading = context.watch<AuthService>().isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageIconButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ).createShader(bounds),
                  child: Text(
                    'BiletFlow',
                    style: AppTheme.logoStyle.copyWith(fontSize: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.authWelcomeTitle,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.authWelcomeSubtitle,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  label: l10n.authEmailLabel,
                  hint: l10n.authEmailHint,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return l10n.authValidationEmailRequired;
                    if (!value.contains('@') || !value.contains('.')) return l10n.authValidationEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: l10n.authPasswordLabel,
                  hint: l10n.authPasswordHint,
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) return l10n.authValidationPasswordRequired;
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.authForgotPasswordSent)),
                      );
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(l10n.authForgotPassword),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: l10n.authLoginButton, onPressed: _submit, isLoading: isLoading),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.authNoAccount, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/register'),
                      child: Text(l10n.authRegisterButton),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in with your backend account, or register a new account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
