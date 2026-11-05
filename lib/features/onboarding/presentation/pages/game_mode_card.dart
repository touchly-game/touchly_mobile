import 'package:flutter/material.dart';
import 'package:touchly/core/models/game_mode.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

class GameModeCard extends StatefulWidget {
  final GameMode mode;
  final VoidCallback onTap;
  const GameModeCard({super.key, required this.mode, required this.onTap});

  @override
  State<GameModeCard> createState() => _GameModeCardState();
}

class _GameModeCardState extends State<GameModeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final featured = mode.isFeatured;

    return ScaleTransition(
      scale: _pressScale,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Hero(
          tag: 'game_mode_${mode.id}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(featured ? 22 : 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    mode.accent.withOpacity(featured ? 0.28 : 0.16),
                    mode.accentDeep.withOpacity(featured ? 0.14 : 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: mode.accent.withOpacity(featured ? 0.6 : 0.3),
                  width: featured ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: mode.accent.withOpacity(featured ? 0.25 : 0.12),
                    blurRadius: featured ? 28 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: featured ? 64 : 54,
                    height: featured ? 64 : 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mode.accent.withOpacity(0.2),
                      border: Border.all(color: mode.accent.withOpacity(0.5), width: 1.5),
                    ),
                    child: Center(
                      child: Text(mode.emoji, style: TextStyle(fontSize: featured ? 30 : 26)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (featured)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: mode.accent.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: mode.accent.withOpacity(0.4), width: 1),
                              ),
                              child: Text('⭐ RECOMMANDÉ',
                                  style: TextStyle(
                                      color: mode.accent,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8)),
                            ),
                          ),
                        Text(mode.name,
                            style: TextStyle(
                                color: TouchlyColors.white,
                                fontSize: featured ? 19 : 16,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(mode.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: TouchlyColors.textSub,
                                fontSize: 12.5,
                                height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: mode.accent.withOpacity(0.8), size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}