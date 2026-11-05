import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/features/onboarding/presentation/pages/demo_theme_memory.dart';
import 'package:touchly/features/onboarding/presentation/pages/home_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/login_page.dart';

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

class RegisterPage extends StatefulWidget {
  /// Code pré-rempli depuis ActivationCodePage — verrouille le champ
  final String? prefillCode;
  const RegisterPage({super.key, this.prefillCode});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final firstNameController       = TextEditingController();
  final lastNameController        = TextEditingController();
  final emailController           = TextEditingController();
  final passwordController        = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final uniqueCodeController      = TextEditingController();
  final supabase                  = Supabase.instance.client;

  final _firstNameFocus = FocusNode();
  final _lastNameFocus  = FocusNode();
  final _emailFocus     = FocusNode();
  final _codeFocus      = FocusNode();
  final _passwordFocus  = FocusNode();
  final _confirmFocus   = FocusNode();

  bool isLoading       = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  String? errorMessage;

  late final AnimationController _btnCtrl;
  late final Animation<double>   _btnScale;

  bool get _codeIsLocked => widget.prefillCode != null;

  int get _passwordStrength {
    final p = passwordController.text;
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s++;
    return s;
  }

  String get _strengthLabel {
    switch (_passwordStrength) {
      case 1: return 'Faible';
      case 2: return 'Moyen';
      case 3: return 'Bon';
      case 4: return 'Fort';
      default: return '';
    }
  }

  Color get _strengthColor {
    switch (_passwordStrength) {
      case 1: return _errorColor;
      case 2: return const Color(0xFFFFB300);
      case 3: return _successColor;
      default: return _successColor;
    }
  }

  bool get _passwordsMatch =>
      confirmPasswordController.text.isNotEmpty &&
          passwordController.text == confirmPasswordController.text;

  @override
  void initState() {
    super.initState();

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut),
    );

    // Pré-remplir le code si fourni depuis ActivationCodePage
    if (widget.prefillCode != null) {
      uniqueCodeController.text = widget.prefillCode!;
    }

    passwordController.addListener(() => setState(() {}));
    confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    uniqueCodeController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    setState(() { errorMessage = null; isLoading = true; });
    try {
      final activationCode = uniqueCodeController.text.trim();

      if (firstNameController.text.trim().isEmpty) {
        throw Exception('Saisis ton prénom.');
      }
      if (lastNameController.text.trim().isEmpty) {
        throw Exception('Saisis ton nom.');
      }
      if (emailController.text.trim().isEmpty) {
        throw Exception('Saisis ton adresse email.');
      }
      if (activationCode.isEmpty) {
        throw Exception("Saisis le code unique de ta boîte.");
      }
      if (passwordController.text.length < 6) {
        throw Exception("Le mot de passe doit contenir au moins 6 caractères.");
      }
      if (passwordController.text != confirmPasswordController.text) {
        throw Exception("Les mots de passe ne correspondent pas.");
      }

      // Vérification code (seulement si pas déjà validé en amont)
      final codeRes = await supabase
          .from('activation_codes')
          .select()
          .eq('code', activationCode)
          .eq('is_used', false)
          .maybeSingle();

      if (codeRes == null) {
        throw Exception("Code d'activation invalide ou déjà utilisé.");
      }

      final authRes = await supabase.auth.signUp(
        email:    emailController.text.trim(),
        password: passwordController.text,
      );

      final user = authRes.user;
      if (user == null) throw Exception("Impossible de créer le compte.");

      await supabase.from('app_users').insert({
        'id':              user.id,
        'email':           emailController.text.trim(),
        'first_name':      firstNameController.text.trim(),
        'last_name':       lastNameController.text.trim(),
        'activation_code': activationCode,
      });

      await supabase
          .from('activation_codes')
          .update({
        'is_used': true,
        'used_by': user.id,
        'used_at': DateTime.now().toIso8601String(),
      })
          .eq('code', activationCode);

      // ── Récupère l'ID du thème démo (Pokémon) ─────────────────────
      final demoThemeId = await DemoThemeMemory.read();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameHomePage(demoThemeId: demoThemeId),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
            Positioned(
              top: -60, right: -40,
              child: _GlowBlob(size: 220, color: _yellow.withOpacity(0.10)),
            ),
            Positioned(
              bottom: 120, left: -50,
              child: _GlowBlob(size: 180, color: _bgLight.withOpacity(0.15)),
            ),
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),

                      // Logo
                      _LogoCompact(),
                      const SizedBox(height: 24),

                      const Text(
                        "Rejoins l'aventure !",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Quelques secondes et tu es dans la partie",
                        style: TextStyle(fontSize: 14, color: _textSub),
                      ),
                      const SizedBox(height: 32),

                      // ── Formulaire ─────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Section 1 : Identité ───────
                            _SectionHeader(
                              label: "Ton identité",
                              icon: Icons.person_outline_rounded,
                              color: _yellow,
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const _TLabel("Prénom"),
                                      const SizedBox(height: 6),
                                      _TField(
                                        controller: firstNameController,
                                        focusNode: _firstNameFocus,
                                        hint: "Jean",
                                        prefixIcon:
                                        Icons.person_outline_rounded,
                                        textInputAction: TextInputAction.next,
                                        onSubmitted: (_) =>
                                            _lastNameFocus.requestFocus(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const _TLabel("Nom"),
                                      const SizedBox(height: 6),
                                      _TField(
                                        controller: lastNameController,
                                        focusNode: _lastNameFocus,
                                        hint: "Dupont",
                                        prefixIcon: Icons.badge_outlined,
                                        textInputAction: TextInputAction.next,
                                        onSubmitted: (_) =>
                                            _emailFocus.requestFocus(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const _TLabel("Email"),
                            const SizedBox(height: 6),
                            _TField(
                              controller: emailController,
                              focusNode: _emailFocus,
                              hint: "ton@email.com",
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.mail_outline_rounded,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _codeIsLocked
                                  ? _passwordFocus.requestFocus()
                                  : _codeFocus.requestFocus(),
                            ),

                            const SizedBox(height: 28),

                            // ── Section 2 : Code d'activation ─
                            _SectionHeader(
                              label: "Code d'activation",
                              icon: Icons.qr_code_rounded,
                              color: _yellow,
                            ),
                            const SizedBox(height: 10),

                            // Bannière différente selon état du code
                            if (_codeIsLocked)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: _successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _successColor.withOpacity(0.3),
                                      width: 1),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.check_circle_rounded,
                                        color: _successColor, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Code validé — ton accès est confirmé !",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _successColor,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: _yellow.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _yellow.withOpacity(0.25),
                                      width: 1),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline_rounded,
                                        color: _yellow, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Retrouve ce code sous le QR Code de ta boîte Touchly",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: _textSub,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 12),
                            const _TLabel("Code unique"),
                            const SizedBox(height: 6),

                            // Champ code — verrouillé si pré-rempli
                            TextField(
                              controller: uniqueCodeController,
                              focusNode: _codeFocus,
                              readOnly: _codeIsLocked,
                              textCapitalization:
                              TextCapitalization.characters,
                              textInputAction: _codeIsLocked
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              onSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                              inputFormatters: _codeIsLocked
                                  ? []
                                  : [
                                TextInputFormatter.withFunction(
                                        (old, n) => n.copyWith(
                                        text: n.text.toUpperCase())),
                              ],
                              style: TextStyle(
                                color: _codeIsLocked
                                    ? _successColor
                                    : _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: _codeIsLocked ? 2 : 0,
                              ),
                              cursorColor: _yellow,
                              decoration: InputDecoration(
                                hintText: 'ABCD-1234',
                                hintStyle: const TextStyle(
                                    color: _textSub, fontSize: 14),
                                filled: true,
                                fillColor: _codeIsLocked
                                    ? _successColor.withOpacity(0.07)
                                    : _bgDark,
                                prefixIcon: Icon(
                                  _codeIsLocked
                                      ? Icons.check_circle_rounded
                                      : Icons.key_outlined,
                                  color: _codeIsLocked
                                      ? _successColor
                                      : _textSub,
                                  size: 20,
                                ),
                                suffixIcon: _codeIsLocked
                                    ? const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Icon(Icons.lock_rounded,
                                      color: _successColor, size: 18),
                                )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _codeIsLocked
                                        ? _successColor.withOpacity(0.4)
                                        : _surfaceBorder,
                                    width: _codeIsLocked ? 1.5 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _codeIsLocked
                                        ? _successColor
                                        : _yellow,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Section 3 : Sécurité ───────────
                            _SectionHeader(
                              label: "Sécurité",
                              icon: Icons.lock_outline_rounded,
                              color: _yellow,
                            ),
                            const SizedBox(height: 12),

                            const _TLabel("Mot de passe"),
                            const SizedBox(height: 6),
                            _TField(
                              controller: passwordController,
                              focusNode: _passwordFocus,
                              hint: "Min. 6 caractères",
                              obscureText: _obscurePass,
                              prefixIcon: Icons.lock_outline_rounded,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _confirmFocus.requestFocus(),
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _textSub,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePass = !_obscurePass),
                              ),
                            ),

                            if (passwordController.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _PasswordStrengthBar(
                                strength: _passwordStrength,
                                label: _strengthLabel,
                                color: _strengthColor,
                              ),
                            ],

                            const SizedBox(height: 16),
                            const _TLabel("Confirmer le mot de passe"),
                            const SizedBox(height: 6),
                            _TField(
                              controller: confirmPasswordController,
                              focusNode: _confirmFocus,
                              hint: "••••••••",
                              obscureText: _obscureConfirm,
                              prefixIcon: Icons.shield_outlined,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                              isLoading ? null : createAccount(),
                              suffix: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (confirmPasswordController
                                      .text.isNotEmpty)
                                    Icon(
                                      _passwordsMatch
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.cancel_outlined,
                                      color: _passwordsMatch
                                          ? _successColor
                                          : _errorColor,
                                      size: 18,
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _textSub,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() =>
                                    _obscureConfirm = !_obscureConfirm),
                                  ),
                                ],
                              ),
                            ),

                            if (errorMessage != null) ...[
                              const SizedBox(height: 20),
                              _ErrorBanner(message: errorMessage!),
                            ],

                            const SizedBox(height: 24),

                            _AnimatedButton(
                              label: "Créer mon compte",
                              isLoading: isLoading,
                              btnCtrl: _btnCtrl,
                              btnScale: _btnScale,
                              onTap: isLoading ? null : createAccount,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Déjà un compte ? ",
                            style: TextStyle(color: _textSub, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage()),
                            ),
                            child: const Text(
                              "Se connecter",
                              style: TextStyle(
                                color: _yellow,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                    ],
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
//  Widgets
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

class _LogoCompact extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _yellow.withOpacity(0.25),
                  blurRadius: 60, spreadRadius: 10),
              BoxShadow(
                  color: Colors.white.withOpacity(0.06),
                  blurRadius: 40, spreadRadius: 5),
            ],
          ),
        ),
        Image.asset(
          'lib/assets/images/logo_touchly.png',
          width: 180,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.8,
          )),
      const SizedBox(width: 10),
      Expanded(
          child: Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.15))),
    ],
  );
}

class _TLabel extends StatelessWidget {
  final String text;
  const _TLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600,
      color: _textSub, letterSpacing: 0.3,
    ),
  );
}

class _TField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  const _TField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    required this.prefixIcon,
    this.suffix,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    obscureText: obscureText,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onSubmitted: onSubmitted,
    inputFormatters: inputFormatters,
    style: const TextStyle(
        color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
    cursorColor: _yellow,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSub, fontSize: 14),
      filled: true,
      fillColor: _bgDark,
      prefixIcon: Icon(prefixIcon, color: _textSub, size: 20),
      suffixIcon: suffix,
      contentPadding:
      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _surfaceBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _yellow, width: 1.5),
      ),
    ),
  );
}

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  final String label;
  final Color color;
  const _PasswordStrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: List.generate(4, (i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: i < strength
                  ? color
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ],
  );
}

class _AnimatedButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final AnimationController btnCtrl;
  final Animation<double> btnScale;
  final VoidCallback? onTap;

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
      onTapDown: (_) => btnCtrl.forward(),
      onTapUp: (_) { btnCtrl.reverse(); onTap?.call(); },
      onTapCancel: () => btnCtrl.reverse(),
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isLoading
              ? null
              : const LinearGradient(
              colors: [_yellow, Color(0xFFFFB300)]),
          color: isLoading ? _surfaceBorder : null,
          boxShadow: isLoading
              ? null
              : [BoxShadow(
              color: _yellow.withOpacity(0.4),
              blurRadius: 24, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _textPrimary))
              : Text(label,
              style: const TextStyle(
                color: _navy, fontSize: 16,
                fontWeight: FontWeight.w900, letterSpacing: 0.3,
              )),
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
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: _errorColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: _errorColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}