// activation_code_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/features/onboarding/presentation/pages/register_page.dart';

const _bgDark        = Color(0xFF0A2A6E);
const _bgLight       = Color(0xFF2979FF);
const _surfaceBorder = Color(0xFF1A4DB5);
const _yellow        = Color(0xFFFFD700);
const _navy          = Color(0xFF0A1A4E);
const _white         = Color(0xFFFFFFFF);
const _textSub       = Color(0xFFB3C8F0);
const _successColor  = Color(0xFF3DD68C);
const _errorColor    = Color(0xFFFF5A7D);

class ActivationCodePage extends StatefulWidget {
  const ActivationCodePage({super.key});

  @override
  State<ActivationCodePage> createState() => _ActivationCodePageState();
}

class _ActivationCodePageState extends State<ActivationCodePage>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isValid   = false;
  String? _errorMessage;

  late final AnimationController _btnCtrl;
  late final Animation<double>   _btnScale;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _btnScale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));

    _codeController.addListener(() {
      // Reset état si l'utilisateur retape
      if (_isValid || _errorMessage != null) {
        setState(() { _isValid = false; _errorMessage = null; });
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Entre ton code d\'activation.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _isValid = false; });

    try {
      final res = await Supabase.instance.client
          .from('activation_codes')
          .select()
          .eq('code', code)
          .eq('is_used', false)
          .maybeSingle();

      if (!mounted) return;

      if (res == null) {
        setState(() => _errorMessage = 'Code invalide ou déjà utilisé.');
      } else {
        setState(() => _isValid = true);
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      setState(() => _errorMessage = 'Erreur réseau. Réessaie.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterPage(prefillCode: _codeController.text.trim().toUpperCase()),
      ),
    );
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
        child: Stack(children: [
          Positioned(top: -60, right: -40,
              child: _Blob(size: 220, color: _yellow.withOpacity(0.10))),
          Positioned(bottom: 120, left: -50,
              child: _Blob(size: 180, color: _bgLight.withOpacity(0.15))),

          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Bouton retour
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: _white, size: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Icône clé
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _yellow.withOpacity(0.12),
                        border: Border.all(color: _yellow.withOpacity(0.25), width: 2),
                        boxShadow: [BoxShadow(
                            color: _yellow.withOpacity(0.25),
                            blurRadius: 40, spreadRadius: 4)],
                      ),
                      child: const Center(
                          child: Text('🔑', style: TextStyle(fontSize: 38))),
                    ),
                    const SizedBox(height: 24),

                    const Text('Mon code d\'activation',
                        style: TextStyle(
                            color: _white, fontSize: 26,
                            fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    const Text(
                        'Entre le code unique situé\nsous le QR Code de ta boîte Touchly',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textSub, fontSize: 14, height: 1.5)),

                    const SizedBox(height: 40),

                    // Champ code
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isLoading ? null : _validateCode(),
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                                (old, n) => n.copyWith(text: n.text.toUpperCase())),
                      ],
                      style: TextStyle(
                        color: _isValid ? _successColor : _white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                      cursorColor: _yellow,
                      decoration: InputDecoration(
                        hintText: 'ABCD-1234',
                        hintStyle: const TextStyle(
                            color: _textSub, fontSize: 20, letterSpacing: 2),
                        filled: true,
                        fillColor: _isValid
                            ? _successColor.withOpacity(0.07)
                            : _bgDark,
                        prefixIcon: Icon(
                          _isValid
                              ? Icons.check_circle_rounded
                              : Icons.key_outlined,
                          color: _isValid ? _successColor : _textSub,
                          size: 22,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: _isValid
                                ? _successColor.withOpacity(0.5)
                                : _errorMessage != null
                                ? _errorColor.withOpacity(0.5)
                                : _surfaceBorder,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: _isValid ? _successColor : _yellow,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Message erreur / succès
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isValid
                          ? _Banner(
                        key: const ValueKey('ok'),
                        message: '✅  Code valide — tu peux créer ton compte !',
                        color: _successColor,
                      )
                          : _errorMessage != null
                          ? _Banner(
                        key: const ValueKey('err'),
                        message: _errorMessage!,
                        color: _errorColor,
                      )
                          : const SizedBox(key: ValueKey('empty'), height: 0),
                    ),

                    const SizedBox(height: 32),

                    // Bouton Vérifier / Créer mon compte
                    ScaleTransition(
                      scale: _btnScale,
                      child: GestureDetector(
                        onTapDown: (_) => _btnCtrl.forward(),
                        onTapUp: (_) {
                          _btnCtrl.reverse();
                          if (_isLoading) return;
                          _isValid ? _goToRegister() : _validateCode();
                        },
                        onTapCancel: () => _btnCtrl.reverse(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: _isLoading
                                ? null
                                : LinearGradient(
                              colors: _isValid
                                  ? [_successColor, const Color(0xFF22C55E)]
                                  : [_yellow, const Color(0xFFFFB300)],
                            ),
                            color: _isLoading ? _surfaceBorder : null,
                            boxShadow: _isLoading
                                ? null
                                : [BoxShadow(
                              color: (_isValid ? _successColor : _yellow)
                                  .withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            )],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: _white))
                                : Text(
                              _isValid
                                  ? '🚀  Créer mon compte'
                                  : 'Vérifier mon code',
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Widgets locaux ──────────────────────────────────────

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _Banner extends StatelessWidget {
  final String message;
  final Color color;
  const _Banner({super.key, required this.message, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.35), width: 1),
    ),
    child: Text(message,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
  );
}