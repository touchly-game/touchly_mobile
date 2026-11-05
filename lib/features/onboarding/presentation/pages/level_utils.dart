/// Paliers de niveau basés sur les points CUMULÉS À VIE
/// (`points_lifetime`), jamais sur le solde dépensable — sinon
/// dépenser des points ferait reculer l'utilisateur de niveau,
/// ce qui serait démotivant.
class LevelInfo {
  final int level;
  final int currentThreshold;
  final int nextThreshold;
  final int pointsIntoLevel;
  final int pointsToNext;
  final double progress; // 0.0 → 1.0

  const LevelInfo({
    required this.level,
    required this.currentThreshold,
    required this.nextThreshold,
    required this.pointsIntoLevel,
    required this.pointsToNext,
    required this.progress,
  });
}

class LevelUtils {
  LevelUtils._();

  /// Seuils des 5 premiers niveaux ; au-delà, +250 points par niveau.
  static const List<int> _baseThresholds = [0, 50, 150, 300, 500];
  static const int _stepAfterBase = 250;

  static int _thresholdForLevel(int level) {
    if (level <= _baseThresholds.length) {
      return _baseThresholds[level - 1];
    }
    final extraLevels = level - _baseThresholds.length;
    return _baseThresholds.last + extraLevels * _stepAfterBase;
  }

  static LevelInfo computeLevel(int lifetimePoints) {
    var level = 1;
    while (_thresholdForLevel(level + 1) <= lifetimePoints) {
      level++;
    }

    final current = _thresholdForLevel(level);
    final next = _thresholdForLevel(level + 1);
    final into = lifetimePoints - current;
    final span = next - current;

    return LevelInfo(
      level: level,
      currentThreshold: current,
      nextThreshold: next,
      pointsIntoLevel: into,
      pointsToNext: next - lifetimePoints,
      progress: span == 0 ? 1.0 : (into / span).clamp(0.0, 1.0),
    );
  }
}