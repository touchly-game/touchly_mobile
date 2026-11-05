import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/features/onboarding/presentation/pages/demo_theme_memory.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_mode_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_play_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/login_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/player_setup_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/points_service.dart';
import 'package:touchly/features/onboarding/presentation/pages/progression_card.dart';
import 'package:touchly/features/onboarding/presentation/pages/review_request_dialog.dart';
import 'package:touchly/features/onboarding/presentation/pages/theme_store_page.dart';
import 'package:touchly/core/models/app_theme.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgDark        = Color(0xFF0A2A6E);
const _bgMid         = Color(0xFF1155CC);
const _bgLight       = Color(0xFF2979FF);
const _surface       = Color(0xFF0B3080);
const _surfaceBorder = Color(0xFF1A4DB5);
const _yellow        = Color(0xFFFFD700);
const _navy          = Color(0xFF0A1A4E);
const _textPrimary   = Color(0xFFFFFFFF);
const _textSub       = Color(0xFFB3C8F0);

// ─────────────────────────────────────────────
//  GameHomePage
// ─────────────────────────────────────────────
class GameHomePage extends StatefulWidget {
  /// ID du thème joué pendant la démo — affiché en priorité dans le hero.
  /// Optionnel : si non fourni (cas le plus courant après un parcours
  /// d'inscription classique), on retombe automatiquement sur la valeur
  /// mémorisée localement via DemoThemeMemory.
  final String? demoThemeId;

  const GameHomePage({super.key, this.demoThemeId});

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage> {
  List<AppTheme> _userThemes    = [];
  AppTheme?      _demoTheme;
  bool           _loading        = true;
  String         _firstName      = '';
  String         _lastName       = '';
  int            _totalQuestions = 0;
  UserPoints _points = UserPoints.zero;


  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserThemes();
    _loadPoints();
    _resolveDemoTheme();
    ReviewRequestService.maybeShow(context);
  }

  // ── Profil ────────────────────────────────────
  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ Aucun utilisateur connecté au moment du chargement du profil');
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('app_users')
          .select('first_name, last_name')
          .eq('id', user.id)
          .maybeSingle();

      debugPrint('🔍 Profil chargé: $data');

      if (mounted) {
        setState(() {
          if (data != null) {
            _firstName = (data['first_name'] as String?)?.trim() ?? '';
            _lastName  = (data['last_name']  as String?)?.trim() ?? '';
          } else {
            _firstName = user.email?.split('@').first ?? '';
            _lastName  = '';
          }
        });
      }
    } catch (e, st) {
      debugPrint('❌ Error loading profile: $e');
      debugPrint('$st');
    }
  }

  Future<void> _loadPoints() async {
    final points = await PointsService.fetchCurrentUserPoints();
    if (mounted) setState(() => _points = points);
  }


  Future<void> _loadUserThemes() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final ids = await Supabase.instance.client
          .from('user_themes')
          .select('theme_id')
          .eq('user_id', user.id) as List;

      if (ids.isNotEmpty) {
        final themeIds = ids.map((e) => e['theme_id'] as String).toList();
        final themes = await Supabase.instance.client
            .from('themes').select('*').inFilter('id', themeIds) as List;
        if (mounted) {
          setState(() => _userThemes = themes
              .map((e) => AppTheme.fromMap(e as Map<String, dynamic>))
              .toList());
        }
        final qCount = await Supabase.instance.client
            .from('questions').select('id').inFilter('theme_id', themeIds) as List;
        if (mounted) setState(() => _totalQuestions = qCount.length);
      } else {
        if (mounted) setState(() => _userThemes = []);
      }
    } catch (e) {
      debugPrint('Error loading themes: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Résolution du thème démo ───────────────────
  /// Priorité 1 : le paramètre `demoThemeId` transmis directement.
  /// Priorité 2 : la valeur mémorisée localement pendant la démo,
  ///              qui survit peu importe le nombre d'écrans traversés
  ///              entre la démo et l'arrivée ici (inscription, activation...).
  Future<void> _resolveDemoTheme() async {
    debugPrint('🔍 demoThemeId reçu en paramètre: ${widget.demoThemeId}');

    String? themeId = widget.demoThemeId;
    themeId ??= await DemoThemeMemory.read();

    debugPrint('🔍 demoThemeId résolu (paramètre ou mémoire locale): $themeId');

    if (themeId != null) {
      await _loadDemoTheme(themeId);
    }
  }

  Future<void> _loadDemoTheme(String themeId) async {
    try {
      final data = await Supabase.instance.client
          .from('themes')
          .select('*')
          .eq('id', themeId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _demoTheme =
            AppTheme.fromMap(data as Map<String, dynamic>));
        debugPrint('✅ _demoTheme set: ${_demoTheme?.name}');
      }
    } catch (e) {
      debugPrint('❌ Error loading demo theme: $e');
    }
  }

  // ── Navigation ────────────────────────────────
  Future<void> _logout() async {
    ReviewRequestService.resetSession();
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
      );
    }
  }

  void _startGame(AppTheme theme, {int startQuestionIndex = 0}) {
    if (_demoTheme != null && theme.id == _demoTheme!.id) {
      DemoThemeMemory.clear();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerSetupPage(
          catchUpRounds: startQuestionIndex,
          onReady: (session) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => GamePlayPage(
                  theme: theme,
                  startQuestionIndex: startQuestionIndex,
                  session: session,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openThemeStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThemeStorePage(onPurchase: _loadUserThemes),
      ),
    );
  }

  void _openGiftPhysicalGame() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Boutique physique bientôt disponible !')),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final displayName = [_firstName, _lastName]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final initials = [
      if (_firstName.isNotEmpty) _firstName[0],
      if (_lastName.isNotEmpty)  _lastName[0],
    ].join().toUpperCase();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1A5AE8),
              Color(0xFF0A2A6E),
              Color(0xFF060E30),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: -60, right: -40,
            child: _GlowBlob(size: 220, color: _yellow.withOpacity(0.12)),
          ),
          Positioned(
            bottom: 120, left: -50,
            child: _GlowBlob(size: 180, color: _bgLight.withOpacity(0.18)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── TopBar ─────────────────────────────
                  _TopBar(
                    displayName: displayName,
                    initials: initials.isEmpty ? '?' : initials,
                    onLogout: _logout,
                  ),
                  const SizedBox(height: 24),

                  // ── Hero ───────────────────────────────
                  _HeroCard(
                    lastTheme:     _userThemes.isNotEmpty ? _userThemes.last : null,
                    demoTheme:     _demoTheme,
                    themeCount:    _userThemes.length,
                    questionCount: _totalQuestions,
                    hasNewTheme:   true,
                    newThemeName:  'Pokémon',
                    onPlay: _userThemes.isNotEmpty
                        ? () => _startGame(_userThemes.last)
                        : _openThemeStore,
                    onResumeDemoTheme: () {
                      if (_demoTheme != null) {
                        _startGame(_demoTheme!, startQuestionIndex: 3);
                      }
                    },
                    onStore: _openThemeStore,
                  ),
                  const SizedBox(height: 28),

                  const SizedBox(height: 16),
                  ProgressionCard(points: _points),
                  const SizedBox(height: 28),

                  // ── Mes thèmes ─────────────────────────
                  const _SectionLabel(text: 'Mes thèmes'),
                  const SizedBox(height: 12),

                  if (_loading)
                    const _LoadingState()
                  else if (_userThemes.isEmpty)
                    _EmptyThemesCard(onDiscover: _openThemeStore)
                  else
                    ..._userThemes.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ThemeRow(
                        theme: t,
                        onTap: () => _startGame(t),
                      ),
                    )),

                  const SizedBox(height: 28),

                  // ── Explorer ───────────────────────────
                  const _SectionLabel(text: 'Explorer'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _NavCard(
                        label:    'Thèmes',
                        sublabel: 'Nouveaux packs',
                        emoji:    '💎',
                        color:    const Color(0xFF7C3AED),
                        onTap:    _openThemeStore,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NavCard(
                        label:    'Modes de jeu',
                        sublabel: 'Découvre les règles',
                        emoji:    '🎲',
                        color:    _yellow,
                        onTap:    () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GameModesPage()),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _GiftPhysicalGameLink(onTap: _openGiftPhysicalGame),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _HeroCard
// ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final AppTheme?   lastTheme;
  final AppTheme?   demoTheme;
  final int         themeCount;
  final int         questionCount;
  final bool        hasNewTheme;
  final String?     newThemeName;
  final VoidCallback  onPlay;
  final VoidCallback? onResumeDemoTheme;
  final VoidCallback  onStore;

  const _HeroCard({
    required this.lastTheme,
    this.demoTheme,
    required this.themeCount,
    required this.questionCount,
    required this.hasNewTheme,
    this.newThemeName,
    required this.onPlay,
    this.onResumeDemoTheme,
    required this.onStore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(children: [

          if (demoTheme != null && onResumeDemoTheme != null)
            _DemoResumeBanner(
              theme:    demoTheme!,
              onResume: onResumeDemoTheme!,
            )
          else if (lastTheme != null)
            _LastThemeBanner(theme: lastTheme!, onPlay: onPlay)
          else
            _EmptyBanner(
              onStore: onStore,
              demoTheme: demoTheme,
              onResumeDemoTheme: onResumeDemoTheme,
            ),

          Container(
            decoration: BoxDecoration(
              border: Border(
                top:    BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
                bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
              ),
            ),
            child: Row(children: [
              Expanded(child: _StatCell(
                  value: '$themeCount', label: 'Thèmes débloqués')),
              Container(width: 1, height: 48,
                  color: Colors.white.withOpacity(0.06)),
              Expanded(child: _StatCell(
                  value: '$questionCount', label: 'Questions dispo')),
            ]),
          ),

          if (hasNewTheme && newThemeName != null)
            _PromoBar(themeName: newThemeName!, onTap: onStore),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _DemoResumeBanner
// ─────────────────────────────────────────────
class _DemoResumeBanner extends StatelessWidget {
  final AppTheme     theme;
  final VoidCallback onResume;
  const _DemoResumeBanner({required this.theme, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.18),
            const Color(0xFFFF8C00).withOpacity(0.10),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _yellow.withOpacity(0.35), width: 1),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('⚡', style: TextStyle(fontSize: 11)),
              SizedBox(width: 5),
              Text(
                'TU AS DÉJÀ JOUÉ CE THÈME',
                style: TextStyle(
                  color: _yellow, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: 0.8,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          Row(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _yellow.withOpacity(0.35), width: 1.5),
              ),
              child: Center(
                child: theme.imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(theme.imageUrl!,
                      width: 42, height: 42, fit: BoxFit.cover),
                )
                    : Text(theme.emoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.name,
                    style: const TextStyle(
                      color: _textPrimary, fontSize: 18,
                      fontWeight: FontWeight.w900, letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Continue à la question 4 — tu es lancé ! 🔥',
                    style: TextStyle(
                        color: _textSub, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 14),

          Row(children: [
            const Text(
              '3 questions faites en démo',
              style: TextStyle(
                  color: _textSub, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Text(
              'Continue !',
              style: TextStyle(
                  color: _yellow, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 3 / 15,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(_yellow),
            ),
          ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: onResume,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_yellow, Color(0xFFFFB300)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: _yellow.withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 5),
                )],
              ),
              child: const Center(
                child: Text(
                  '▶  Reprendre à la question 4',
                  style: TextStyle(
                    color: _navy, fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lien "Offrir le jeu physique" ──────────────
class _GiftPhysicalGameLink extends StatelessWidget {
  final VoidCallback onTap;
  const _GiftPhysicalGameLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎁', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                'Offrir le jeu physique Touchly',
                style: TextStyle(
                  color: _textSub.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _textSub.withOpacity(0.3),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded,
                  color: _textSub.withOpacity(0.6), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widgets existants (inchangés)
// ─────────────────────────────────────────────

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color  color;
  const _GlowBlob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ── TopBar ────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String       displayName;
  final String       initials;
  final VoidCallback onLogout;
  const _TopBar({
    required this.displayName,
    required this.initials,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Row(children: [
        Container(
          width: 100, height: 100,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: _yellow.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: _yellow.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Image.asset(
            'lib/assets/images/logo_touchly.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
      ]),
      const Spacer(),

      GestureDetector(
        onTap: () => _showLogoutDialog(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_yellow, Color(0xFFFFB300)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: initials.isNotEmpty
                    ? Text(initials, style: const TextStyle(
                    color: _navy, fontSize: 12, fontWeight: FontWeight.w900))
                    : const Icon(Icons.person_rounded, color: _navy, size: 16),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              displayName.isNotEmpty ? displayName : 'Joueur',
              style: const TextStyle(
                  color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ),
    ]);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D3A8E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Se déconnecter ?',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800)),
        content: const Text('Tu vas quitter la session.',
            style: TextStyle(color: _textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: _textSub)),
          ),
          GestureDetector(
            onTap: () { Navigator.pop(context); onLogout(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
              ),
              child: const Text('Se déconnecter',
                  style: TextStyle(
                      color: Color(0xFFFF6B6B), fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bannière dernier thème ────────────────────
class _LastThemeBanner extends StatelessWidget {
  final AppTheme     theme;
  final VoidCallback onPlay;
  const _LastThemeBanner({required this.theme, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withOpacity(0.35),
            const Color(0xFF6366F1).withOpacity(0.25),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: theme.imageUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(theme.imageUrl!,
                  width: 40, height: 40, fit: BoxFit.cover),
            )
                : Text(theme.emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DERNIER THÈME DÉBLOQUÉ', style: TextStyle(
              color: _textSub.withOpacity(0.7), fontSize: 9,
              fontWeight: FontWeight.w800, letterSpacing: 1.2,
            )),
            const SizedBox(height: 3),
            Text(theme.name, style: const TextStyle(
              color: _textPrimary, fontSize: 16,
              fontWeight: FontWeight.w900, letterSpacing: -0.3,
            )),
          ]),
        ),
        GestureDetector(
          onTap: onPlay,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_yellow, Color(0xFFFFB300)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                color: _yellow.withOpacity(0.35),
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _navy),
                child: const Center(
                  child: Icon(Icons.play_arrow_rounded, color: _yellow, size: 11),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Jouer', style: TextStyle(
                  color: _navy, fontSize: 13, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _EmptyBanner extends StatelessWidget {
  final VoidCallback  onStore;
  final AppTheme?     demoTheme;
  final VoidCallback? onResumeDemoTheme;

  const _EmptyBanner({
    required this.onStore,
    this.demoTheme,
    this.onResumeDemoTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (demoTheme != null && onResumeDemoTheme != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7C3AED).withOpacity(0.22),
              const Color(0xFF2979FF).withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF7C3AED).withOpacity(0.4), width: 1),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🎮', style: TextStyle(fontSize: 10)),
                  SizedBox(width: 5),
                  Text('DÉMO TERMINÉE',
                      style: TextStyle(
                        color: Color(0xFFB39DFF), fontSize: 9,
                        fontWeight: FontWeight.w900, letterSpacing: 0.9,
                      )),
                ]),
              ),
            ]),

            const SizedBox(height: 14),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withOpacity(0.4), width: 1.5),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.25),
                      blurRadius: 16, offset: const Offset(0, 4),
                    )],
                  ),
                  child: Center(
                    child: demoTheme!.imageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(demoTheme!.imageUrl!,
                          width: 44, height: 44, fit: BoxFit.cover),
                    )
                        : Text(demoTheme!.emoji,
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
                Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                  child: const Center(
                    child: Text('3', style: TextStyle(
                        color: _textPrimary, fontSize: 9,
                        fontWeight: FontWeight.w900)),
                  ),
                ),
              ]),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      demoTheme!.name,
                      style: const TextStyle(
                        color: _textPrimary, fontSize: 17,
                        fontWeight: FontWeight.w900, letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            color: _textSub, fontSize: 12, height: 1.45),
                        children: [
                          TextSpan(text: 'Tu as joué 3 questions en démo.\n'),
                          TextSpan(
                            text: 'Continue où tu t\'es arrêté 🔥',
                            style: TextStyle(
                                color: Color(0xFFB39DFF),
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 3 / 15,
                    minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF7C3AED)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text('3 / 15',
                  style: TextStyle(
                      color: Color(0xFFB39DFF),
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ]),

            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: onResumeDemoTheme,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.4),
                        blurRadius: 14, offset: const Offset(0, 4),
                      )],
                    ),
                    child: const Center(
                      child: Text('▶  Reprendre Q.4',
                          style: TextStyle(
                            color: _textPrimary, fontSize: 13,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onStore,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.12), width: 1),
                    ),
                    child: const Center(
                      child: Text('+ Thèmes',
                          style: TextStyle(
                            color: _textSub, fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: _yellow.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: _yellow.withOpacity(0.2), width: 1.5),
          ),
          child: const Center(child: Text('🎲', style: TextStyle(fontSize: 26))),
        ),
        const SizedBox(height: 12),
        const Text('Prêt à jouer ?', style: TextStyle(
            color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Débloque un thème pour commencer',
            style: TextStyle(color: _textSub, fontSize: 12)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onStore,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_yellow, const Color(0xFFFFB300)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: _yellow.withOpacity(0.35),
                  blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: const Text('🚀  Explorer les thèmes',
                style: TextStyle(
                    color: _navy, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }
}

// ── Cellule stat ──────────────────────────────
class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      color: const Color(0xFF0A2A6E).withOpacity(0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(
          color: _yellow, fontSize: 22,
          fontWeight: FontWeight.w900, height: 1,
        )),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          color: _textSub.withOpacity(0.7),
          fontSize: 11, fontWeight: FontWeight.w600,
        )),
      ]),
    );
  }
}

// ── Barre promo nouveau thème ─────────────────
class _PromoBar extends StatelessWidget {
  final String       themeName;
  final VoidCallback onTap;
  const _PromoBar({required this.themeName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: _yellow.withOpacity(0.06),
          border: Border(top: BorderSide(color: _yellow.withOpacity(0.12), width: 1)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _yellow.withOpacity(0.3), width: 1),
            ),
            child: const Text('✨ NOUVEAU', style: TextStyle(
              color: _yellow, fontSize: 9,
              fontWeight: FontWeight.w900, letterSpacing: 0.5,
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pack $themeName disponible dans la boutique !',
              style: TextStyle(
                  color: _textPrimary.withOpacity(0.75),
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded,
              color: _yellow.withOpacity(0.7), size: 16),
        ]),
      ),
    );
  }
}

// ── Section label ─────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: _textSub, fontSize: 11,
      fontWeight: FontWeight.w800, letterSpacing: 1.8,
    ),
  );
}

// ── Loading ───────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      SizedBox(
        width: 32, height: 32,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: _yellow),
      ),
      SizedBox(height: 14),
      Text('Chargement...', style: TextStyle(color: _textSub, fontSize: 14)),
    ]),
  );
}

// ── Empty themes ──────────────────────────────
class _EmptyThemesCard extends StatelessWidget {
  final VoidCallback onDiscover;
  const _EmptyThemesCard({required this.onDiscover});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(children: [
        const Text('🎁', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 10),
        const Text('Aucun thème pour le moment', style: TextStyle(
          color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 6),
        const Text('Ajoute des thèmes pour commencer à jouer',
            style: TextStyle(color: _textSub, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: onDiscover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _yellow.withOpacity(0.3)),
            ),
            child: const Text('🚀  Voir les thèmes', style: TextStyle(
              color: _yellow, fontSize: 14, fontWeight: FontWeight.w800,
            )),
          ),
        ),
      ]),
    );
  }
}

// ── Theme row ─────────────────────────────────
class _ThemeRow extends StatelessWidget {
  final AppTheme     theme;
  final VoidCallback onTap;
  const _ThemeRow({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: theme.imageUrl != null
                ? Image.network(theme.imageUrl!,
                width: 52, height: 52, fit: BoxFit.cover)
                : Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(theme.emoji,
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(theme.name, style: const TextStyle(
                color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w800,
              )),
              if (theme.description != null) ...[
                const SizedBox(height: 2),
                Text(theme.description!, style: const TextStyle(
                    color: _textSub, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _yellow.withOpacity(0.3), width: 1),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded, color: _yellow, size: 16),
              SizedBox(width: 4),
              Text('Jouer', style: TextStyle(
                  color: _yellow, fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Nav card ──────────────────────────────────
class _NavCard extends StatelessWidget {
  final String       label;
  final String       sublabel;
  final String       emoji;
  final Color        color;
  final VoidCallback onTap;

  const _NavCard({
    required this.label,
    required this.sublabel,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(
              color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sublabel, style: const TextStyle(color: _textSub, fontSize: 11)),
        ]),
      ),
    );
  }
}