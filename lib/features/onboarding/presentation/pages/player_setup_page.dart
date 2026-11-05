import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchly/features/game/presentation/controllers/game_session_controller.dart';
import 'package:touchly/features/onboarding/presentation/pages/home_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';
import 'package:touchly/features/onboarding/presentation/pages/victory_page.dart';

import 'end_of_round_sheet.dart';

class PlayerSetupPage extends StatefulWidget {
  final void Function(GameSessionController controller) onReady;
  final int catchUpRounds; // ← NOUVEAU

  const PlayerSetupPage({
    super.key,
    required this.onReady,
    this.catchUpRounds = 0, // ← NOUVEAU
  });

  @override
  State<PlayerSetupPage> createState() => _PlayerSetupPageState();
}

class _PlayerSetupPageState extends State<PlayerSetupPage> {
  static const _minPlayers = 2;
  static const _maxPlayers = 8;

  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _startingCatchUp = false; // ← NOUVEAU : bloque le bouton pendant la boucle

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    if (_controllers.length >= _maxPlayers) return;
    HapticFeedback.selectionClick();
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removePlayer(int index) {
    if (_controllers.length <= _minPlayers) return;
    HapticFeedback.selectionClick();
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  bool get _canStart =>
      !_startingCatchUp &&
      _controllers.length >= _minPlayers &&
          _controllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _start() async {
    if (!_canStart) return;
    HapticFeedback.mediumImpact();
    final names = _controllers.map((c) => c.text.trim()).toList();
    final controller = GameSessionController()..setPlayers(names);

    // Pas de rattrapage → partie normale, comportement inchangé.
    if (widget.catchUpRounds <= 0) {
      widget.onReady(controller);
      return;
    }

    // ── Rattrapage des manches jouées en démo ──────────────────
    setState(() => _startingCatchUp = true);

    for (var i = 1; i <= widget.catchUpRounds; i++) {
      if (!mounted) return;

      final outcome = await showEndOfRoundSheet(
        context,
        controller: controller,
        roundLabel: 'Manche $i/${widget.catchUpRounds} (rattrapage démo)',
      );

      // L'utilisateur a fermé le popup sans valider (ne devrait pas
      // arriver puisqu'il est non-dismissible, mais on sécurise).
      if (outcome == null || !mounted) {
        setState(() => _startingCatchUp = false);
        return;
      }

      controller.applyRoundResult(outcome);

      // Cas limite : un joueur atteint 5 points dès le rattrapage.
      if (controller.hasWinner) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VictoryPage(
              winner: controller.winner!,
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
        return;
      }
    }

    if (!mounted) return;
    setState(() => _startingCatchUp = false);
    widget.onReady(controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: TouchlyColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 24, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: TouchlyColors.white, size: 18),
                    ),
                    const Text('Qui joue ce soir ?',
                        style: TextStyle(
                            color: TouchlyColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.catchUpRounds > 0
                        ? 'Ajoute les joueurs, puis on rattrape les ${widget.catchUpRounds} manches jouées en démo'
                        : 'Ajoute entre 2 et 8 joueurs pour commencer',
                    style: const TextStyle(color: TouchlyColors.textSub, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _controllers.length,
                  itemBuilder: (context, index) => _PlayerInputTile(
                    key: ValueKey(_controllers[index]),
                    index: index,
                    controller: _controllers[index],
                    canRemove: _controllers.length > _minPlayers,
                    onRemove: () => _removePlayer(index),
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: GestureDetector(
                  onTap: _controllers.length < _maxPlayers ? _addPlayer : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(
                            _controllers.length < _maxPlayers ? 0.15 : 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color: _controllers.length < _maxPlayers
                                ? TouchlyColors.yellow
                                : TouchlyColors.textSub.withOpacity(0.4)),
                        const SizedBox(width: 8),
                        Text('Ajouter un joueur',
                            style: TextStyle(
                                color: _controllers.length < _maxPlayers
                                    ? TouchlyColors.yellow
                                    : TouchlyColors.textSub.withOpacity(0.4),
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: GestureDetector(
                  onTap: _start,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: _canStart ? TouchlyColors.primaryButtonGradient : null,
                      color: _canStart ? null : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _canStart
                          ? [
                        BoxShadow(
                            color: TouchlyColors.yellow.withOpacity(0.4),
                            blurRadius: 26,
                            offset: const Offset(0, 8)),
                      ]
                          : null,
                    ),
                    child: Center(
                      child: _startingCatchUp
                          ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: TouchlyColors.yellow),
                      )
                          : Text(
                          widget.catchUpRounds > 0
                              ? '🔁  Rattraper les manches démo'
                              : '🚀  Lancer la partie',
                          style: TextStyle(
                              color: _canStart
                                  ? TouchlyColors.navy
                                  : TouchlyColors.textSub.withOpacity(0.5),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
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
}

class _PlayerInputTile extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _PlayerInputTile({
    super.key,
    required this.index,
    required this.controller,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = TouchlyColors.avatarPalette[index % TouchlyColors.avatarPalette.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (_) => onChanged(),
                style: const TextStyle(
                    color: TouchlyColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nom du joueur ${index + 1}',
                  hintStyle: TextStyle(color: TouchlyColors.textSub.withOpacity(0.5)),
                ),
              ),
            ),
            if (canRemove)
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded,
                    color: TouchlyColors.textSub.withOpacity(0.6), size: 18),
              ),
          ],
        ),
      ),
    );
  }
}