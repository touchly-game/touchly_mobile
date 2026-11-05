import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchly/core/models/game_mode.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_mode_card.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_mode_detail_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

import 'game_mode_data.dart';

class GameModesPage extends StatefulWidget {
  const GameModesPage({super.key});

  @override
  State<GameModesPage> createState() => _GameModesPageState();
}

class _GameModesPageState extends State<GameModesPage>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + kGameModes.length * 90),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _openMode(int index) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameModeDetailPage(mode: kGameModes[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: TouchlyColors.backgroundGradient),
        child: Stack(
          children: [
            Positioned(top: -60, right: -50,
                child: _GlowBlob(size: 240, color: TouchlyColors.yellow.withOpacity(0.08))),
            Positioned(bottom: 100, left: -60,
                child: _GlowBlob(size: 200, color: TouchlyColors.bgLight.withOpacity(0.14))),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 20, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: TouchlyColors.white, size: 18),
                        ),
                        const Text('Modes de jeu',
                            style: TextStyle(
                                color: TouchlyColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Une boîte, plusieurs façons de jouer',
                        style: TextStyle(
                            color: TouchlyColors.textSub.withOpacity(0.9), fontSize: 13.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      itemCount: kGameModes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final start = (index * 0.12).clamp(0.0, 0.6);
                        final anim = CurvedAnimation(
                          parent: _entrance,
                          curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
                              curve: Curves.easeOutCubic),
                        );
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                begin: const Offset(0, 0.08), end: Offset.zero)
                                .animate(anim),
                            child: GameModeCard(
                              mode: kGameModes[index],
                              onTap: () => _openMode(index),
                            ),
                          ),
                        );
                      },
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

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}