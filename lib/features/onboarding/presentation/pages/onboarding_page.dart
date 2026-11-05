import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/core/models/app_theme.dart';
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

/// Noms des thèmes éligibles à la démo, dans l'ordre d'affichage voulu.
/// Modifie cette liste si tu veux ajouter/retirer des thèmes du carrousel.
const List<String> _demoThemeNames = [
  'Sport & Champions',
  'Science & Nature',
  'Pokémon',
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // ── Carrousel de thèmes ────────────────────
  late final PageController _pageController;
  List<AppTheme> _themes        = [];
  bool           _loadingThemes = true;
  String?        _themesError;
  double         _currentPage   = 0; // valeur continue (pour l'animation)
  int            _selectedIndex = 0; // index arrondi = thème sélectionné

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

    _pageController = PageController(viewportFraction: 0.72)
      ..addListener(_onPageScroll);

    _loadThemes();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients || !_pageController.position.haveDimensions) return;
    setState(() => _currentPage = _pageController.page ?? 0);
  }

  Future<void> _loadThemes() async {
    setState(() { _loadingThemes = true; _themesError = null; });
    try {
      final data = await Supabase.instance.client
          .from('themes')
          .select('*')
          .inFilter('name', _demoThemeNames)
          .eq('is_active', true) as List;

      final fetched = data
          .map((e) => AppTheme.fromMap(e as Map<String, dynamic>))
          .toList();

      // Réordonne selon _demoThemeNames pour un affichage prévisible,
      // peu importe l'ordre renvoyé par Supabase.
      fetched.sort((a, b) => _demoThemeNames
          .indexOf(a.name)
          .compareTo(_demoThemeNames.indexOf(b.name)));

      if (mounted) {
        setState(() {
          _themes = fetched;
          _loadingThemes = false;
          if (_themes.isEmpty) {
            _themesError = 'Aucun thème disponible pour le moment.';
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement thèmes carrousel: $e');
      if (mounted) {
        setState(() {
          _loadingThemes = false;
          _themesError = 'Impossible de charger les thèmes.';
        });
      }
    }
  }

  void _startDemo() {
    if (_themes.isEmpty) return;
    HapticFeedback.mediumImpact();
    final theme = _themes[_selectedIndex.clamp(0, _themes.length - 1)];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DemoGamePage(
          themeId: theme.id,
          themeName: theme.name,
          onUnlock: () {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => const RegisterPage(),
            ));
          },
        ),
      ),
    );
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
                  // ── LOGO ────────────────────────
                  Expanded(
                    flex: 52,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: size.width * 0.9,
                                height: size.width * 0.55,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _yellow.withOpacity(0.18),
                                      blurRadius: 70,
                                      spreadRadius: 16,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF2979FF)
                                          .withOpacity(0.2),
                                      blurRadius: 50,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              Image.asset(
                                'lib/assets/images/logo_touchly.png',
                                width: size.width * 0.9,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
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

                  // ── CARROUSEL DE THÈMES ─────────
                  Expanded(
                    flex: 33,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'CHOISIS TON THÈME POUR LA DÉMO',
                            style: TextStyle(
                              color: _textSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                        Expanded(child: _buildCarouselBody()),
                        const SizedBox(height: 10),
                        if (_themes.isNotEmpty)
                          _CarouselDots(
                            count: _themes.length,
                            currentPage: _currentPage,
                          ),
                      ],
                    ),
                  ),

                  // ── BOUTONS bas ─────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                    child: Column(
                      children: [
                        _MainButton(
                          label: 'JOUER MAINTENANT',
                          enabled: _themes.isNotEmpty,
                          onTap: _startDemo,
                        ),
                        const SizedBox(height: 14),
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

  Widget _buildCarouselBody() {
    if (_loadingThemes) {
      return const Center(
        child: SizedBox(
          width: 32, height: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _yellow),
        ),
      );
    }

    if (_themesError != null || _themes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _themesError ?? 'Aucun thème disponible.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSub, fontSize: 13),
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _themes.length,
      onPageChanged: (i) {
        HapticFeedback.selectionClick();
        setState(() => _selectedIndex = i);
      },
      itemBuilder: (context, index) {
        final theme = _themes[index];
        final delta = (_currentPage - index);
        final scale = (1 - delta.abs() * 0.22).clamp(0.78, 1.0);
        final angle = delta.clamp(-1.0, 1.0) * 0.12;
        final opacity = (1 - delta.abs() * 0.5).clamp(0.4, 1.0);

        return Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: _ThemeCarouselCard(
                theme: theme,
                isSelected: index == _selectedIndex,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Carte de thème du carrousel
// ─────────────────────────────────────────────
class _ThemeCarouselCard extends StatelessWidget {
  final AppTheme theme;
  final bool isSelected;
  const _ThemeCarouselCard({required this.theme, required this.isSelected});

  static const List<Color> _accents = [
    Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFEC4899),
    Color(0xFFF97316), Color(0xFF06B6D4),
  ];

  Color get _accent => _accents[theme.name.hashCode.abs() % _accents.length];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3A8E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected ? _yellow.withOpacity(0.7) : _accent.withOpacity(0.25),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? _yellow.withOpacity(0.3) : _accent.withOpacity(0.12),
            blurRadius: isSelected ? 30 : 14,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (theme.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                theme.imageUrl!,
                width: 54, height: 54, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Text(theme.emoji, style: const TextStyle(fontSize: 40)),
              ),
            )
          else
            Text(theme.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            theme.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 32, height: 3,
            decoration: BoxDecoration(
              color: isSelected ? _yellow : _accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _yellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _yellow.withOpacity(0.35), width: 1),
              ),
              child: const Text(
                'SÉLECTIONNÉ',
                style: TextStyle(
                  color: _yellow, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Indicateurs de pagination (dots)
// ─────────────────────────────────────────────
class _CarouselDots extends StatelessWidget {
  final int count;
  final double currentPage;
  const _CarouselDots({required this.count, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final distance = (currentPage - i).abs().clamp(0.0, 1.0);
        final width = 8 + (1 - distance) * 14;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: width,
          height: 8,
          decoration: BoxDecoration(
            color: Color.lerp(_textSub.withOpacity(0.3), _yellow, 1 - distance),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  Boutons
// ─────────────────────────────────────────────
class _MainButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _MainButton({required this.label, required this.onTap, this.enabled = true});

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
    final enabled = widget.enabled;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _ctrl.forward() : null,
        onTapUp: enabled ? (_) { _ctrl.reverse(); widget.onTap(); } : null,
        onTapCancel: enabled ? () => _ctrl.reverse() : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1.0 : 0.45,
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
              boxShadow: enabled
                  ? [
                BoxShadow(
                  color: _yellow.withOpacity(0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ]
                  : null,
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