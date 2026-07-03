/// Représente un joueur pendant une partie physique de Touchly.
///
/// Règles associées :
/// - `points` : 0 → 5. À 5, le joueur remporte la partie.
/// - `bombs`  : 0 → 3. À 3, le joueur est éliminé (`isEliminated`).
/// - `skipNextTurn` : true tant que le joueur doit "passer" son
///   prochain tour suite à une bombe. Se réinitialise automatiquement
///   après ce tour (voir GameSessionController.applyRoundResult).
class GamePlayer {
  final String id;
  final String name;
  final int points;
  final int bombs;
  final bool skipNextTurn;

  const GamePlayer({
    required this.id,
    required this.name,
    this.points = 0,
    this.bombs = 0,
    this.skipNextTurn = false,
  });

  bool get isEliminated => bombs >= 3;
  bool get isWinner => points >= 5;

  GamePlayer copyWith({
    String? name,
    int? points,
    int? bombs,
    bool? skipNextTurn,
  }) {
    return GamePlayer(
      id: id,
      name: name ?? this.name,
      points: points ?? this.points,
      bombs: bombs ?? this.bombs,
      skipNextTurn: skipNextTurn ?? this.skipNextTurn,
    );
  }
}