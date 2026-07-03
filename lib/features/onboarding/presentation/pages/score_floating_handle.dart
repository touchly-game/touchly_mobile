import 'package:flutter/material.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_player.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

import 'package:touchly/features/game/presentation/controllers/game_session_controller.dart';

/// Badge flottant à placer dans un Stack (ex: en bas à droite de
/// l'écran de jeu). Toujours visible, toujours cliquable, ouvre la
/// fiche de score complète en bottom sheet.
class ScoreFloatingHandle extends StatelessWidget {
  final GameSessionController controller;
  const ScoreFloatingHandle({super.key, required this.controller});

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScoreSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final players = controller.players;
        final leader = players.isEmpty
            ? null
            : players.reduce((a, b) => a.points >= b.points ? a : b);
        return GestureDetector(
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F52).withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TouchlyColors.yellow.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.leaderboard_rounded, color: TouchlyColors.yellow, size: 16),
              const SizedBox(width: 8),
              Text(
                leader == null ? 'Scores' : '${leader.name} en tête',
                style: const TextStyle(
                    color: TouchlyColors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_up_rounded, color: TouchlyColors.textSub, size: 16),
            ]),
          ),
        );
      },
    );
  }
}

class _ScoreSheet extends StatelessWidget {
  final GameSessionController controller;
  const _ScoreSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final sorted = [...controller.players]..sort((a, b) => b.points.compareTo(a.points));
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1F52),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(children: [
              Text('🏆', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Tableau des scores',
                  style: TextStyle(
                      color: TouchlyColors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: sorted.length,
              itemBuilder: (context, i) => _ScoreRow(rank: i + 1, player: sorted[i]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final int rank;
  final GamePlayer player;
  const _ScoreRow({required this.rank, required this.player});

  @override
  Widget build(BuildContext context) {
    final eliminated = player.isEliminated;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: eliminated ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank == 1 && !eliminated
              ? TouchlyColors.yellow.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 26,
          child: Text(
            rank == 1 && !eliminated ? '👑' : '#$rank',
            style: TextStyle(
                color: TouchlyColors.textSub.withOpacity(eliminated ? 0.4 : 1),
                fontSize: 13,
                fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              player.name,
              style: TextStyle(
                color: eliminated ? TouchlyColors.textSub.withOpacity(0.5) : TouchlyColors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                decoration: eliminated ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              _Dots(count: player.points, total: 5, color: TouchlyColors.correct),
              const SizedBox(width: 10),
              _BombIcons(count: player.bombs),
              if (eliminated) ...[
                const SizedBox(width: 8),
                const Text('💀 Éliminé',
                    style: TextStyle(
                        color: TouchlyColors.danger, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ] else if (player.skipNextTurn) ...[
                const SizedBox(width: 8),
                const Text('⏸ Passe ce tour',
                    style: TextStyle(
                        color: TouchlyColors.warn, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count, total;
  final Color color;
  const _Dots({required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      total,
          (i) => Container(
        margin: const EdgeInsets.only(right: 3),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < count ? color : Colors.white.withOpacity(0.15),
        ),
      ),
    ),
  );
}

class _BombIcons extends StatelessWidget {
  final int count;
  const _BombIcons({required this.count});

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      3,
          (i) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(i < count ? '💣' : '⚪', style: const TextStyle(fontSize: 10)),
      ),
    ),
  );
}