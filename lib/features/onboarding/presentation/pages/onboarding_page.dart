import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchly/features/onboarding/presentation/pages/demo_flow.dart';
import 'package:touchly/features/onboarding/presentation/pages/login_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/register_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/rules_settings_page.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgBottom    = Color(0xFF060E30);
const _bgMid       = Color(0xFF0A2A6E);
const _bgTop       = Color(0xFF1A5AE8);
const _yellow      = Color(0xFFFFD700);
const _yellowLight = Color(0xFFFFF176);
const _navy        = Color(0xFF0A1A4E);
const _textPrimary = Color(0xFFFFFFFF);
const _textSub     = Color(0xFFB3C8F0);
// ─────────────────────────────────────────────

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgMid, _bgBottom],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Lueurs de fond ─────────────────
            Positioned(
              top: -80, left: -80,
              child: _GlowBlob(size: 300,
                  color: _yellow.withOpacity(0.06)),
            ),
            Positioned(
              top: -40, right: -60,
              child: _GlowBlob(size: 260,
                  color: const Color(0xFF2979FF).withOpacity(0.15)),
            ),
            Positioned(
              bottom: 100, left: -60,
              child: _GlowBlob(size: 220,
                  color: _yellow.withOpacity(0.04)),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── LOGO — grande zone haut ────────
                  Expanded(
                    flex: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),

                        // Logo Touchly — très grand
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow jaune derrière
                              Container(
                                width: size.width * 1.0,
                                height: size.width * 0.65,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _yellow.withOpacity(0.18),
                                      blurRadius: 80,
                                      spreadRadius: 20,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF2979FF)
                                          .withOpacity(0.2),
                                      blurRadius: 60,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              Image.asset(
                                'lib/assets/images/logo_touchly.png',
                                width: size.width * 1.0,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Slogan style Hitster
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _yellow.withOpacity(0.5), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                            color: _yellow.withOpacity(0.06),
                          ),
                          child: const Text(
                            'LE JEU DES GRANDES SOIRÉES',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── ILLUSTRATION centrale ──────────
                  Expanded(
                    flex: 25,
                    child: Center(
                      child: _IllustrationCentrale(pulseAnim: _pulseAnim),
                    ),
                  ),

                  // ── BOUTONS bas ────────────────────
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        // Bouton principal jaune
                        _MainButton(
                          label: 'JOUER MAINTENANT',
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DemoGamePage(onUnlock: () {
                                    // Navigue vers ta page d'activation
                                    Navigator.pushReplacement(context, MaterialPageRoute(
                                      builder: (_) => const RegisterPage(),
                                    ));
                                  })),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Bouton secondaire
                        _SecondaryButton(
                          label: 'RÈGLES & PARAMÈTRES',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RulesSettingsPage()),
                            );
                          },
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Illustration centrale — cartes de jeu stylisées
//  (remplace le haut-parleur Hitster par quelque
//   chose de cohérent avec Touchly)
// ─────────────────────────────────────────────
class _IllustrationCentrale extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _IllustrationCentrale({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width * 0.52;

    return SizedBox(
      width: size.width,
      height: size.width * 0.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo central
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: cardW * pulseAnim.value,
              height: cardW * pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _yellow.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Carte gauche inclinée
          Positioned(
            left: size.width * 0.04,
            child: Transform.rotate(
              angle: -0.22,
              child: _GameCard(
                emoji: '🎬',
                label: 'Cinéma',
                accent: const Color(0xFF6366F1),
                width: cardW * 0.72,
              ),
            ),
          ),

          // Carte droite inclinée
          Positioned(
            right: size.width * 0.04,
            child: Transform.rotate(
              angle: 0.22,
              child: _GameCard(
                emoji: '⚽',
                label: 'Sport',
                accent: const Color(0xFF10B981),
                width: cardW * 0.72,
              ),
            ),
          ),

          // Carte centrale — au premier plan
          _GameCard(
            emoji: '🌍',
            label: 'Culture G',
            accent: _yellow,
            width: cardW,
            elevated: true,
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color accent;
  final double width;
  final bool elevated;

  const _GameCard({
    required this.emoji,
    required this.label,
    required this.accent,
    required this.width,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.all(width * 0.12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3A8E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(elevated ? 0.6 : 0.25),
          width: elevated ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(elevated ? 0.3 : 0.1),
            blurRadius: elevated ? 30 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: width * 0.22)),
          SizedBox(height: width * 0.06),
          Text(
            label,
            style: TextStyle(
              color: _textPrimary,
              fontSize: width * 0.11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: width * 0.04),
          Container(
            width: width * 0.4,
            height: 2,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Boutons
// ─────────────────────────────────────────────
class _MainButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _MainButton({required this.label, required this.onTap});

  @override
  State<_MainButton> createState() => _MainButtonState();
}

class _MainButtonState extends State<_MainButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
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
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_yellow, Color(0xFFFFB300)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _yellow.withOpacity(0.5),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                color: _navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Colors.white.withOpacity(0.18), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Utilitaire
// ─────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
    ),
  );
}