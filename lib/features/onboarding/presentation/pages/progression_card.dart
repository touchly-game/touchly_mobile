import 'package:flutter/material.dart';
import 'package:touchly/features/onboarding/presentation/pages/level_utils.dart';
import 'package:touchly/features/onboarding/presentation/pages/points_service.dart';

const _yellow = Color(0xFFFFD700);
const _navy = Color(0xFF0A1A4E);
const _textPrimary = Color(0xFFFFFFFF);
const _textSub = Color(0xFFB3C8F0);
const _purple = Color(0xFF7C3AED);

/// Carte de progression affichée sur la home page, entre le Hero et
/// "Mes thèmes". Affiche le solde de points dépensables, le niveau
/// (basé sur les points cumulés à vie) et la progression vers le
/// niveau suivant.
class ProgressionCard extends StatelessWidget {
  final UserPoints points;
  const ProgressionCard({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final level = LevelUtils.computeLevel(points.lifetime);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _yellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.bolt_rounded, color: _navy, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Points Touchly',
                        style: TextStyle(color: _textSub.withOpacity(0.9), fontSize: 11)),
                    Text('${points.balance} pts',
                        style: const TextStyle(
                            color: _yellow, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple.withOpacity(0.4), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('NIVEAU',
                        style: TextStyle(
                            color: Color(0xFFC7B8F5),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                    Text('${level.level}',
                        style: const TextStyle(
                            color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: level.progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(_yellow),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Encore ${level.pointsToNext} pts avant le niveau ${level.level + 1}',
            style: TextStyle(color: _textSub.withOpacity(0.8), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}