import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/features/onboarding/presentation/pages/activation_code_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/demo_theme_memory.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgDark   = Color(0xFF0A2A6E);
const _bgLight  = Color(0xFF2979FF);
const _yellow   = Color(0xFFFFD700);
const _navy     = Color(0xFF0A1A4E);
const _white    = Color(0xFFFFFFFF);
const _textSub  = Color(0xFFB3C8F0);
const _correct  = Color(0xFF22C55E);
const _warn     = Color(0xFFFF6B35);
const _answerA  = Color(0xFF6366F1);
const _answerB  = Color(0xFF8B5CF6);
const _answerC  = Color(0xFFEC4899);
// ─────────────────────────────────────────────

// ── Modèle ────────────────────────────────────
class _DemoQ {
  final String id, questionText, answerA, answerB, answerC, correctAnswer;
  final String? anecdote;
  const _DemoQ({
    required this.id, required this.questionText,
    required this.answerA, required this.answerB,
    required this.answerC, required this.correctAnswer,
    this.anecdote,
  });
  factory _DemoQ.fromMap(Map<String, dynamic> m) => _DemoQ(
    id: m['id'] as String,
    questionText: m['question_text'] as String,
    answerA: m['answer_a'] as String,
    answerB: m['answer_b'] as String,
    answerC: m['answer_c'] as String,
    correctAnswer: m['correct_answer'] as String,
    anecdote: m['anecdote'] as String?,
  );
  String text(String l) {
    switch (l) { case 'A': return answerA; case 'B': return answerB; default: return answerC; }
  }
}

// ── State machine ─────────────────────────────
enum _DemoState { loading, readingQuestion, countdown, answering, timeUp, revealing, endDemo }

// ─────────────────────────────────────────────
//  DemoGamePage
// ─────────────────────────────────────────────
class DemoGamePage extends StatefulWidget {
  final VoidCallback onUnlock; // → ActivationCodePage

  /// ID du thème choisi dans le carrousel de l'onboarding.
  /// Si null, on retombe sur le premier thème actif disponible
  /// (comportement de secours, ne devrait pas arriver en pratique).
  final String? themeId;

  /// Nom du thème choisi, affiché dans la TopBar ("Mode Démo — Pokémon").
  final String? themeName;

  const DemoGamePage({
    super.key,
    required this.onUnlock,
    this.themeId,
    this.themeName,
  });

  @override
  State<DemoGamePage> createState() => _DemoGamePageState();
}

class _DemoGamePageState extends State<DemoGamePage>
    with TickerProviderStateMixin {
  static const _maxQ       = 3;
  static const _answerSecs = 15;

  List<_DemoQ> _questions = [];
  int  _idx      = 0;
  bool _revealed = false;
  String? _loadError;
  String  _themeLabel = 'Mode Démo';

  _DemoState _state = _DemoState.loading;
  int? _countdown;
  int  _secondsLeft = _answerSecs;

  // TTS
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  // Timers
  Timer? _answerTimer;

  // Animations
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _themeLabel = widget.themeName != null && widget.themeName!.isNotEmpty
        ? 'Mode Démo — ${widget.themeName}'
        : 'Mode Démo';

    // Mémorise le thème dès le lancement de la démo — même si
    // l'utilisateur quitte avant la fin, on saura quel thème lui
    // proposer de reprendre une fois inscrit/connecté.
    if (widget.themeId != null) {
      DemoThemeMemory.save(widget.themeId!);
    }

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initTts().then((_) => _loadQuestions());
  }

  @override
  void dispose() {
    _answerTimer?.cancel();
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── TTS ───────────────────────────────────────
  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ttsReady = true;
    } catch (_) { _ttsReady = false; }
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady) return;
    try { await _tts.speak(text); } catch (_) {}
  }

  Future<void> _waitSpeech() async {
    if (!_ttsReady) { await Future.delayed(const Duration(seconds: 2)); return; }
    final c = Completer<void>();
    _tts.setCompletionHandler(() { if (!c.isCompleted) c.complete(); });
    await c.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  // ── Chargement ────────────────────────────────
  Future<void> _loadQuestions() async {
    try {
      String? themeId = widget.themeId;

      // Filet de sécurité si jamais aucun thème n'a été transmis
      // (ne devrait pas arriver depuis le carrousel de l'onboarding).
      if (themeId == null) {
        final fallback = await Supabase.instance.client
            .from('themes')
            .select('id, name')
            .eq('is_active', true)
            .limit(1) as List;
        if (fallback.isNotEmpty) {
          themeId = fallback.first['id'] as String;
          if (_themeLabel == 'Mode Démo') {
            _themeLabel = 'Mode Démo — ${fallback.first['name']}';
          }
        }
      }

      if (themeId == null) { _setError('Aucun thème disponible.'); return; }

      final data = await Supabase.instance.client
          .from('questions').select('*')
          .eq('theme_id', themeId)
          .limit(20) as List;

      final list = data.map((e) => _DemoQ.fromMap(e as Map<String, dynamic>)).toList()..shuffle();
      if (list.isEmpty) { _setError('Aucune question disponible pour ce thème.'); return; }

      if (mounted) {
        setState(() => _questions = list.take(_maxQ).toList());
        await _slideCtrl.forward().orCancel;
        _startQuestionFlow();
      }
    } catch (e) {
      _setError('Erreur de chargement.');
      debugPrint('Demo load: $e');
    }
  }

  void _setError(String msg) {
    if (mounted) setState(() { _loadError = msg; _state = _DemoState.revealing; });
  }

  // ── Flux question ─────────────────────────────
  Future<void> _startQuestionFlow() async {
    if (!mounted) return;
    final q = _questions[_idx];

    setState(() { _state = _DemoState.readingQuestion; _revealed = false; });

    final fullText =
        '${q.questionText}. '
        'Réponse A : ${q.answerA}. '
        'Réponse B : ${q.answerB}. '
        'Réponse C : ${q.answerC}.';
    await _speak(fullText);
    await _waitSpeech();
    if (!mounted) return;

    setState(() => _state = _DemoState.countdown);
    for (final v in [3, 2, 1, 0]) {
      if (!mounted) return;
      setState(() => _countdown = v);
      await _speak(v == 0 ? 'Go !' : '$v');
      await Future.delayed(const Duration(milliseconds: 750));
    }
    if (!mounted) return;

    _startTimer();
  }

  void _startTimer() {
    _answerTimer?.cancel();
    setState(() { _state = _DemoState.answering; _secondsLeft = _answerSecs; });
    _answerTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      _secondsLeft--;
      setState(() {});
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _state = _DemoState.timeUp);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _state = _DemoState.revealing);
        });
      }
    });
  }

  void _revealNow() {
    _answerTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() { _state = _DemoState.revealing; _revealed = true; });
    final q = _questions[_idx];
    final label = q.correctAnswer == 'A' ? q.answerA
        : q.correctAnswer == 'B' ? q.answerB : q.answerC;
    _speak('La bonne réponse est : $label !');
  }

  void _skipToAnswering() {
    _tts.stop();
    HapticFeedback.selectionClick();
    _startTimer();
  }

  void _nextQuestion() {
    HapticFeedback.lightImpact();
    _tts.stop();
    _answerTimer?.cancel();

    if (_idx >= _questions.length - 1) {
      setState(() => _state = _DemoState.endDemo);
      return;
    }

    _slideCtrl.reset();
    setState(() { _idx++; _revealed = false; });
    _slideCtrl.forward().then((_) => _startQuestionFlow());
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_state == _DemoState.endDemo) {
      return _EndDemoScreen(onUnlock: widget.onUnlock,
          onBack: () => Navigator.pop(context));
    }

    if (_loadError != null) {
      return _FullBg(child: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(_loadError!, style: const TextStyle(color: _white, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _TlBtn(label: '← Retour', primary: false,
                onTap: () => Navigator.pop(context)),
          ],
        )),
      ));
    }

    if (_state == _DemoState.loading || _questions.isEmpty) {
      return _FullBg(child: const Center(
        child: SizedBox(width: 36, height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _yellow)),
      ));
    }

    final q        = _questions[_idx];
    final progress = (_idx + 1) / _questions.length;
    final answersVisible = _state == _DemoState.readingQuestion
        || _state == _DemoState.answering
        || _state == _DemoState.timeUp
        || _state == _DemoState.revealing;

    return Scaffold(
      body: _FullBg(
        child: SafeArea(
          child: Column(
            children: [
              _DemoTopBar(
                current: _idx + 1,
                total: _questions.length,
                progress: progress,
                themeLabel: _themeLabel,
                onExit: () => _showExitDialog(),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _DemoBadge(state: _state),
              ),

              Expanded(
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                    child: Column(
                      children: [
                        _QuestionCard(question: q),
                        const SizedBox(height: 16),

                        if (_state == _DemoState.readingQuestion)
                          _ReadingView(onSkip: _skipToAnswering),

                        if (_state == _DemoState.countdown)
                          _CountdownView(
                              value: _countdown, pulse: _pulseAnim),

                        if (answersVisible) ...[
                          if (_state == _DemoState.answering)
                            _TimerBar(
                                secondsLeft: _secondsLeft,
                                progress: _secondsLeft / _answerSecs),
                          if (_state == _DemoState.timeUp)
                            _TimeUpBanner(),

                          const SizedBox(height: 14),

                          ...['A', 'B', 'C'].map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AnswerTile(
                              letter: l,
                              text: q.text(l),
                              isCorrect: l == q.correctAnswer,
                              isRevealed: _state == _DemoState.revealing,
                            ),
                          )),

                          if (_state == _DemoState.revealing &&
                              q.anecdote != null &&
                              q.anecdote!.trim().isNotEmpty)
                            _AnecdoteCard(anecdote: q.anecdote!),

                          const SizedBox(height: 16),

                          if (_state == _DemoState.revealing)
                            _ActionBtn(
                              label: _idx < _questions.length - 1
                                  ? '➡️  Question suivante'
                                  : '🔑  Débloquer le jeu complet',
                              color: _idx < _questions.length - 1 ? _correct : _yellow,
                              textColor: _idx < _questions.length - 1 ? _white : _navy,
                              onTap: _nextQuestion,
                            )
                          else if (_state == _DemoState.answering)
                            _ActionBtn(
                              label: '👁️  Révéler la réponse',
                              color: _yellow,
                              textColor: _navy,
                              onTap: _revealNow,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0D3A8E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Quitter la démo ?',
          style: TextStyle(color: _white, fontWeight: FontWeight.w800)),
      content: const Text('Tu pourras rejouer quand tu veux !',
          style: TextStyle(color: _textSub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Continuer',
                style: TextStyle(color: _yellow, fontWeight: FontWeight.w700))),
        TextButton(
          onPressed: () { Navigator.pop(context); Navigator.pop(context); },
          child: const Text('Quitter',
              style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }
}

// ─────────────────────────────────────────────
//  Bloc Anecdote — "Le saviez-vous ?"
// ─────────────────────────────────────────────
class _AnecdoteCard extends StatefulWidget {
  final String anecdote;
  const _AnecdoteCard({required this.anecdote});

  @override
  State<_AnecdoteCard> createState() => _AnecdoteCardState();
}

class _AnecdoteCardState extends State<_AnecdoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _accent = _answerB;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4, bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _accent.withOpacity(0.18),
                _accent.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withOpacity(0.35), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _yellow.withOpacity(0.18),
                    border: Border.all(
                        color: _yellow.withOpacity(0.5), width: 1.5),
                  ),
                  child: const Center(
                    child: Text('💡', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ALLEZ, UN BONUS',
                        style: TextStyle(
                          color: Color(0xFFE9D5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.anecdote,
                      style: const TextStyle(
                        color: _white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  Écran fin de démo — REDESIGN
//  À copier-coller à la place de tes classes `_EndDemoScreen` et `_PerkCard`
//  existantes. Le reste du fichier (tokens, _FullBg, _TlBtn…) est inchangé.
// ═════════════════════════════════════════════════════════════════════════

// Petit modèle interne pour lister les fonctionnalités du jeu complet.
class _Feature {
  final String emoji, title, sub;
  final Color accent;
  const _Feature(this.emoji, this.title, this.sub, this.accent);
}

class _EndDemoScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  final VoidCallback onBack;
  const _EndDemoScreen({required this.onUnlock, required this.onBack});

  @override
  State<_EndDemoScreen> createState() => _EndDemoScreenState();
}

class _EndDemoScreenState extends State<_EndDemoScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // entrée (scale + fade)
  late final Animation<double> _scaleAnim, _fadeAnim;
  late final AnimationController _pulse;  // halo pulsé derrière le trophée

  // ── Les fonctionnalités mises en avant ──────────────────────────────
  static const _features = <_Feature>[
    _Feature('🎯', 'Des centaines de questions',
        'Football, Pokémon, Cinéma, Science…', _answerA),
    _Feature('🎙️', 'Voix off automatique',
        "Le maître du jeu n'a rien à lire", _answerB),
    _Feature('🎵', 'Blind tests & modes de jeu',
        'Musical, rapidité, détente…', _answerC),
    _Feature('🛍️', 'Nouveaux thèmes',
        'Mis à jour régulièrement dans la boutique', _correct),
  ];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutBack));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _intro, curve: Curves.easeOut));
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _FullBg(
        child: SafeArea(
          child: Column(
            children: [
              // ── Contenu défilable (au cas où petit écran) ───────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        // ── HERO trophée ─────────────────────────────
                        ScaleTransition(
                          scale: _scaleAnim,
                          child: SizedBox(
                            height: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Halos pulsés
                                AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (_, __) {
                                    final t = _pulse.value;
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        _haloRing(120 + t * 70, (1 - t) * 0.25),
                                        _haloRing(120 + ((t + 0.5) % 1) * 70,
                                            (1 - ((t + 0.5) % 1)) * 0.22),
                                      ],
                                    );
                                  },
                                ),
                                // Petites étoiles décoratives
                                const Positioned(
                                    top: 8, left: 40,
                                    child: Text('✨', style: TextStyle(fontSize: 20))),
                                const Positioned(
                                    top: 24, right: 44,
                                    child: Text('⭐', style: TextStyle(fontSize: 16))),
                                const Positioned(
                                    bottom: 18, left: 60,
                                    child: Text('⭐', style: TextStyle(fontSize: 14))),
                                // Badge trophée
                                Container(
                                  width: 128, height: 128,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      _yellow.withOpacity(0.28),
                                      _yellow.withOpacity(0.06),
                                    ]),
                                    border: Border.all(
                                        color: _yellow.withOpacity(0.45),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: _yellow.withOpacity(0.35),
                                          blurRadius: 40, spreadRadius: 2),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text('🏆',
                                        style: TextStyle(fontSize: 62)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Titre + accroche ─────────────────────────
                        ScaleTransition(
                          scale: _scaleAnim,
                          child: Column(children: [
                            const Text('Tu as adoré ! 🎉',
                                style: TextStyle(
                                    color: _yellow, fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'Ça, c\'était juste un aperçu.\nVoilà tout ce qui t\'attend 👇',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _textSub.withOpacity(0.95),
                                  fontSize: 14.5, height: 1.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 22),

                        // ── Bandeau "JEU COMPLET" ────────────────────
                        Row(children: [
                          Expanded(
                              child: Container(height: 1,
                                  color: Colors.white.withOpacity(0.1))),
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _yellow.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _yellow.withOpacity(0.3)),
                              ),
                              child: const Text('🔓  JEU COMPLET',
                                  style: TextStyle(
                                      color: _yellow, fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8)),
                            ),
                          ),
                          Expanded(
                              child: Container(height: 1,
                                  color: Colors.white.withOpacity(0.1))),
                        ]),
                        const SizedBox(height: 16),

                        // ── Cartes fonctionnalités ───────────────────
                        ...List.generate(_features.length, (i) {
                          final f = _features[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: _PerkCard(
                                feature: f, delayMs: 120 + i * 90),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // ── CTA fixés en bas ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
                child: Column(children: [
                  _TlBtn(
                    label: '🔑  Débloquer avec mon code',
                    primary: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ActivationCodePage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TlBtn(
                    label: '🔁  Rejouer la démo',
                    primary: false,
                    onTap: widget.onBack,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Anneau de halo (cercle bordé translucide).
  Widget _haloRing(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
          color: _yellow.withOpacity(opacity.clamp(0, 1)), width: 1.5),
    ),
  );
}

// ── Carte fonctionnalité (accent coloré + entrée animée) ────────────────
class _PerkCard extends StatefulWidget {
  final _Feature feature;
  final int delayMs;
  const _PerkCard({required this.feature, this.delayMs = 0});

  @override
  State<_PerkCard> createState() => _PerkCardState();
}

class _PerkCardState extends State<_PerkCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return FadeTransition(
      opacity: _c,
      child: SlideTransition(
        position: Tween<Offset>(
            begin: const Offset(0.15, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                f.accent.withOpacity(0.20),
                f.accent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: f.accent.withOpacity(0.35), width: 1.2),
          ),
          child: Row(children: [
            // Icône dans un carré coloré
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: f.accent.withOpacity(0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: f.accent.withOpacity(0.45)),
              ),
              child: Center(
                  child: Text(f.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title,
                      style: const TextStyle(
                          color: _white, fontSize: 14.5,
                          fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 3),
                  Text(f.sub,
                      style: const TextStyle(
                          color: _textSub, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: f.accent, size: 22),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widgets UI
// ─────────────────────────────────────────────

class _FullBg extends StatelessWidget {
  final Widget child;
  const _FullBg({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, height: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: [Color(0xFF1A5AE8), Color(0xFF0A2A6E), Color(0xFF060E30)],
        stops: [0.0, 0.55, 1.0],
      ),
    ),
    child: Stack(children: [
      Positioned(top: -60, right: -40,
          child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _yellow.withOpacity(0.07)))),
      Positioned(bottom: 80, left: -40,
          child: Container(width: 160, height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _bgLight.withOpacity(0.1)))),
      child,
    ]),
  );
}

class _DemoTopBar extends StatelessWidget {
  final int current, total;
  final double progress;
  final String themeLabel;
  final VoidCallback onExit;
  const _DemoTopBar({required this.current, required this.total,
    required this.progress, required this.themeLabel, required this.onExit});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Column(children: [
      Row(children: [
        GestureDetector(onTap: onExit, child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: const Icon(Icons.close_rounded, color: _white, size: 18))),
        const SizedBox(width: 12),
        Expanded(child: Row(children: [
          const Text('⚡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(themeLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _white, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _yellow.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _yellow.withOpacity(0.3), width: 1)),
            child: Text('$current / $total',
                style: const TextStyle(color: _yellow, fontSize: 13, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: progress, minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(_yellow))),
    ]),
  );
}

class _DemoBadge extends StatelessWidget {
  final _DemoState state;
  const _DemoBadge({required this.state});

  String get _label {
    switch (state) {
      case _DemoState.readingQuestion: return 'Lecture de la question';
      case _DemoState.countdown:       return 'Préparez-vous...';
      case _DemoState.answering:       return 'Temps de réponse';
      case _DemoState.timeUp:          return 'Temps écoulé !';
      case _DemoState.revealing:       return 'Réponse révélée';
      default: return 'Mode Démo';
    }
  }

  Color get _color {
    switch (state) {
      case _DemoState.readingQuestion: return _answerA;
      case _DemoState.countdown:       return _yellow;
      case _DemoState.answering:       return _correct;
      case _DemoState.timeUp:          return _warn;
      case _DemoState.revealing:       return _answerC;
      default: return _textSub;
    }
  }

  IconData get _icon {
    switch (state) {
      case _DemoState.readingQuestion: return Icons.record_voice_over_rounded;
      case _DemoState.countdown:       return Icons.timer_outlined;
      case _DemoState.answering:       return Icons.edit_rounded;
      case _DemoState.timeUp:          return Icons.alarm_rounded;
      case _DemoState.revealing:       return Icons.visibility_rounded;
      default: return Icons.stars_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: Container(
      key: ValueKey(state),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(0.25), width: 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, color: _color, size: 13),
        const SizedBox(width: 7),
        Text(_label, style: TextStyle(color: _color, fontSize: 11,
            fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  final _DemoQ question;
  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _yellow.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _yellow.withOpacity(0.2), width: 1)),
          child: const Text('QUESTION DU MAÎTRE', style: TextStyle(color: _yellow,
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
      const SizedBox(height: 14),
      Text(question.questionText, style: const TextStyle(color: _white,
          fontSize: 20, fontWeight: FontWeight.w800, height: 1.35, letterSpacing: -0.3)),
    ]),
  );
}

// Indicateur lecture TTS
class _ReadingView extends StatefulWidget {
  final VoidCallback onSkip;
  const _ReadingView({required this.onSkip});
  @override State<_ReadingView> createState() => _ReadingViewState();
}
class _ReadingViewState extends State<_ReadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  @override void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat();
  }
  @override void dispose() { _waveCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
    child: Column(children: [
      SizedBox(height: 36, child: AnimatedBuilder(
        animation: _waveCtrl,
        builder: (_, __) => Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final t = (_waveCtrl.value + i * 0.15) % 1.0;
            final h = 8 + (1 - (t - 0.5).abs() * 2) * 26;
            return Container(
                width: 5, height: h.clamp(8, 36),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: _answerA, borderRadius: BorderRadius.circular(3)));
          }),
        ),
      )),
      const SizedBox(height: 12),
      const Text('Lecture question + réponses...', style: TextStyle(color: _textSub,
          fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      GestureDetector(onTap: widget.onSkip, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: const Text('Passer ⏭', style: TextStyle(color: _textSub, fontSize: 12,
              fontWeight: FontWeight.w700)))),
    ]),
  );
}

// Countdown
class _CountdownView extends StatelessWidget {
  final int? value;
  final Animation<double> pulse;
  const _CountdownView({required this.value, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final label = value == null ? '' : (value == 0 ? 'GO !' : '$value');
    final isGo  = value == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: ScaleTransition(
          scale: pulse,
          child: Container(
            key: ValueKey(value),
            width: 140, height: 140,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: isGo
                    ? [_correct, _correct.withOpacity(0.7)]
                    : [_yellow, const Color(0xFFFFB300)]),
                boxShadow: [BoxShadow(
                    color: (isGo ? _correct : _yellow).withOpacity(0.5),
                    blurRadius: 40, spreadRadius: 4)]),
            child: Center(child: Text(label, style: TextStyle(color: _navy,
                fontSize: isGo ? 30 : 54, fontWeight: FontWeight.w900))),
          ),
        ),
      )),
    );
  }
}

// Timer bar
class _TimerBar extends StatelessWidget {
  final int secondsLeft;
  final double progress;
  const _TimerBar({required this.secondsLeft, required this.progress});

  Color get _c {
    if (secondsLeft <= 3) return const Color(0xFFEF4444);
    if (secondsLeft <= 7) return _warn;
    return _correct;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
        color: _c.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _c.withOpacity(0.25), width: 1)),
    child: Row(children: [
      Container(width: 42, height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: _c.withOpacity(0.15), border: Border.all(color: _c.withOpacity(0.4), width: 2)),
          child: Center(child: Text('$secondsLeft', style: TextStyle(color: _c,
              fontSize: 16, fontWeight: FontWeight.w900)))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Les joueurs répondent...', style: TextStyle(color: _white,
            fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_c))),
      ])),
    ]),
  );
}

class _TimeUpBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: _warn.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warn.withOpacity(0.3), width: 1)),
    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.alarm_rounded, color: _warn, size: 18),
      SizedBox(width: 8),
      Text('Temps écoulé !', style: TextStyle(color: _warn, fontSize: 13,
          fontWeight: FontWeight.w700)),
    ]),
  );
}

// Réponse
class _AnswerTile extends StatelessWidget {
  final String letter, text;
  final bool isCorrect, isRevealed;
  const _AnswerTile({required this.letter, required this.text,
    required this.isCorrect, required this.isRevealed});

  Color get _lc {
    switch (letter) { case 'A': return _answerA; case 'B': return _answerB; default: return _answerC; }
  }

  @override
  Widget build(BuildContext context) {
    final ok  = isRevealed && isCorrect;
    final bad = isRevealed && !isCorrect;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: ok ? _correct.withOpacity(0.18) : bad ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: ok ? _correct.withOpacity(0.7) : bad ? Colors.white.withOpacity(0.05) : _lc.withOpacity(0.35),
              width: ok ? 2 : 1),
          boxShadow: ok ? [BoxShadow(color: _correct.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))] : null),
      child: Row(children: [
        AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: ok ? _correct.withOpacity(0.25) : bad ? Colors.white.withOpacity(0.04) : _lc.withOpacity(0.18),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: ok ? _correct.withOpacity(0.5) : bad ? Colors.white.withOpacity(0.08) : _lc.withOpacity(0.4), width: 1)),
            child: Center(child: ok
                ? const Icon(Icons.check_rounded, color: _correct, size: 20)
                : Text(letter, style: TextStyle(color: bad ? _textSub.withOpacity(0.4) : _lc,
                fontSize: 15, fontWeight: FontWeight.w900)))),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: TextStyle(
            color: bad ? _white.withOpacity(0.35) : _white,
            fontSize: 15, fontWeight: ok ? FontWeight.w800 : FontWeight.w600, height: 1.3))),
        if (ok) ...[
          const SizedBox(width: 10),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _correct.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _correct.withOpacity(0.4), width: 1)),
              child: const Text('BONNE\nRÉPONSE', textAlign: TextAlign.center,
                  style: TextStyle(color: _correct, fontSize: 9,
                      fontWeight: FontWeight.w900, letterSpacing: 0.5, height: 1.3))),
        ],
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color, textColor;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color,
    required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))]),
        child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 16,
            fontWeight: FontWeight.w900, letterSpacing: 0.2)))),
  );
}

class _TlBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _TlBtn({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
            gradient: primary ? const LinearGradient(colors: [_yellow, Color(0xFFFFB300)]) : null,
            color: primary ? null : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: primary ? null : Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            boxShadow: primary ? [BoxShadow(color: _yellow.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 6))] : null),
        child: Center(child: Text(label, style: TextStyle(
            color: primary ? _navy : _white, fontSize: 15, fontWeight: FontWeight.w900)))),
  );
}