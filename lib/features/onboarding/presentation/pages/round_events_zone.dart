import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:touchly/features/game/presentation/controllers/game_session_controller.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

import 'game_player.dart';

// ═════════════════════════════════════════════════════════════
//  ROUND EVENTS ZONE
//  À placer directement dans la page Question / Réponses
//  (GamePlayPage), sous les réponses ou sous le bouton GO.
//
//  Deux états :
//  • Aucune exclusion → grande carte d'action "Touché avant le GO ?"
//  • Exclusions en cours → bannière listant les joueurs exclus
//    (avec possibilité d'annuler une erreur de saisie ou d'en
//    ajouter un autre)
//
//  La sélection d'un joueur N'AVANCE PAS la question :
//  elle marque simplement le joueur comme exclu pour la manche
//  en cours via controller.excludeForCurrentRound().
// ═════════════════════════════════════════════════════════════
class RoundEventsZone extends StatefulWidget {
  final GameSessionController controller;
  const RoundEventsZone({super.key, required this.controller});

  @override
  State<RoundEventsZone> createState() => _RoundEventsZoneState();
}

class _RoundEventsZoneState extends State<RoundEventsZone> {
  GameSessionController get c => widget.controller;

  Future<void> _openEarlyTouchSheet() async {
    HapticFeedback.mediumImpact();
    final selected = await showEarlyTouchSheet(context, controller: c);
    if (selected != null && selected.isNotEmpty) {
      c.excludeForCurrentRound(selected);
      if (mounted) setState(() {});
    }
  }

  void _reinstate(String id) {
    HapticFeedback.selectionClick();
    c.reinstateForCurrentRound(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final excluded = c.excludedThisRound;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      child: excluded.isEmpty
          ? _EarlyTouchActionCard(
        key: const ValueKey('cta'),
        onTap: _openEarlyTouchSheet,
      )
          : _ExcludedBanner(
        key: const ValueKey('banner'),
        players: excluded,
        onAddMore: _openEarlyTouchSheet,
        onReinstate: _reinstate,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Carte d'action principale
//  Visible en permanence pendant la manche :
//  l'événement fait partie du jeu, pas une option cachée.
// ─────────────────────────────────────────────
class _EarlyTouchActionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EarlyTouchActionCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              TouchlyColors.warn.withOpacity(0.18),
              TouchlyColors.warn.withOpacity(0.08),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TouchlyColors.warn.withOpacity(0.45), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: TouchlyColors.warn.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TouchlyColors.warn.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TouchlyColors.warn.withOpacity(0.4)),
              ),
              child: const Center(
                child: Text('🖐️', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Touché avant le GO ?',
                      style: TextStyle(
                          color: TouchlyColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text('Le joueur passe son tour sur cette question',
                      style: TextStyle(
                          color: TouchlyColors.textSub,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: TouchlyColors.warn.withOpacity(0.8), size: 15),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Bannière : joueurs exclus de la manche
// ─────────────────────────────────────────────
class _ExcludedBanner extends StatelessWidget {
  final List<GamePlayer> players;
  final VoidCallback onAddMore;
  final ValueChanged<String> onReinstate;

  const _ExcludedBanner({
    super.key,
    required this.players,
    required this.onAddMore,
    required this.onReinstate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          TouchlyColors.warn.withOpacity(0.16),
          TouchlyColors.warn.withOpacity(0.06),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TouchlyColors.warn.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🖐️', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Exclus de cette manche',
                    style: TextStyle(
                        color: TouchlyColors.warn,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3)),
              ),
              GestureDetector(
                onTap: onAddMore,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: const Text('+ Ajouter',
                      style: TextStyle(
                          color: TouchlyColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: players
                .map((p) => Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          color: TouchlyColors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  // Annulation d'une erreur de saisie
                  GestureDetector(
                    onTap: () => onReinstate(p.id),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 11, color: TouchlyColors.textSub),
                    ),
                  ),
                ],
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'La manche continue avec les autres joueurs — même question.',
            style: TextStyle(
                color: TouchlyColors.textSub.withOpacity(0.8),
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Sheet de sélection : qui a touché avant le GO ?
//  Multi-sélection (les règles prévoient "le ou les joueurs").
//  Retourne un Set d'ids, ou null si annulé.
// ═════════════════════════════════════════════════════════════
Future<Set<String>?> showEarlyTouchSheet(
    BuildContext context, {
      required GameSessionController controller,
    }) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EarlyTouchSheet(controller: controller),
  );
}

class _EarlyTouchSheet extends StatefulWidget {
  final GameSessionController controller;
  const _EarlyTouchSheet({required this.controller});

  @override
  State<_EarlyTouchSheet> createState() => _EarlyTouchSheetState();
}

class _EarlyTouchSheetState extends State<_EarlyTouchSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    // On ne propose que les joueurs encore éligibles sur cette manche
    final players = widget.controller.eligiblePlayersThisRound;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1F52),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Column(
                children: [
                  const Text('🖐️', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  const Text('Qui a touché avant le GO ?',
                      style: TextStyle(
                          color: TouchlyColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    'Sélectionne le ou les joueurs. Ils ne participeront\npas à cette question, puis reviendront à la suivante.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: TouchlyColors.textSub.withOpacity(0.9),
                        fontSize: 12.5,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: players.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  final isSelected = _selected.contains(p.id);
                  final color = TouchlyColors.avatarPalette[
                  idx % TouchlyColors.avatarPalette.length];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        isSelected
                            ? _selected.remove(p.id)
                            : _selected.add(p.id);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TouchlyColors.warn.withOpacity(0.22)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? TouchlyColors.warn.withOpacity(0.7)
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? TouchlyColors.warn
                                : color.withOpacity(0.35),
                          ),
                          child: Center(
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                size: 14, color: TouchlyColors.navy)
                                : Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(p.name,
                            style: TextStyle(
                                color: isSelected
                                    ? TouchlyColors.white
                                    : TouchlyColors.textSub,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Center(
                          child: Text('Annuler',
                              style: TextStyle(
                                  color: TouchlyColors.textSub,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: _selected.isEmpty
                          ? null
                          : () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, _selected);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: _selected.isNotEmpty
                              ? const LinearGradient(colors: [
                            TouchlyColors.warn,
                            Color(0xFFFF8C5A)
                          ])
                              : null,
                          color: _selected.isEmpty
                              ? Colors.white.withOpacity(0.06)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _selected.isNotEmpty
                              ? [
                            BoxShadow(
                              color:
                              TouchlyColors.warn.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _selected.length > 1
                                ? '⏸️  Exclure ces joueurs'
                                : '⏸️  Exclure pour cette manche',
                            style: TextStyle(
                                color: _selected.isNotEmpty
                                    ? TouchlyColors.navy
                                    : TouchlyColors.textSub.withOpacity(0.5),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}