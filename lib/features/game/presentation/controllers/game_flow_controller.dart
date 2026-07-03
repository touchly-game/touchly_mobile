import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ─────────────────────────────────────────────
//  GameFlowState — états de la machine
// ─────────────────────────────────────────────
enum GameFlowState {
  idle,
  readingQuestion,
  countdown,
  answering,
  timeUp,
  revealing,
}

// ─────────────────────────────────────────────
//  GameFlowController
//  Gère la TTS, le countdown vocal/visuel et le timer
//  de réponse, en pilotant une state machine simple.
// ─────────────────────────────────────────────
class GameFlowController extends ChangeNotifier {
  static const int answerDurationSeconds = 15;

  final FlutterTts _tts = FlutterTts();

  GameFlowState _state = GameFlowState.idle;
  GameFlowState get state => _state;

  // Countdown vocal (3, 2, 1, Go!)
  int? _countdownValue; // 3, 2, 1, 0 (0 = "Go!")
  int? get countdownValue => _countdownValue;

  // Timer de réponse
  int _secondsLeft = answerDurationSeconds;
  int get secondsLeft => _secondsLeft;
  double get answerProgress => _secondsLeft / answerDurationSeconds;

  Timer? _countdownTimer;
  Timer? _answerTimer;
  bool _ttsAvailable = true;
  bool get ttsAvailable => _ttsAvailable;

  bool _disposed = false;

  GameFlowController() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Tente de sélectionner une voix française si disponible
      try {
        final voices = await _tts.getVoices as List?;
        if (voices != null) {
          final frVoice = voices.firstWhere(
                (v) => (v['locale'] as String?)?.startsWith('fr') ?? false,
            orElse: () => null,
          );
          if (frVoice != null) {
            await _tts.setVoice({
              'name': frVoice['name'],
              'locale': frVoice['locale'],
            });
          }
        }
      } catch (_) {
        // Pas grave si la sélection de voix échoue, on garde le défaut
      }

      _tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _ttsAvailable = false;
      });
    } catch (e) {
      debugPrint('TTS init failed: $e');
      _ttsAvailable = false;
    }
  }

  // ── Démarre le flux complet pour une question ────
  Future<void> startQuestionFlow(String questionText) async {
    _reset();
    _setState(GameFlowState.readingQuestion);

    if (_ttsAvailable) {
      try {
        await _tts.speak(questionText);
        // Attend la fin de la lecture
        final completer = Completer<void>();
        _tts.setCompletionHandler(() {
          if (!completer.isCompleted) completer.complete();
        });
        // Sécurité : timeout si le completion handler ne se déclenche pas
        await completer.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () {},
        );
      } catch (e) {
        debugPrint('TTS speak failed: $e');
      }
    } else {
      // Pas de TTS dispo : on laisse un délai de lecture silencieuse
      await Future.delayed(const Duration(seconds: 3));
    }

    if (_disposed) return;
    await _runCountdown();
  }

  // ── Compte à rebours 3-2-1-Go ──────────────────
  Future<void> _runCountdown() async {
    _setState(GameFlowState.countdown);

    for (final value in [3, 2, 1, 0]) {
      if (_disposed) return;
      _countdownValue = value;
      notifyListeners();

      if (_ttsAvailable) {
        try {
          await _tts.speak(value == 0 ? 'Go !' : '$value');
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 700));
      if (_disposed) return;
    }

    _countdownValue = null;
    if (_disposed) return;
    _startAnswerTimer();
  }

  // ── Timer de réponse (15s) ──────────────────────
  void _startAnswerTimer() {
    _setState(GameFlowState.answering);
    _secondsLeft = answerDurationSeconds;
    notifyListeners();

    _answerTimer?.cancel();
    _answerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsLeft--;
      notifyListeners();
      if (_secondsLeft <= 0) {
        timer.cancel();
        _setState(GameFlowState.timeUp);
        // petite pause pour laisser voir "Temps écoulé" avant révélation
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!_disposed) _setState(GameFlowState.revealing);
        });
      }
    });
  }

  // ── Le maître du jeu peut révéler avant la fin du timer ──
  void revealNow() {
    _answerTimer?.cancel();
    _setState(GameFlowState.revealing);
  }

  // ── Permet de passer directement le countdown/lecture ──
  void skipToAnswering() {
    _countdownTimer?.cancel();
    _tts.stop();
    _countdownValue = null;
    _startAnswerTimer();
  }

  void pauseTts() => _tts.pause();

  void _reset() {
    _countdownTimer?.cancel();
    _answerTimer?.cancel();
    _countdownValue = null;
    _secondsLeft = answerDurationSeconds;
  }

  void _setState(GameFlowState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _answerTimer?.cancel();
    _tts.stop();
    super.dispose();
  }
}