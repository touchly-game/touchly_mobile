import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgDark        = Color(0xFF0A2A6E);
const _bgMid         = Color(0xFF1155CC);
const _bgLight       = Color(0xFF2979FF);
const _surface       = Color(0xFF0D3A8E);
const _surfaceBorder = Color(0xFF1A4DB5);
const _yellow        = Color(0xFFFFD700);
const _navy          = Color(0xFF0A1A4E);
const _textPrimary   = Color(0xFFFFFFFF);
const _textSub       = Color(0xFFB3C8F0);
const _errorColor    = Color(0xFFFF5A7D);
const _successColor  = Color(0xFF3DD68C);
// ─────────────────────────────────────────────

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _emailFocus      = FocusNode();
  bool _isLoading  = false;
  bool _emailSent  = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'touchly://reset-password',
      );
      if (mounted) setState(() => _emailSent = true);
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
                    // ── Back button ───────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _BackBtn(onTap: () => Navigator.pop(context)),
                      ),
                    ),
                    Expanded(
                      child: _emailSent
                          ? _SuccessView(onBack: () => Navigator.pop(context))
                          : _FormView(
                        emailController: _emailController,
                        emailFocus: _emailFocus,
                        isLoading: _isLoading,
                        errorMessage: _errorMessage,
                        onSend: _sendResetEmail,
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
//  Vue succès
// ─────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onBack;
  const _SuccessView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône succès avec halo
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _successColor.withOpacity(0.06),
                ),
              ),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _successColor.withOpacity(0.12),
                  border: Border.all(
                      color: _successColor.withOpacity(0.3), width: 1),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: _successColor,
                  size: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            "Email envoyé !",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Vérifie ta boîte mail et clique sur le lien pour réinitialiser ton mot de passe.\n\nLe lien expire dans 1 heure.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSub,
              fontSize: 14,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 48),
          _PrimaryBtn(
            label: "Retour à la connexion",
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Vue formulaire
// ─────────────────────────────────────────────
class _FormView extends StatelessWidget {
  final TextEditingController emailController;
  final FocusNode emailFocus;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSend;

  const _FormView({
    required this.emailController,
    required this.emailFocus,
    required this.isLoading,
    required this.errorMessage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _yellow.withOpacity(0.25), width: 1),
            ),
            child: const Icon(Icons.lock_reset_rounded, color: _yellow, size: 28),
          ),
          const SizedBox(height: 24),

          const Text(
            "Mot de passe oublié ?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Saisis ton email et on t'envoie un lien pour en créer un nouveau.",
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 36),

          // Error banner
          if (errorMessage != null) ...[
            _ErrorBanner(message: errorMessage!),
            const SizedBox(height: 20),
          ],

          // Carte formulaire
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1), width: 1),
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
                _FieldLabel("Email"),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  focusNode: emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => isLoading ? null : onSend(),
                  cursorColor: _yellow,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "ton@email.com",
                    hintStyle: const TextStyle(color: _textSub, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    prefixIcon: const Icon(Icons.mail_outline_rounded,
                        color: _textSub, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                      const BorderSide(color: _yellow, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _PrimaryBtn(
                  label: "Envoyer le lien",
                  isLoading: isLoading,
                  onTap: isLoading ? null : onSend,
                ),
              ],
            ),
          ),
        ],
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