import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/features/onboarding/presentation/pages/home_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/register_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/forgot_password_page.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgDark        = Color(0xFF060E30);
const _bgMid         = Color(0xFF0A2A6E);
const _bgLight       = Color(0xFF1A5AE8);
const _surface       = Color(0xFF0D3A8E);
const _surfaceBorder = Color(0xFF1A4DB5);
const _yellow        = Color(0xFFFFD700);
const _yellowSoft    = Color(0xFFFFB300);
const _navy          = Color(0xFF0A1A4E);
const _textPrimary   = Color(0xFFFFFFFF);
const _textSub       = Color(0xFFB3C8F0);
const _errorColor    = Color(0xFFFF5A7D);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final _emailFocus        = FocusNode();
  final _passwordFocus     = FocusNode();

  bool isLoading    = false;
  bool _obscurePass = true;
  bool _rememberMe  = false;
  String? errorMessage;

  late final AnimationController _btnCtrl;
  late final Animation<double>   _btnScale;

  late final AnimationController _entryCtrl;
  late final Animation<double>   _entryFade;
  late final Animation<Offset>   _entrySlide;

  // Clés SharedPreferences
  static const _kEmail    = 'saved_email';
  static const _kPassword = 'saved_password';
  static const _kRemember = 'remember_me';

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _btnScale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    _loadSavedCredentials();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _btnCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Chargement des identifiants sauvegardés ──
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_kRemember) ?? false;
    if (remember) {
      final email    = prefs.getString(_kEmail) ?? '';
      final password = prefs.getString(_kPassword) ?? '';
      if (mounted) {
        setState(() {
          _rememberMe = true;
          emailController.text    = email;
          passwordController.text = password;
        });
      }
    }
  }

  // ── Sauvegarde / suppression des identifiants ──
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_kEmail,    emailController.text.trim());
      await prefs.setString(_kPassword, passwordController.text.trim());
      await prefs.setBool(_kRemember,   true);
    } else {
      await prefs.remove(_kEmail);
      await prefs.remove(_kPassword);
      await prefs.setBool(_kRemember, false);
    }
  }

  // ── Login ─────────────────────────────────────
  Future<void> login() async {
    setState(() { errorMessage = null; isLoading = true; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email:    emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await _saveCredentials();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GameHomePage()),
      );
    } on AuthException catch (e) {
      setState(() => errorMessage = _traduireErreur(e.message));
    } catch (e) {
      setState(() => errorMessage = "Erreur de connexion");
    }
    if (mounted) setState(() => isLoading = false);
  }

  String _traduireErreur(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password'))
      return "Email ou mot de passe incorrect.";
    if (msg.contains('email not confirmed'))
      return "Ton email n'est pas encore confirmé. Vérifie ta boîte mail.";
    if (msg.contains('user not found'))
      return "Aucun compte trouvé avec cet email.";
    if (msg.contains('too many requests') || msg.contains('rate limit'))
      return "Trop de tentatives. Réessaie dans quelques minutes.";
    if (msg.contains('network') || msg.contains('connection'))
      return "Problème de connexion. Vérifie ton réseau.";
    if (msg.contains('invalid email')) return "Adresse email invalide.";
    if (msg.contains('token') || msg.contains('expired'))
      return "Lien expiré. Demande un nouveau lien de réinitialisation.";
    return "Une erreur est survenue. Réessaie.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgLight, _bgMid, _bgDark],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Halos lumineux de fond ──────────────
            Positioned(top: -100, left: -80,
                child: _GlowBlob(size: 280, color: _yellow.withOpacity(0.07))),
            Positioned(top: -40, right: -90,
                child: _GlowBlob(size: 260, color: const Color(0xFF2979FF).withOpacity(0.22))),
            Positioned(bottom: -120, left: -60,
                child: _GlowBlob(size: 300, color: _yellow.withOpacity(0.05))),

            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: FadeTransition(
                    opacity: _entryFade,
                    child: SlideTransition(
                      position: _entrySlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          const _LogoHeader(),
                          const SizedBox(height: 20),

                          const Text('Bon retour !', style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w900,
                            color: _textPrimary, letterSpacing: -0.5,
                          )),
                          const SizedBox(height: 8),
                          const Text("Reconnecte-toi et reprends l'aventure",
                              style: TextStyle(fontSize: 14.5, color: _textSub,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 30),

                          // ── Formulaire (effet glass) ────────
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _surface.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.14), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 30, offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (errorMessage != null) ...[
                                      _ErrorBanner(message: errorMessage!),
                                      const SizedBox(height: 20),
                                    ],

                                    _TLabel("Email"),
                                    const SizedBox(height: 7),
                                    _TField(
                                      controller: emailController,
                                      focusNode: _emailFocus,
                                      hint: "ton@email.com",
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                                      prefixIcon: Icons.mail_outline_rounded,
                                    ),

                                    const SizedBox(height: 18),

                                    _TLabel("Mot de passe"),
                                    const SizedBox(height: 7),
                                    _TField(
                                      controller: passwordController,
                                      focusNode: _passwordFocus,
                                      hint: "••••••••",
                                      obscureText: _obscurePass,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => isLoading ? null : login(),
                                      prefixIcon: Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePass
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: _textSub, size: 20,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscurePass = !_obscurePass),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // ── Remember me + mot de passe oublié ──
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () =>
                                              setState(() => _rememberMe = !_rememberMe),
                                          child: Row(children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: 21, height: 21,
                                              decoration: BoxDecoration(
                                                color: _rememberMe
                                                    ? _yellow.withOpacity(0.18)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: _rememberMe
                                                      ? _yellow
                                                      : _surfaceBorder,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: _rememberMe
                                                  ? const Icon(Icons.check_rounded,
                                                  color: _yellow, size: 13)
                                                  : null,
                                            ),
                                            const SizedBox(width: 9),
                                            const Text('Se souvenir de moi',
                                                style: TextStyle(
                                                  color: _textSub, fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                )),
                                          ]),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 0),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => const ForgotPasswordPage()),
                                          ),
                                          child: const Text('Mot de passe oublié ?',
                                              style: TextStyle(
                                                fontSize: 12.5, color: _yellow,
                                                fontWeight: FontWeight.w700,
                                              )),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 22),

                                    _AnimatedButton(
                                      label: "Se connecter",
                                      isLoading: isLoading,
                                      btnCtrl: _btnCtrl,
                                      btnScale: _btnScale,
                                      onTap: isLoading ? null : login,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 26),
                          const _OrDivider(),
                          const SizedBox(height: 22),

                          // ── Bloc inscription mis en avant ───────
                          _RegisterCallout(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterPage()),
                            ),
                          ),

                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
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
//  Logo — grand, avec halo pulsé
// ─────────────────────────────────────────────
class _LogoHeader extends StatefulWidget {
  const _LogoHeader();

  @override
  State<_LogoHeader> createState() => _LogoHeaderState();
}

class _LogoHeaderState extends State<_LogoHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.94, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 220 * _pulse.value,
              height: 220 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _yellow.withOpacity(0.30),
                      blurRadius: 90, spreadRadius: 14),
                  BoxShadow(color: const Color(0xFF2979FF).withOpacity(0.25),
                      blurRadius: 60, spreadRadius: 6),
                ],
              ),
            ),
          ),
          Container(
            width: 168, height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withOpacity(0.06), Colors.transparent],
              ),
            ),
          ),
          Image.asset('lib/assets/images/logo_touchly.png',
              width: 200, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Séparateur "ou"
// ─────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.14), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OU',
              style: TextStyle(
                color: _textSub.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              )),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.14), thickness: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Bloc d'invitation à l'inscription — mis en valeur
// ─────────────────────────────────────────────
class _RegisterCallout extends StatefulWidget {
  final VoidCallback onTap;
  const _RegisterCallout({required this.onTap});

  @override
  State<_RegisterCallout> createState() => _RegisterCalloutState();
}

class _RegisterCalloutState extends State<_RegisterCallout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_yellow.withOpacity(0.14), _yellowSoft.withOpacity(0.05)],
            ),
            border: Border.all(color: _yellow.withOpacity(0.45), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: _yellow.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_yellow, _yellowSoft]),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: _navy, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouveau sur Touchly ?',
                        style: TextStyle(
                          color: _textPrimary, fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        )),
                    SizedBox(height: 3),
                    Text('Crée ton compte en quelques secondes',
                        style: TextStyle(
                          color: _textSub, fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: _yellow, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Champs & labels
// ─────────────────────────────────────────────
class _TLabel extends StatelessWidget {
  final String text;
  const _TLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: _textSub, letterSpacing: 0.3,
      ));
}

class _TField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final String                hint;
  final bool                  obscureText;
  final TextInputType         keyboardType;
  final TextInputAction       textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData              prefixIcon;
  final Widget?               suffix;

  const _TField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.obscureText       = false,
    this.keyboardType      = TextInputType.text,
    this.textInputAction   = TextInputAction.done,
    this.onSubmitted,
    required this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:      controller,
    focusNode:       focusNode,
    obscureText:     obscureText,
    keyboardType:    keyboardType,
    textInputAction: textInputAction,
    onSubmitted:     onSubmitted,
    style: const TextStyle(
        color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
    cursorColor: _yellow,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSub, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      prefixIcon: Icon(prefixIcon, color: _textSub, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _yellow, width: 1.5),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  Bouton principal
// ─────────────────────────────────────────────
class _AnimatedButton extends StatelessWidget {
  final String              label;
  final bool                isLoading;
  final AnimationController btnCtrl;
  final Animation<double>   btnScale;
  final VoidCallback?       onTap;

  const _AnimatedButton({
    required this.label,
    required this.isLoading,
    required this.btnCtrl,
    required this.btnScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: btnScale,
    child: GestureDetector(
      onTapDown:  (_) => btnCtrl.forward(),
      onTapUp:    (_) { btnCtrl.reverse(); onTap?.call(); },
      onTapCancel: () => btnCtrl.reverse(),
      child: Container(
        width: double.infinity, height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: isLoading
              ? null
              : const LinearGradient(colors: [_yellow, _yellowSoft]),
          color: isLoading ? _surfaceBorder : null,
          boxShadow: isLoading ? null : [BoxShadow(
            color: _yellow.withOpacity(0.5),
            blurRadius: 26, offset: const Offset(0, 8),
          )],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _textPrimary))
              : Text(label, style: const TextStyle(
              color: _navy, fontSize: 16.5,
              fontWeight: FontWeight.w900, letterSpacing: 0.3)),
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
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: _errorColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _errorColor.withOpacity(0.4), width: 1),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _errorColor, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(
        color: _errorColor, fontSize: 13, fontWeight: FontWeight.w500,
      ))),
    ]),
  );
}

// ─────────────────────────────────────────────
//  Utilitaire — halo lumineux de fond
// ─────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}