import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/features/onboarding/presentation/pages/login_page.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgLight       = Color(0xFF2979FF);
const _bgMid         = Color(0xFF0A2A6E);
const _yellow        = Color(0xFFFFD700);
const _navy          = Color(0xFF0A1A4E);
const _textPrimary   = Color(0xFFFFFFFF);
const _textSub       = Color(0xFFB3C8F0);
const _errorColor    = Color(0xFFFF5A7D);
const _successColor  = Color(0xFF3DD68C);
// ─────────────────────────────────────────────

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  final _passwordFocus      = FocusNode();
  final _confirmFocus       = FocusNode();

  bool _isLoading = false;
  bool _obscure1  = true;
  bool _obscure2  = true;
  String? _errorMessage;

  bool get _match =>
      _confirmController.text.isNotEmpty &&
          _passwordController.text == _confirmController.text;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = "6 caractères minimum");
      return;
    }
    if (!_match) {
      setState(() => _errorMessage = "Les mots de passe ne correspondent pas");
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (!mounted) return;
      await Supabase.instance.client.auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = "Une erreur est survenue");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1A5AE8), Color(0xFF0A2A6E), Color(0xFF060E30)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Lueurs d'ambiance
            Positioned(
              top: -60, right: -40,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _yellow.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 80, left: -50,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bgLight.withOpacity(0.12),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: Column(
                  children: [
                    // Back button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _BackBtn(onTap: () => Navigator.pop(context)),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Icône ─────────────────────
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: _yellow.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _yellow.withOpacity(0.25), width: 1),
                              ),
                              child: const Icon(Icons.lock_reset_rounded,
                                  color: _yellow, size: 28),
                            ),
                            const SizedBox(height: 24),

                            const Text(
                              "Nouveau mot de passe",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Choisis un mot de passe solide pour sécuriser ton compte.",
                              style: TextStyle(
                                  color: _textSub, fontSize: 14, height: 1.5),
                            ),
                            const SizedBox(height: 36),

                            // ── Error banner ───────────────
                            if (_errorMessage != null) ...[
                              _ErrorBanner(message: _errorMessage!),
                              const SizedBox(height: 24),
                            ],

                            // ── Carte formulaire ───────────
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nouveau mot de passe
                                  const _FieldLabel("Nouveau mot de passe"),
                                  const SizedBox(height: 6),
                                  _PasswordField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    hint: "Min. 6 caractères",
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscure: _obscure1,
                                    onToggleObscure: () =>
                                        setState(() => _obscure1 = !_obscure1),
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _confirmFocus.requestFocus(),
                                  ),
                                  const SizedBox(height: 20),

                                  // Confirmation
                                  const _FieldLabel("Confirmer le mot de passe"),
                                  const SizedBox(height: 6),
                                  _PasswordField(
                                    controller: _confirmController,
                                    focusNode: _confirmFocus,
                                    hint: "••••••••",
                                    prefixIcon: Icons.shield_outlined,
                                    obscure: _obscure2,
                                    onToggleObscure: () =>
                                        setState(() => _obscure2 = !_obscure2),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) =>
                                    _isLoading ? null : _updatePassword(),
                                    matchIcon: _confirmController.text.isNotEmpty
                                        ? (_match
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.cancel_outlined)
                                        : null,
                                    matchColor: _match ? _successColor : _errorColor,
                                  ),

                                  // Indicateur de correspondance
                                  if (_confirmController.text.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          _match
                                              ? Icons.check_rounded
                                              : Icons.close_rounded,
                                          color: _match
                                              ? _successColor
                                              : _errorColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _match
                                              ? "Les mots de passe correspondent"
                                              : "Les mots de passe ne correspondent pas",
                                          style: TextStyle(
                                            color: _match
                                                ? _successColor
                                                : _errorColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 28),

                                  // Bouton
                                  _PrimaryBtn(
                                    label: "Enregistrer le mot de passe",
                                    isLoading: _isLoading,
                                    onTap: _isLoading ? null : _updatePassword,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widgets locaux
// ─────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: const Icon(Icons.arrow_back_rounded,
          color: _textPrimary, size: 20),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _textSub,
      letterSpacing: 0.3,
    ),
  );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData? matchIcon;
  final Color? matchColor;

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.prefixIcon,
    required this.obscure,
    required this.onToggleObscure,
    required this.textInputAction,
    this.onSubmitted,
    this.matchIcon,
    this.matchColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      cursorColor: _yellow,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSub, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        prefixIcon: Icon(prefixIcon, color: _textSub, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (matchIcon != null)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(matchIcon, color: matchColor, size: 18),
              ),
            IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _textSub,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
          ],
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.12), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _yellow, width: 1.5),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PrimaryBtn({
    required this.label,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isLoading
            ? null
            : const LinearGradient(
            colors: [_yellow, Color(0xFFFFB300)]),
        color: isLoading ? Colors.white.withOpacity(0.1) : null,
        boxShadow: isLoading
            ? null
            : [
          BoxShadow(
            color: _yellow.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: _textPrimary),
        )
            : Text(
          label,
          style: const TextStyle(
            color: _navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding:
    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: _errorColor.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      border:
      Border.all(color: _errorColor.withOpacity(0.35), width: 1),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: _errorColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
                color: _errorColor,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}