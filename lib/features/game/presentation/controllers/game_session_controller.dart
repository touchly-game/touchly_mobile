import 'package:flutter/foundation.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_player.dart';

/// Résultat d'une manche, tel que saisi par le maître du jeu dans le
/// popup de fin de manche. Les annulations/redirections de bombes via
/// une carte Chance sont déjà résolues côté UI avant d'arriver ici :
/// `finalBombPlayerIds` contient la liste définitive des joueurs qui
/// reçoivent réellement une bombe ce tour-ci.
///
/// ⚠️ La touche anticipée ("avant le GO") n'est PLUS un résultat de
/// manche : c'est un événement en cours de manche, géré via
/// `excludeForCurrentRound()`. Les anciens champs sont conservés
/// uniquement pour éviter de casser d'éventuelles références, mais
/// ils ne sont plus jamais renseignés ni lus.
class RoundOutcome {
  @Deprecated('Géré via GameSessionController.excludeForCurrentRound')
  final bool disqualifiedEarlyTouch;
  @Deprecated('Géré via GameSessionController.excludeForCurrentRound')
  final String? disqualifiedPlayerId;

  final String? correctPlayerId;
  final List<String> finalBombPlayerIds;

  const RoundOutcome({
    @Deprecated('Géré via GameSessionController.excludeForCurrentRound')
    this.disqualifiedEarlyTouch = false,
    @Deprecated('Géré via GameSessionController.excludeForCurrentRound')
    this.disqualifiedPlayerId,
    this.correctPlayerId,
    this.finalBombPlayerIds = const [],
  });
}

class GameSessionController extends ChangeNotifier {
  final List<GamePlayer> _players = [];
  GamePlayer? _winner;

  /// Joueurs exclus de la manche EN COURS uniquement
  /// (pénalité "touché avant le GO"). Vidé automatiquement
  /// à la fin de chaque manche dans [applyRoundResult].
  final Set<String> _excludedThisRoundIds = {};

  List<GamePlayer> get players => List.unmodifiable(_players);

  /// Joueurs encore en course (non éliminés).
  List<GamePlayer> get activePlayers =>
      _players.where((p) => !p.isEliminated).toList();

  /// Joueurs qu'on peut proposer dans les sélections du popup de fin
  /// de manche : ni éliminés, ni en train de "passer" leur tour
  /// (bombe), ni exclus de la manche en cours (touche anticipée).
  ///
  /// Le filtre sur l'exclusion garantit la règle métier par
  /// construction : un joueur exclu ne peut ni marquer de point,
  /// ni recevoir de bombe, ni recevoir de carte Chance.
  List<GamePlayer> get selectablePlayers => _players
      .where((p) =>
  !p.isEliminated &&
      !p.skipNextTurn &&
      !_excludedThisRoundIds.contains(p.id))
      .toList();

  /// Joueurs actuellement hors-jeu pour le tour en cours (bombe).
  List<GamePlayer> get skippingPlayers =>
      _players.where((p) => !p.isEliminated && p.skipNextTurn).toList();

  // ── Exclusions "touché avant le GO" ─────────────────────────

  /// Ids des joueurs exclus de la manche en cours.
  Set<String> get excludedThisRoundIds =>
      Set.unmodifiable(_excludedThisRoundIds);

  /// Joueurs exclus de la manche en cours (objets complets).
  List<GamePlayer> get excludedThisRound =>
      _players.where((p) => _excludedThisRoundIds.contains(p.id)).toList();

  /// Joueurs pouvant encore répondre sur la manche en cours :
  /// ni éliminés, ni en skip (bombe), ni déjà exclus.
  /// Utilisé par le sheet de sélection "qui a touché avant le GO ?".
  List<GamePlayer> get eligiblePlayersThisRound => selectablePlayers;

  /// Exclut un ou plusieurs joueurs de la manche EN COURS.
  /// ⚠️ Ne change PAS de question, ne termine PAS la manche :
  /// la partie continue normalement avec les autres joueurs sur
  /// la même question.
  void excludeForCurrentRound(Set<String> playerIds) {
    _excludedThisRoundIds.addAll(playerIds);
    notifyListeners();
  }

  /// Annule l'exclusion d'un joueur (erreur de saisie).
  void reinstateForCurrentRound(String playerId) {
    _excludedThisRoundIds.remove(playerId);
    notifyListeners();
  }

  // ── Cycle de vie de la partie ───────────────────────────────

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
    _excludedThisRoundIds.clear();
    notifyListeners();
  }

  void applyRoundResult(RoundOutcome outcome) {
    // NB : plus aucun traitement "early touch" ici. L'ancien
    // `if (outcome.disqualifiedEarlyTouch) return;` était la cause
    // du bug : la page interprétait la fermeture du sheet comme une
    // fin de manche et enchaînait sur la question suivante.

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

    // 4. La pénalité "touché avant le GO" ne dure qu'une manche :
    //    les joueurs exclus redeviennent automatiquement actifs
    //    pour la question suivante.
    _excludedThisRoundIds.clear();

    // 5. Victoire ?
    final candidates = _players.where((p) => p.isWinner).toList();
    if (candidates.isNotEmpty) {
      _winner = candidates.first;
    }

    notifyListeners();
  }

  void reset() {
    _players.clear();
    _winner = null;
    _excludedThisRoundIds.clear();
    notifyListeners();
  }
}