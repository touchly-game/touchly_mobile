import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:touchly/features/game/presentation/controllers/game_session_controller.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

import 'game_player.dart';

/// Ouvre le popup bloquant de fin de manche. Retourne `null` si
/// jamais le contexte est fermé anormalement (ne devrait pas arriver
/// puisque le sheet est non-dismissible), sinon un [RoundOutcome]
/// prêt à être passé à `GameSessionController.applyRoundResult`.
Future<RoundOutcome?> showEndOfRoundSheet(
    BuildContext context, {
      required GameSessionController controller,
    }) {
  return showModalBottomSheet<RoundOutcome>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EndOfRoundSheet(controller: controller),
  );
}

enum _BombResolution { keep, cancel, redirect }

class _EndOfRoundSheet extends StatefulWidget {
  final GameSessionController controller;
  const _EndOfRoundSheet({required this.controller});

  @override
  State<_EndOfRoundSheet> createState() => _EndOfRoundSheetState();
}

class _EndOfRoundSheetState extends State<_EndOfRoundSheet> {
  bool _earlyTouch = false;
  String? _earlyTouchPlayerId;

  String? _correctPlayerId;
  final Set<String> _bombIds = {};
  final Set<String> _chanceIds = {};
  final Map<String, _BombResolution> _resolutions = {};
  final Map<String, String> _redirectTargets = {};

  List<GamePlayer> get _selectable => widget.controller.selectablePlayers;

  void _toggleBomb(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_bombIds.contains(id)) {
        _bombIds.remove(id);
        _resolutions.remove(id);
        _redirectTargets.remove(id);
      } else {
        _bombIds.add(id);
        _resolutions[id] = _BombResolution.keep;
      }
    });
  }

  void _toggleChance(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_chanceIds.contains(id)) {
        _chanceIds.remove(id);
      } else {
        _chanceIds.add(id);
      }
    });
  }

  /// Liste finale des joueurs qui reçoivent réellement une bombe,
  /// une fois les annulations/redirections prises en compte.
  List<String> get _finalBombIds {
    final result = <String>[];
    for (final id in _bombIds) {
      final res = _resolutions[id] ?? _BombResolution.keep;
      if (res == _BombResolution.cancel) continue;
      if (res == _BombResolution.redirect) {
        final target = _redirectTargets[id];
        if (target != null) result.add(target);
        continue;
      }
      result.add(id);
    }
    return result;
  }

  List<GamePlayer> get _upcomingSkippers {
    final skipping = <GamePlayer>[];
    for (final id in _finalBombIds) {
      final p = widget.controller.players.firstWhere((p) => p.id == id);
      if (p.bombs + 1 < 3) skipping.add(p);
    }
    return skipping;
  }

  bool get _canConfirm {
    if (_earlyTouch) return _earlyTouchPlayerId != null;
    final missingRedirectTarget = _bombIds.any((id) =>
    _resolutions[id] == _BombResolution.redirect &&
        _redirectTargets[id] == null);
    return !missingRedirectTarget;
  }

  void _confirm() {
    if (!_canConfirm) return;
    if (_earlyTouch) {
      Navigator.pop(
        context,
        RoundOutcome(
          disqualifiedEarlyTouch: true,
          disqualifiedPlayerId: _earlyTouchPlayerId,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      RoundOutcome(
        correctPlayerId: _correctPlayerId,
        finalBombPlayerIds: _finalBombIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.controller.activePlayers;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1F52),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
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
              padding: EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Row(
                children: [
                  Text('🎯', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text('Fin de la manche',
                      style: TextStyle(
                          color: TouchlyColors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                children: [
                  _EarlyTouchToggle(
                    value: _earlyTouch,
                    onChanged: (v) => setState(() {
                      _earlyTouch = v;
                      _earlyTouchPlayerId = null;
                    }),
                  ),
                  if (_earlyTouch) ...[
                    const SizedBox(height: 14),
                    const _SectionLabel(emoji: '⚠️', label: 'Qui a touché trop tôt ?'),
                    const SizedBox(height: 10),
                    _PlayerChipGrid(
                      players: players,
                      selected: {if (_earlyTouchPlayerId != null) _earlyTouchPlayerId!},
                      accent: TouchlyColors.warn,
                      onTap: (id) => setState(() => _earlyTouchPlayerId = id),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    const _SectionLabel(emoji: '✅', label: 'Qui a la bonne réponse ?'),
                    const SizedBox(height: 10),
                    _PlayerChipGrid(
                      players: _selectable,
                      selected: {if (_correctPlayerId != null) _correctPlayerId!},
                      accent: TouchlyColors.correct,
                      onTap: (id) => setState(
                              () => _correctPlayerId = _correctPlayerId == id ? null : id),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel(emoji: '💣', label: 'Qui a chopé une Bombe ?'),
                    const SizedBox(height: 10),
                    _PlayerChipGrid(
                      players: _selectable,
                      selected: _bombIds,
                      accent: TouchlyColors.danger,
                      onTap: _toggleBomb,
                    ),
                    if (_bombIds.isNotEmpty)
                      ..._bombIds.map((id) => _BombResolutionRow(
                        player: widget.controller.players.firstWhere((p) => p.id == id),
                        resolution: _resolutions[id] ?? _BombResolution.keep,
                        redirectTarget: _redirectTargets[id],
                        chanceAvailable: _chanceIds.isNotEmpty,
                        candidates: _selectable.where((p) => p.id != id).toList(),
                        onResolutionChanged: (res) =>
                            setState(() => _resolutions[id] = res),
                        onTargetChanged: (targetId) =>
                            setState(() => _redirectTargets[id] = targetId),
                      )),
                    const SizedBox(height: 22),
                    const _SectionLabel(emoji: '🍀', label: 'Qui a chopé une Chance ?'),
                    const SizedBox(height: 10),
                    _PlayerChipGrid(
                      players: _selectable,
                      selected: _chanceIds,
                      accent: TouchlyColors.answerB,
                      onTap: _toggleChance,
                    ),
                    if (_upcomingSkippers.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _SkipReminderCard(players: _upcomingSkippers),
                    ],
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: GestureDetector(
                onTap: _canConfirm ? _confirm : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _canConfirm
                        ? LinearGradient(colors: _earlyTouch
                        ? [TouchlyColors.warn, const Color(0xFFFF8C5A)]
                        : [TouchlyColors.yellow, TouchlyColors.yellowDeep])
                        : null,
                    color: _canConfirm ? null : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _canConfirm
                        ? [
                      BoxShadow(
                          color: (_earlyTouch ? TouchlyColors.warn : TouchlyColors.yellow)
                              .withOpacity(0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 6)),
                    ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _earlyTouch ? '🔁  Rejouer la manche sans lui' : '✅  Confirmer et continuer',
                      style: TextStyle(
                          color: _canConfirm
                              ? TouchlyColors.navy
                              : TouchlyColors.textSub.withOpacity(0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String emoji, label;
  const _SectionLabel({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 15)),
    const SizedBox(width: 8),
    Text(label,
        style: const TextStyle(
            color: TouchlyColors.white, fontSize: 14, fontWeight: FontWeight.w800)),
  ]);
}

class _EarlyTouchToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _EarlyTouchToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: value ? TouchlyColors.warn.withOpacity(0.14) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: value
                ? TouchlyColors.warn.withOpacity(0.5)
                : Colors.white.withOpacity(0.1)),
      ),
      child: Row(children: [
        const Text('🖐️', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Un joueur a touché avant le GO ?',
              style: TextStyle(
                  color: TouchlyColors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: TouchlyColors.warn,
          activeTrackColor: TouchlyColors.warn.withOpacity(0.3),
        ),
      ]),
    ),
  );
}

class _PlayerChipGrid extends StatelessWidget {
  final List<GamePlayer> players;
  final Set<String> selected;
  final Color accent;
  final ValueChanged<String> onTap;

  const _PlayerChipGrid({
    required this.players,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Text('Aucun joueur disponible',
          style: TextStyle(color: TouchlyColors.textSub.withOpacity(0.6), fontSize: 13));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: players.asMap().entries.map((entry) {
        final idx = entry.key;
        final p = entry.value;
        final isSelected = selected.contains(p.id);
        final color = TouchlyColors.avatarPalette[idx % TouchlyColors.avatarPalette.length];
        return GestureDetector(
          onTap: () => onTap(p.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? accent.withOpacity(0.22) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? accent.withOpacity(0.7) : Colors.white.withOpacity(0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accent : color.withOpacity(0.35),
                ),
                child: Center(
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: TouchlyColors.navy)
                      : Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              Text(p.name,
                  style: TextStyle(
                      color: isSelected ? TouchlyColors.white : TouchlyColors.textSub,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _BombResolutionRow extends StatelessWidget {
  final GamePlayer player;
  final _BombResolution resolution;
  final String? redirectTarget;
  final bool chanceAvailable;
  final List<GamePlayer> candidates;
  final ValueChanged<_BombResolution> onResolutionChanged;
  final ValueChanged<String> onTargetChanged;

  const _BombResolutionRow({
    required this.player,
    required this.resolution,
    required this.redirectTarget,
    required this.chanceAvailable,
    required this.candidates,
    required this.onResolutionChanged,
    required this.onTargetChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TouchlyColors.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TouchlyColors.danger.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('💣 ${player.name}',
            style: const TextStyle(
                color: TouchlyColors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _ResPill(
              label: 'Garder',
              selected: resolution == _BombResolution.keep,
              onTap: () => onResolutionChanged(_BombResolution.keep)),
          if (chanceAvailable) ...[
            _ResPill(
                label: '🍀 Annuler',
                selected: resolution == _BombResolution.cancel,
                onTap: () => onResolutionChanged(_BombResolution.cancel)),
            _ResPill(
                label: '🍀 Rediriger',
                selected: resolution == _BombResolution.redirect,
                onTap: () => onResolutionChanged(_BombResolution.redirect)),
          ],
        ]),
        if (resolution == _BombResolution.redirect) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidates
                .map((c) => _ResPill(
              label: c.name,
              selected: redirectTarget == c.id,
              onTap: () => onTargetChanged(c.id),
            ))
                .toList(),
          ),
        ],
      ]),
    );
  }
}

class _ResPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ResPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? TouchlyColors.yellow.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected
                ? TouchlyColors.yellow.withOpacity(0.6)
                : Colors.white.withOpacity(0.1)),
      ),
      child: Text(label,
          style: TextStyle(
              color: selected ? TouchlyColors.yellow : TouchlyColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    ),
  );
}

class _SkipReminderCard extends StatelessWidget {
  final List<GamePlayer> players;
  const _SkipReminderCard({required this.players});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        TouchlyColors.warn.withOpacity(0.16),
        TouchlyColors.warn.withOpacity(0.06),
      ]),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TouchlyColors.warn.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('⏸️', style: TextStyle(fontSize: 16)),
        SizedBox(width: 8),
        Text('Ne joueront pas au prochain tour',
            style: TextStyle(
                color: TouchlyColors.warn, fontSize: 12.5, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: players
            .map((p) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(p.name,
              style: const TextStyle(
                  color: TouchlyColors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ))
            .toList(),
      ),
    ]),
  );
}