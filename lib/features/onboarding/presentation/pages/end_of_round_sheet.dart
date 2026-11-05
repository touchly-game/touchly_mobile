import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:touchly/features/game/presentation/controllers/game_session_controller.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

import 'game_player.dart';

/// Ouvre le popup bloquant de fin de manche.
///
/// ⚠️ Un joueur ne peut recevoir qu'UNE SEULE carte par manche
/// (bonne réponse OU bombe OU chance) — conforme aux règles physiques
/// du jeu : on ne lance sa main qu'une fois et on n'attrape qu'une
/// carte. Les 3 catégories de sélection sont donc mutuellement
/// exclusives ci-dessous : un joueur déjà assigné à une catégorie est
/// automatiquement grisé dans les deux autres.
Future<RoundOutcome?> showEndOfRoundSheet(
    BuildContext context, {
      required GameSessionController controller,
      String? roundLabel,
    }) {
  return showModalBottomSheet<RoundOutcome>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EndOfRoundSheet(controller: controller, roundLabel: roundLabel),
  );
}

enum _BombResolution { keep, cancel, redirect }

/// Catégorie de carte attribuée à un joueur pour la manche en cours.
/// Sert uniquement à calculer les exclusions croisées entre grilles.
enum _CardCategory { correct, bomb, chance }

class _EndOfRoundSheet extends StatefulWidget {
  final GameSessionController controller;
  final String? roundLabel;
  const _EndOfRoundSheet({required this.controller, this.roundLabel});

  @override
  State<_EndOfRoundSheet> createState() => _EndOfRoundSheetState();
}

class _EndOfRoundSheetState extends State<_EndOfRoundSheet> {
  String? _correctPlayerId;
  final Set<String> _bombIds = {};
  final Set<String> _chanceIds = {};
  final Map<String, _BombResolution> _resolutions = {};
  final Map<String, String> _redirectTargets = {};

  /// Ids des joueurs exclus pour cette manche (touche avant le GO).
  Set<String> get _excludedIds => widget.controller.excludedThisRoundIds;

  /// Joueurs sélectionnables = joueurs habituels MOINS les exclus
  /// de la manche. Ils ne peuvent ni marquer, ni recevoir de bombe,
  /// ni recevoir de chance.
  List<GamePlayer> get _selectable => widget.controller.selectablePlayers
      .where((p) => !_excludedIds.contains(p.id))
      .toList();

  /// Catégorie actuellement attribuée à chaque joueur (une seule
  /// carte par joueur et par manche).
  Map<String, _CardCategory> get _assignments {
    final map = <String, _CardCategory>{};
    if (_correctPlayerId != null) map[_correctPlayerId!] = _CardCategory.correct;
    for (final id in _bombIds) map[id] = _CardCategory.bomb;
    for (final id in _chanceIds) map[id] = _CardCategory.chance;
    return map;
  }

  /// Retire un joueur de toutes les catégories AUTRES que celle
  /// passée en paramètre — garantit l'exclusivité "1 carte/joueur".
  void _clearOtherCategories(String id, _CardCategory keep) {
    if (keep != _CardCategory.correct && _correctPlayerId == id) {
      _correctPlayerId = null;
    }
    if (keep != _CardCategory.bomb && _bombIds.contains(id)) {
      _bombIds.remove(id);
      _resolutions.remove(id);
      _redirectTargets.remove(id);
    }
    if (keep != _CardCategory.chance && _chanceIds.contains(id)) {
      _chanceIds.remove(id);
    }
  }

  void _toggleCorrect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_correctPlayerId == id) {
        _correctPlayerId = null;
      } else {
        _clearOtherCategories(id, _CardCategory.correct);
        _correctPlayerId = id;
      }
    });
  }

  void _toggleBomb(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_bombIds.contains(id)) {
        _bombIds.remove(id);
        _resolutions.remove(id);
        _redirectTargets.remove(id);
      } else {
        _clearOtherCategories(id, _CardCategory.bomb);
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
        _clearOtherCategories(id, _CardCategory.chance);
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
    final missingRedirectTarget = _bombIds.any((id) =>
    _resolutions[id] == _BombResolution.redirect &&
        _redirectTargets[id] == null);
    return !missingRedirectTarget;
  }

  void _confirm() {
    if (!_canConfirm) return;
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
    final excludedPlayers = widget.controller.excludedThisRound;
    final assignments = _assignments;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Row(
                children: [
                  Text(widget.roundLabel != null ? '🔁' : '🎯', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(widget.roundLabel ?? 'Fin de la manche',
                      style: const TextStyle(
                          color: TouchlyColors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '1 carte attrapée par joueur — la sélection dans une catégorie retire le joueur des autres.',
                  style: TextStyle(
                      color: TouchlyColors.textSub.withOpacity(0.8), fontSize: 11.5, height: 1.3),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                children: [
                  // ── Rappel des joueurs exclus (touche anticipée) ──
                  if (excludedPlayers.isNotEmpty) ...[
                    _ExcludedReminderCard(players: excludedPlayers),
                    const SizedBox(height: 18),
                  ],

                  const _SectionLabel(emoji: '✅', label: 'Qui a la bonne réponse ?'),
                  const SizedBox(height: 10),
                  _PlayerChipGrid(
                    players: _selectable,
                    selected: {if (_correctPlayerId != null) _correctPlayerId!},
                    disabledIds: assignments.entries
                        .where((e) => e.value != _CardCategory.correct)
                        .map((e) => e.key)
                        .toSet(),
                    accent: TouchlyColors.correct,
                    onTap: _toggleCorrect,
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel(emoji: '💣', label: 'Qui a chopé une Bombe ?'),
                  const SizedBox(height: 10),
                  _PlayerChipGrid(
                    players: _selectable,
                    selected: _bombIds,
                    disabledIds: assignments.entries
                        .where((e) => e.value != _CardCategory.bomb)
                        .map((e) => e.key)
                        .toSet(),
                    accent: TouchlyColors.danger,
                    onTap: _toggleBomb,
                  ),
                  if (_bombIds.isNotEmpty)
                    ..._bombIds.map((id) => _BombResolutionRow(
                      player: widget.controller.players.firstWhere((p) => p.id == id),
                      resolution: _resolutions[id] ?? _BombResolution.keep,
                      redirectTarget: _redirectTargets[id],
                      chanceAvailable: _chanceIds.isNotEmpty,
                      // Une redirection donne la bombe à un autre joueur : on
                      // exclut donc aussi les joueurs déjà assignés ailleurs.
                      candidates: _selectable
                          .where((p) => p.id != id && !assignments.containsKey(p.id))
                          .toList(),
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
                    disabledIds: assignments.entries
                        .where((e) => e.value != _CardCategory.chance)
                        .map((e) => e.key)
                        .toSet(),
                    accent: TouchlyColors.answerB,
                    onTap: _toggleChance,
                  ),
                  if (_upcomingSkippers.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _SkipReminderCard(players: _upcomingSkippers),
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
                        ? const LinearGradient(
                        colors: [TouchlyColors.yellow, TouchlyColors.yellowDeep])
                        : null,
                    color: _canConfirm ? null : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _canConfirm
                        ? [
                      BoxShadow(
                          color: TouchlyColors.yellow.withOpacity(0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 6)),
                    ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '✅  Confirmer et continuer',
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

// ─────────────────────────────────────────────
//  Rappel : joueurs exclus de cette manche
// ─────────────────────────────────────────────
class _ExcludedReminderCard extends StatelessWidget {
  final List<GamePlayer> players;
  const _ExcludedReminderCard({required this.players});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TouchlyColors.warn.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TouchlyColors.warn.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('🖐️', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            players.length > 1
                ? 'Exclus de cette manche (touche avant le GO)'
                : 'Exclu de cette manche (touche avant le GO)',
            style: const TextStyle(
                color: TouchlyColors.warn,
                fontSize: 12.5,
                fontWeight: FontWeight.w900),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        '${players.map((p) => p.name).join(', ')} — pas de point, pas de bombe, pas de chance sur cette question. Retour au jeu dès la prochaine.',
        style: TextStyle(
            color: TouchlyColors.textSub.withOpacity(0.9),
            fontSize: 12,
            height: 1.4),
      ),
    ]),
  );
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

class _PlayerChipGrid extends StatelessWidget {
  final List<GamePlayer> players;
  final Set<String> selected;
  final Color accent;
  final ValueChanged<String> onTap;

  /// Joueurs déjà assignés à une AUTRE catégorie pour cette manche.
  /// Ils sont grisés et non cliquables — un joueur ne peut recevoir
  /// qu'une seule carte par manche.
  final Set<String> disabledIds;

  const _PlayerChipGrid({
    required this.players,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.disabledIds = const {},
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
        final isDisabled = disabledIds.contains(p.id);
        final color = TouchlyColors.avatarPalette[idx % TouchlyColors.avatarPalette.length];

        return GestureDetector(
          onTap: isDisabled ? null : () => onTap(p.id),
          child: Opacity(
            opacity: isDisabled ? 0.35 : 1.0,
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
                        : isDisabled
                        ? Icon(Icons.lock_rounded, size: 12, color: color.withOpacity(0.8))
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
          if (candidates.isEmpty)
            Text(
              'Aucun joueur disponible pour la redirection (tous déjà assignés).',
              style: TextStyle(color: TouchlyColors.textSub.withOpacity(0.7), fontSize: 11.5),
            )
          else
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