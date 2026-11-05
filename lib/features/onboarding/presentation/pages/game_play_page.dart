import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/core/models/app_theme.dart';
import 'package:touchly/features/onboarding/presentation/pages/end_of_round_sheet.dart';
import 'package:touchly/features/onboarding/presentation/pages/home_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/points_service.dart';
import 'package:touchly/features/onboarding/presentation/pages/round_events_zone.dart';
import 'package:touchly/features/game/presentation/controllers/game_flow_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:touchly/features/game/presentation/controllers/game_session_controller.dart';
import 'package:touchly/features/onboarding/presentation/pages/score_floating_handle.dart';
import 'package:touchly/features/onboarding/presentation/pages/victory_page.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgDark        = Color(0xFF0A2A6E);
const _bgLight       = Color(0xFF2979FF);
const _yellow        = Color(0xFFFFD700);
const _navy          = Color(0xFF0A1A4E);
const _textPrimary   = Color(0xFFFFFFFF);
const _textSub       = Color(0xFFB3C8F0);
const _correct       = Color(0xFF22C55E);
const _answerA       = Color(0xFF6366F1);
const _answerB       = Color(0xFF8B5CF6);
const _answerC       = Color(0xFFEC4899);
const _warn          = Color(0xFFFF6B35);
// ─────────────────────────────────────────────

class Question {
  final String id;
  final String questionText;
  final String answerA;
  final String answerB;
  final String answerC;
  final String correctAnswer;
  final int difficulty;
  final String? anecdote;
  final String? anecdoteSource;     // ← NOUVEAU
  final String? anecdoteSourceUrl;  // ← NOUVEAU

  Question({
    required this.id,
    required this.questionText,
    required this.answerA,
    required this.answerB,
    required this.answerC,
    required this.correctAnswer,
    this.difficulty = 1,
    this.anecdote,
    this.anecdoteSource,
    this.anecdoteSourceUrl,
  });

  factory Question.fromMap(Map<String, dynamic> m) => Question(
    id: m['id'] as String,
    questionText: m['question_text'] as String,
    answerA: m['answer_a'] as String,
    answerB: m['answer_b'] as String,
    answerC: m['answer_c'] as String,
    correctAnswer: m['correct_answer'] as String,
    difficulty: m['difficulty'] as int? ?? 1,
    anecdote: m['anecdote'] as String?,
    anecdoteSource: m['anecdote_source'] as String?,           // ← NOUVEAU
    anecdoteSourceUrl: m['anecdote_source_url'] as String?,    // ← NOUVEAU
  );

  String text(String letter) {
    switch (letter) {
      case 'A': return answerA;
      case 'B': return answerB;
      case 'C': return answerC;
      default:  return '';
    }
  }
}

// ─────────────────────────────────────────────
//  GamePlayPage — Maître du jeu
// ─────────────────────────────────────────────
class GamePlayPage extends StatefulWidget {
  final AppTheme theme;
  final int startQuestionIndex; // ← démarre à la question N (0-based)
  final GameSessionController session; // ← gère joueurs/score/bombes

  const GamePlayPage({
    super.key,
    required this.theme,
    required this.session,
    this.startQuestionIndex = 0,
  });

  @override
  State<GamePlayPage> createState() => _GamePlayPageState();
}

class _GamePlayPageState extends State<GamePlayPage>
    with TickerProviderStateMixin {
  List<Question> _questions    = [];
  int  _currentIndex           = 0;
  bool _loading                = true;
  bool _gameEnded = false;

  late final GameFlowController _flow;
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _flow = GameFlowController();
    _flow.addListener(_onFlowChange);

    // On écoute aussi la session : les exclusions "touché avant le GO"
    // modifient l'affichage de la page (bannière RoundEventsZone).
    widget.session.addListener(_onFlowChange);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _loadQuestions();
  }

  @override
  void dispose() {
    _flow.removeListener(_onFlowChange);
    _flow.dispose();
    widget.session.removeListener(_onFlowChange);
    _slideCtrl.dispose();
    super.dispose();
  }

  void _onFlowChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('questions')
          .select('*')
          .eq('theme_id', widget.theme.id)
          .eq('is_active', true) as List;

      final list = data
          .map((e) => Question.fromMap(e as Map<String, dynamic>))
          .toList()
        ..shuffle();

      if (mounted) {
        final safeStart = widget.startQuestionIndex.clamp(0, list.isEmpty ? 0 : list.length - 1);

        setState(() {
          _questions     = list;
          _currentIndex  = safeStart;
        });

        _slideCtrl.forward();

        if (list.isNotEmpty) {
          _flow.startQuestionFlow(list[safeStart].questionText);
        }
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _nextQuestion() async {
    if (!mounted || _gameEnded) return;
    HapticFeedback.lightImpact();

    final outcome = await showEndOfRoundSheet(context, controller: widget.session);
    if (!mounted || outcome == null) return;

    widget.session.applyRoundResult(outcome);

    final isLastQuestion = _currentIndex >= _questions.length - 1;

    if (widget.session.hasWinner || isLastQuestion) {
      _gameEnded = true;
      await PointsService.awardGameCompleted();
      if (!mounted) return;

      if (widget.session.hasWinner) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VictoryPage(
              winner: widget.session.winner!,
              onReplay: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const GameHomePage()),
                    (_) => false,
              ),
              onHome: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const GameHomePage()),
                    (_) => false,
              ),
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _GameResultPage(theme: widget.theme, total: _questions.length),
          ),
        );
      }
      return;
    }

    _slideCtrl.reset();
    setState(() => _currentIndex++);
    _slideCtrl.forward();
    _flow.startQuestionFlow(_questions[_currentIndex].questionText);
  }

  void _revealAnswer() {
    HapticFeedback.mediumImpact();
    _flow.revealNow();
  }

  void _skipIntro() {
    HapticFeedback.selectionClick();
    _flow.skipToAnswering();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _FullScreenLoader();

    if (_questions.isEmpty) {
      return _FullScreenMessage(
        emoji: '😢',
        title: 'Aucune question',
        subtitle: 'Ce thème n\'a pas encore de questions.',
        actionLabel: '← Retour',
        onAction: () => Navigator.pop(context),
      );
    }

    final q           = _questions[_currentIndex];
    final progress    = (_currentIndex + 1) / _questions.length;
    final state       = _flow.state;
    final answersVisible = state == GameFlowState.answering ||
        state == GameFlowState.timeUp ||
        state == GameFlowState.revealing;

    // La zone "touché avant le GO" est visible pendant toute la manche.
    // Au moment du reveal, on ne la garde que si des joueurs sont déjà
    // exclus (bannière de rappel) : plus besoin du bouton d'action,
    // la manche est finie.
    final showRoundEvents = state != GameFlowState.revealing ||
        widget.session.excludedThisRound.isNotEmpty;

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
            Positioned(top: -60, right: -40,
                child: Container(width: 200, height: 200,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _yellow.withOpacity(0.07)))),
            Positioned(bottom: 80, left: -40,
                child: Container(width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _bgLight.withOpacity(0.1)))),

            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    theme:      widget.theme,
                    current:    _currentIndex + 1,
                    total:      _questions.length,
                    progress:   progress,
                    difficulty: q.difficulty,
                    onExit:     () => _showExitDialog(context),
                  ),

                  _StepIndicator(state: state),

                  Expanded(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          children: [
                            _QuestionCard(
                              question: q,
                              theme:    widget.theme,
                              state:    state,
                            ),
                            const SizedBox(height: 16),

                            if (state == GameFlowState.readingQuestion)
                              _ReadingIndicator(onSkip: _skipIntro),

                            if (state == GameFlowState.countdown)
                              _CountdownDisplay(value: _flow.countdownValue),

                            // ── Événement de manche : touché avant le GO ──
                            // Intégré au déroulement normal du tour, visible
                            // dès la lecture de la question (c'est là que la
                            // triche se produit) et pendant toute la manche.
                            if (!answersVisible) ...[
                              const SizedBox(height: 14),
                              RoundEventsZone(controller: widget.session),
                            ],

                            if (answersVisible) ...[
                              if (state == GameFlowState.answering)
                                _AnswerTimerBar(
                                  secondsLeft: _flow.secondsLeft,
                                  progress:    _flow.answerProgress,
                                ),
                              if (state == GameFlowState.timeUp)
                                const _TimeUpBanner(),
                              const SizedBox(height: 14),
                              ...['A', 'B', 'C'].map((letter) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AnswerCard(
                                  letter:     letter,
                                  text:       q.text(letter),
                                  isCorrect:  letter == q.correctAnswer,
                                  isRevealed: state == GameFlowState.revealing,
                                ),
                              )),

                              // Bloc anecdote — affiché après le reveal
                              if (state == GameFlowState.revealing &&
                                  q.anecdote != null &&
                                  q.anecdote!.trim().isNotEmpty)
                                _AnecdoteCard(
                                  anecdote: q.anecdote!,
                                  source: q.anecdoteSource,        // ← NOUVEAU
                                  sourceUrl: q.anecdoteSourceUrl,  // ← NOUVEAU
                                ),

                              // Zone événements pendant la phase de réponse,
                              // puis simple bannière de rappel au reveal.
                              if (showRoundEvents) ...[
                                const SizedBox(height: 6),
                                RoundEventsZone(controller: widget.session),
                              ],

                              const SizedBox(height: 16),
                              state == GameFlowState.revealing
                                  ? _ActionButton(
                                label: '➡️  Manche suivante',
                                color: _correct,
                                onTap: _nextQuestion,
                              )
                                  : _ActionButton(
                                label:     '👁️  Révéler la réponse',
                                color:     _yellow,
                                textColor: _navy,
                                onTap:     _revealAnswer,
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

            // ── Badge flottant "Scores" — toujours accessible ──
            Positioned(
              bottom: 24,
              right: 20,
              child: SafeArea(
                child: ScoreFloatingHandle(controller: widget.session),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D3A8E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quitter la partie ?',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800)),
        content: const Text('La progression sera perdue.',
            style: TextStyle(color: _textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer',
                style: TextStyle(color: _yellow, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Quitter',
                style: TextStyle(
                    color: Color(0xFFFF6B6B), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widgets
// ─────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final GameFlowState state;
  const _StepIndicator({required this.state});

  String get _label {
    switch (state) {
      case GameFlowState.readingQuestion: return 'Lecture de la question';
      case GameFlowState.countdown:       return 'Préparez-vous...';
      case GameFlowState.answering:       return 'Temps de réponse';
      case GameFlowState.timeUp:          return 'Temps écoulé !';
      case GameFlowState.revealing:       return 'Réponse révélée';
      default:                            return '';
    }
  }

  IconData get _icon {
    switch (state) {
      case GameFlowState.readingQuestion: return Icons.record_voice_over_rounded;
      case GameFlowState.countdown:       return Icons.timer_outlined;
      case GameFlowState.answering:       return Icons.edit_rounded;
      case GameFlowState.timeUp:          return Icons.alarm_rounded;
      case GameFlowState.revealing:       return Icons.visibility_rounded;
      default:                            return Icons.circle;
    }
  }

  Color get _color {
    switch (state) {
      case GameFlowState.readingQuestion: return _answerA;
      case GameFlowState.countdown:       return _yellow;
      case GameFlowState.answering:       return _correct;
      case GameFlowState.timeUp:          return _warn;
      case GameFlowState.revealing:       return _answerC;
      default:                            return _textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey(state),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _color.withOpacity(0.25), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_icon, color: _color, size: 14),
            const SizedBox(width: 8),
            Text(_label, style: TextStyle(
              color: _color, fontSize: 12, fontWeight: FontWeight.w800,
            )),
          ]),
        ),
      ),
    );
  }
}

class _ReadingIndicator extends StatelessWidget {
  final VoidCallback onSkip;
  const _ReadingIndicator({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: [
        const _SpeakingWave(),
        const SizedBox(height: 14),
        const Text('Lecture de la question en cours...',
            style: TextStyle(color: _textSub, fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onSkip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Text('Passer ⏭',
                style: TextStyle(color: _textSub, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _SpeakingWave extends StatefulWidget {
  const _SpeakingWave();
  @override
  State<_SpeakingWave> createState() => _SpeakingWaveState();
}

class _SpeakingWaveState extends State<_SpeakingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final t = (_ctrl.value + i * 0.15) % 1.0;
              final h = 8 + (1 - (t - 0.5).abs() * 2) * 24;
              return Container(
                width: 4,
                height: h.clamp(8, 32),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _answerA,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _CountdownDisplay extends StatelessWidget {
  final int? value;
  const _CountdownDisplay({required this.value});

  @override
  Widget build(BuildContext context) {
    final label = value == null ? '' : (value == 0 ? 'GO !' : '$value');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Container(
            key: ValueKey(value),
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: value == 0
                    ? [_correct, _correct.withOpacity(0.7)]
                    : [_yellow, const Color(0xFFFFB300)],
              ),
              boxShadow: [BoxShadow(
                color: (value == 0 ? _correct : _yellow).withOpacity(0.4),
                blurRadius: 32, offset: const Offset(0, 8),
              )],
            ),
            child: Center(
              child: Text(label, style: TextStyle(
                color: _navy,
                fontSize: value == 0 ? 32 : 56,
                fontWeight: FontWeight.w900,
              )),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerTimerBar extends StatelessWidget {
  final int secondsLeft;
  final double progress;
  const _AnswerTimerBar({required this.secondsLeft, required this.progress});

  Color get _color {
    if (secondsLeft <= 3) return const Color(0xFFEF4444);
    if (secondsLeft <= 7) return _warn;
    return _correct;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.25), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color.withOpacity(0.15),
            border: Border.all(color: _color.withOpacity(0.4), width: 2),
          ),
          child: Center(
            child: Text('$secondsLeft', style: TextStyle(
              color: _color, fontSize: 16, fontWeight: FontWeight.w900,
            )),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Les joueurs répondent...',
                style: TextStyle(color: _textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_color),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TimeUpBanner extends StatelessWidget {
  const _TimeUpBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _warn.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warn.withOpacity(0.3), width: 1),
      ),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.alarm_rounded, color: _warn, size: 18),
        SizedBox(width: 8),
        Text('Temps écoulé ! Révélation dans un instant...',
            style: TextStyle(color: _warn, fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppTheme theme;
  final int current;
  final int total;
  final double progress;
  final int difficulty;
  final VoidCallback onExit;

  const _TopBar({
    required this.theme,
    required this.current,
    required this.total,
    required this.progress,
    required this.difficulty,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: onExit,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: const Icon(Icons.close_rounded, color: _textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              Text(theme.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(theme.name, style: const TextStyle(
                  color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Row(
                children: List.generate(3, (i) => Icon(
                  Icons.star_rounded, size: 12,
                  color: i < difficulty
                      ? _yellow
                      : Colors.white.withOpacity(0.2),
                )),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _yellow.withOpacity(0.3), width: 1),
            ),
            child: Text('$current / $total',
                style: const TextStyle(color: _yellow, fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(_yellow),
          ),
        ),
      ]),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Question      question;
  final AppTheme      theme;
  final GameFlowState state;

  const _QuestionCard({
    required this.question,
    required this.theme,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _yellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _yellow.withOpacity(0.2), width: 1),
          ),
          child: const Text('QUESTION DU MAÎTRE', style: TextStyle(
            color: _yellow, fontSize: 10, fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          )),
        ),
        const SizedBox(height: 16),
        Text(question.questionText, style: const TextStyle(
          color: _textPrimary, fontSize: 21, fontWeight: FontWeight.w800,
          height: 1.35, letterSpacing: -0.3,
        )),
      ]),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String letter;
  final String text;
  final bool   isCorrect;
  final bool   isRevealed;

  const _AnswerCard({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isRevealed,
  });

  Color get _letterColor {
    switch (letter) {
      case 'A': return _answerA;
      case 'B': return _answerB;
      case 'C': return _answerC;
      default:  return _yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCorrect = isRevealed && isCorrect;
    final showWrong   = isRevealed && !isCorrect;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: showCorrect
            ? _correct.withOpacity(0.18)
            : showWrong
            ? Colors.white.withOpacity(0.03)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: showCorrect
              ? _correct.withOpacity(0.7)
              : showWrong
              ? Colors.white.withOpacity(0.05)
              : _letterColor.withOpacity(0.35),
          width: showCorrect ? 2 : 1,
        ),
        boxShadow: showCorrect
            ? [BoxShadow(color: _correct.withOpacity(0.25),
            blurRadius: 20, offset: const Offset(0, 6))]
            : null,
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: showCorrect
                ? _correct.withOpacity(0.25)
                : showWrong
                ? Colors.white.withOpacity(0.04)
                : _letterColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: showCorrect
                  ? _correct.withOpacity(0.5)
                  : showWrong
                  ? Colors.white.withOpacity(0.08)
                  : _letterColor.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Center(
            child: showCorrect
                ? const Icon(Icons.check_rounded, color: _correct, size: 20)
                : Text(letter, style: TextStyle(
              color: showWrong
                  ? _textSub.withOpacity(0.4)
                  : _letterColor,
              fontSize: 15, fontWeight: FontWeight.w900,
            )),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: TextStyle(
            color: showWrong
                ? _textPrimary.withOpacity(0.35)
                : _textPrimary,
            fontSize: 15,
            fontWeight: showCorrect ? FontWeight.w800 : FontWeight.w600,
            height: 1.3,
          )),
        ),
        if (showCorrect) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _correct.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _correct.withOpacity(0.4), width: 1),
            ),
            child: const Text('BONNE\nRÉPONSE', textAlign: TextAlign.center,
                style: TextStyle(color: _correct, fontSize: 9,
                    fontWeight: FontWeight.w900, letterSpacing: 0.5, height: 1.3)),
          ),
        ],
      ]),
    );
  }
}

// ── Bloc anecdote — "Le saviez-vous ?" ──
// ── Bloc anecdote — "Le saviez-vous ?" ──
class _AnecdoteCard extends StatefulWidget {
  final String anecdote;
  final String? source;
  final String? sourceUrl;

  const _AnecdoteCard({
    required this.anecdote,
    this.source,
    this.sourceUrl,
  });

  @override
  State<_AnecdoteCard> createState() => _AnecdoteCardState();
}

class _AnecdoteCardState extends State<_AnecdoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

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

  Future<void> _openSource() async {
    final url = widget.sourceUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Échec silencieux : pas critique, on ne bloque pas l'expérience de jeu.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSource = widget.source != null && widget.source!.trim().isNotEmpty;
    final hasLink = widget.sourceUrl != null && widget.sourceUrl!.trim().isNotEmpty;

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
                _answerB.withOpacity(0.18),
                _answerB.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _answerB.withOpacity(0.35), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                            color: _answerB.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LE SAVAIS-TU ?',
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
                            color: _textPrimary,
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

              // ── Source — discrète, en bas de carte ──
              if (hasSource) ...[
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.08),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: hasLink ? _openSource : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasLink ? Icons.link_rounded : Icons.info_outline_rounded,
                        size: 12,
                        color: _textSub.withOpacity(0.6),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Source : ${widget.source}',
                          style: TextStyle(
                            color: _textSub.withOpacity(0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: hasLink
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor: _textSub.withOpacity(0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String     label;
  final Color      color;
  final Color      textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    this.textColor = _textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2),
              blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: Text(label, style: TextStyle(
              color: color, fontSize: 16,
              fontWeight: FontWeight.w900, letterSpacing: 0.2)),
        ),
      ),
    );
  }
}

class _GameResultPage extends StatelessWidget {
  final AppTheme theme;
  final int      total;
  const _GameResultPage({required this.theme, required this.total});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFF1A5AE8), Color(0xFF0A2A6E), Color(0xFF060E30)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _yellow.withOpacity(0.12),
                  border: Border.all(color: _yellow.withOpacity(0.3), width: 2),
                ),
                child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 52))),
              ),
              const SizedBox(height: 24),
              const Text('Paquet de questions terminé !', style: TextStyle(
                  color: _yellow, fontSize: 26,
                  fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('${theme.emoji}  ${theme.name}',
                  style: const TextStyle(color: _textSub, fontSize: 15)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _yellow.withOpacity(0.2), width: 1),
                ),
                child: Column(children: [
                  Text('$total', style: const TextStyle(
                      color: _yellow, fontSize: 64,
                      fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(height: 6),
                  const Text('questions jouées', style: TextStyle(
                      color: _textSub, fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 32),
              _TlButton(
                label: '🏠  Retour à l\'accueil',
                primary: true,
                onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const GameHomePage()),
                      (_) => false,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: [Color(0xFF1A5AE8), Color(0xFF0A2A6E), Color(0xFF060E30)],
        ),
      ),
      child: const Center(
        child: SizedBox(width: 36, height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _yellow)),
      ),
    ),
  );
}

class _FullScreenMessage extends StatelessWidget {
  final String emoji, title, subtitle, actionLabel;
  final VoidCallback onAction;

  const _FullScreenMessage({
    required this.emoji, required this.title, required this.subtitle,
    required this.actionLabel, required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: [Color(0xFF1A5AE8), Color(0xFF0A2A6E), Color(0xFF060E30)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: _textPrimary,
                fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: _textSub, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            _TlButton(label: actionLabel, onTap: onAction, primary: false),
          ]),
        ),
      ),
    ),
  );
}

class _TlButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  final bool         primary;
  const _TlButton({required this.label, required this.onTap, required this.primary});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 52,
      decoration: BoxDecoration(
        gradient: primary
            ? const LinearGradient(colors: [_yellow, Color(0xFFFFB300)])
            : null,
        color:    primary ? null : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: primary
            ? null
            : Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        boxShadow: primary
            ? [BoxShadow(color: _yellow.withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 5))]
            : null,
      ),
      child: Center(
        child: Text(label, style: TextStyle(
            color: primary ? _navy : _textPrimary,
            fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    ),
  );
}