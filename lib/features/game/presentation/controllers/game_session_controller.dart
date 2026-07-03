import 'package:flutter/foundation.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_player.dart';

/// Résultat d'une manche, tel que saisi par le maître du jeu dans le
/// popup de fin de manche. Les annulations/redirections de bombes via
/// une carte Chance sont déjà résolues côté UI avant d'arriver ici :
/// `finalBombPlayerIds` contient la liste définitive des joueurs qui
/// reçoivent réellement une bombe ce tour-ci.
class RoundOutcome {
  final bool disqualifiedEarlyTouch;
  final String? disqualifiedPlayerId;
  final String? correctPlayerId;
  final List<String> finalBombPlayerIds;

  const RoundOutcome({
    this.disqualifiedEarlyTouch = false,
    this.disqualifiedPlayerId,
    this.correctPlayerId,
    this.finalBombPlayerIds = const [],
  });
}

class GameSessionController extends ChangeNotifier {
  final List<GamePlayer> _players = [];
  GamePlayer? _winner;

  List<GamePlayer> get players => List.unmodifiable(_players);

  /// Joueurs encore en course (non éliminés).
  List<GamePlayer> get activePlayers =>
      _players.where((p) => !p.isEliminated).toList();

  /// Joueurs qu'on peut proposer dans les sélections du popup de fin
  /// de manche : ni éliminés, ni en train de "passer" leur tour.
  List<GamePlayer> get selectablePlayers =>
      _players.where((p) => !p.isEliminated && !p.skipNextTurn).toList();

  /// Joueurs actuellement hors-jeu pour le tour en cours.
  List<GamePlayer> get skippingPlayers =>
      _players.where((p) => !p.isEliminated && p.skipNextTurn).toList();

  GamePlayer? get winner => _winner;
  bool get hasWinner => _winner != null;

  void setPlayers(List<String> names) {
    _players
      ..clear()
      ..addAll(names.asMap().entries.map(
            (e) => GamePlayer(
          id: 'p${e.key}_${DateTime.now().microsecondsSinceEpoch}',
          name: e.value.trim(),
        ),
      ));
    _winner = null;
    notifyListeners();
  }

  void applyRoundResult(RoundOutcome outcome) {
    // Touché avant le GO → manche rejouée, aucun changement de score.
    if (outcome.disqualifiedEarlyTouch) {
      return;
    }

    // 1. Les joueurs qui ont "passé" le tour qui vient de se jouer
    //    reprennent leur place pour le tour suivant.
    for (var i = 0; i < _players.length; i++) {
      if (_players[i].skipNextTurn) {
        _players[i] = _players[i].copyWith(skipNextTurn: false);
      }
    }

    // 2. Point pour la bonne réponse.
    if (outcome.correctPlayerId != null) {
      final idx = _players.indexWhere((p) => p.id == outcome.correctPlayerId);
      if (idx != -1) {
        _players[idx] = _players[idx].copyWith(
          points: _players[idx].points + 1,
        );
      }
    }

    // 3. Bombes (annulations/redirections déjà résolues côté UI).
    for (final id in outcome.finalBombPlayerIds) {
      final idx = _players.indexWhere((p) => p.id == id);
      if (idx == -1) continue;
      final newBombs = _players[idx].bombs + 1;
      _players[idx] = _players[idx].copyWith(
        bombs: newBombs,
        // Si le joueur est éliminé (3 bombes), inutile de le faire
        // "passer" un tour : il ne rejoue plus du tout.
        skipNextTurn: newBombs < 3,
      );
    }

    // 4. Victoire ?
    final candidates = _players.where((p) => p.isWinner).toList();
    if (candidates.isNotEmpty) {
      _winner = candidates.first;
    }

    notifyListeners();
  }

  void reset() {
    _players.clear();
    _winner = null;
    notifyListeners();
  }
}