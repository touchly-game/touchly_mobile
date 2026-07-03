import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/features/onboarding/presentation/pages/activation_code_page.dart';

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
  final String? anecdote; // ← NOUVEAU
  const _DemoQ({
    required this.id, required this.questionText,
    required this.answerA, required this.answerB,
    required this.answerC, required this.correctAnswer,
    this.anecdote, // ← NOUVEAU
  });
  factory _DemoQ.fromMap(Map<String, dynamic> m) => _DemoQ(
    id: m['id'] as String,
    questionText: m['question_text'] as String,
    answerA: m['answer_a'] as String,
    answerB: m['answer_b'] as String,
    answerC: m['answer_c'] as String,
    correctAnswer: m['correct_answer'] as String,
    anecdote: m['anecdote'] as String?, // ← NOUVEAU
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
  const DemoGamePage({super.key, required this.onUnlock});

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

  _DemoState _state = _DemoState.loading;
  int? _countdown;          // 3,2,1,0 pendant countdown
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
      final themes = await Supabase.instance.client
          .from('themes').select('id, name').eq('is_active', true) as List;

      String? themeId;
      for (final t in themes) {
        if ((t['name'] as String).toLowerCase().contains('pok')) {
          themeId = t['id'] as String; break;
        }
      }
      themeId ??= themes.isNotEmpty ? themes.first['id'] as String : null;
      if (themeId == null) { _setError('Aucun thème disponible.'); return; }

      final data = await Supabase.instance.client
          .from('questions').select('*')
          .eq('theme_id', themeId)
          .limit(20) as List;

      final list = data.map((e) => _DemoQ.fromMap(e as Map<String, dynamic>)).toList()..shuffle();
      if (list.isEmpty) { _setError('Aucune question disponible.'); return; }

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

    // 1. READING
    setState(() { _state = _DemoState.readingQuestion; _revealed = false; });

    // Lit question + réponses
    final fullText =
        '${q.questionText}. '
        'Réponse A : ${q.answerA}. '
        'Réponse B : ${q.answerB}. '
        'Réponse C : ${q.answerC}.';
    await _speak(fullText);
    await _waitSpeech();
    if (!mounted) return;

    // 2. COUNTDOWN 3-2-1-Go
    setState(() => _state = _DemoState.countdown);
    for (final v in [3, 2, 1, 0]) {
      if (!mounted) return;
      setState(() => _countdown = v);
      await _speak(v == 0 ? 'Go !' : '$v');
      await Future.delayed(const Duration(milliseconds: 750));
    }
    if (!mounted) return;

    // 3. ANSWERING
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
    // Lit la bonne réponse à voix haute
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
      // Fin de la démo
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
    // Écran fin de démo
    if (_state == _DemoState.endDemo) {
      return _EndDemoScreen(onUnlock: widget.onUnlock,
          onBack: () => Navigator.pop(context));
    }

    // Erreur
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

    // Chargement
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
              // ── TopBar ──────────────────────
              _DemoTopBar(
                current: _idx + 1,
                total: _questions.length,
                progress: progress,
                onExit: () => _showExitDialog(),
              ),

              // ── Badge mode démo ─────────────
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
                        // Carte question
                        _QuestionCard(question: q),
                        const SizedBox(height: 16),

                        // Zone dynamique
                        if (_state == _DemoState.readingQuestion)
                          _ReadingView(onSkip: _skipToAnswering),

                        if (_state == _DemoState.countdown)
                          _CountdownView(
                              value: _countdown, pulse: _pulseAnim),

                        if (answersVisible) ...[
                          // Timer — seulement si on joue
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

                          // Boutons — masqués pendant la lecture et le countdown
                          if (_state == _DemoState.revealing)
                            _ActionBtn(
                              label: _idx < _questions.length - 1
                                  ? '➡️  Question suivante'
                                  : '🔑  Débloquer le jeu complet',
                              color: _idx < _questions.length - 1 ? _correct : _yellow,
                              textColor: _idx < _questions.length - 1 ? _white : _navy,
                              onTap: _nextQuestion,
                            )
                          else if (_state == _DemoState.answering)   // ← seulement si on joue
                            _ActionBtn(
                              label: '👁️  Révéler la réponse',
                              color: _yellow,
                              textColor: _navy,
                              onTap: _revealNow,
                            ),
                          // Pendant readingQuestion et countdown : aucun bouton affiché
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

  static const _accent = _answerB; // violet — cohérent avec le thème Pokémon

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

// ─────────────────────────────────────────────
//  Écran fin de démo — accrocheur
// ─────────────────────────────────────────────
class _EndDemoScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  final VoidCallback onBack;
  const _EndDemoScreen({required this.onUnlock, required this.onBack});

  @override
  State<_EndDemoScreen> createState() => _EndDemoScreenState();
}

class _EndDemoScreenState extends State<_EndDemoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scaleAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _FullBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: Column(
              children: [
                // Haut : trophée animé
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Halo étoilé
                          Stack(alignment: Alignment.center, children: [
                            Container(width: 160, height: 160,
                                decoration: BoxDecoration(shape: BoxShape.circle,
                                    color: _yellow.withOpacity(0.08))),
                            Container(width: 120, height: 120,
                                decoration: BoxDecoration(shape: BoxShape.circle,
                                    color: _yellow.withOpacity(0.14),
                                    border: Border.all(color: _yellow.withOpacity(0.3), width: 2))),
                            const Text('🏆', style: TextStyle(fontSize: 64)),
                          ]),
                          const SizedBox(height: 24),

                          const Text('Tu as adoré !', style: TextStyle(
                              color: _yellow, fontSize: 32,
                              fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          const SizedBox(height: 10),
                          const Text(
                              'La démo est terminée.\nDébloque le jeu complet pour\ndes centaines de questions !',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _textSub, fontSize: 15, height: 1.5)),
                          const SizedBox(height: 32),

                          // Cards avantages
                          _PerkCard(emoji: '🎯', label: 'Des centaines de questions',
                              sub: 'Football, Pokémon, Cinéma, Science...'),
                          const SizedBox(height: 10),
                          _PerkCard(emoji: '🎙️', label: 'Voix off automatique',
                              sub: 'Le maître du jeu n\'a rien à lire'),
                          const SizedBox(height: 10),
                          _PerkCard(emoji: '🛍️', label: 'Nouveaux thèmes',
                              sub: 'Mis à jour régulièrement dans la boutique'),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Bouton principal — très visible
                _TlBtn(
                  label: '🔑  Débloquer avec mon code',
                  primary: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActivationCodePage()),
                  ),
                ),
                const SizedBox(height: 12),
                _TlBtn(
                  label: 'Rejouer la démo',
                  primary: false,
                  onTap: widget.onBack,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  final String emoji, label, sub;
  const _PerkCard({required this.emoji, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
    ),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 26)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _white,
            fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: _textSub, fontSize: 12)),
      ])),
      const Icon(Icons.check_circle_rounded, color: _correct, size: 18),
    ]),
  );
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
  final VoidCallback onExit;
  const _DemoTopBar({required this.current, required this.total,
    required this.progress, required this.onExit});

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
        const Expanded(child: Row(children: [
          Text('⚡', style: TextStyle(fontSize: 14)),
          SizedBox(width: 6),
          Text('Mode Démo — Pokémon',
              style: TextStyle(color: _white, fontSize: 13, fontWeight: FontWeight.w800)),
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