import 'dart:math';
import 'package:flutter/material.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_player.dart';
import 'package:touchly/features/onboarding/presentation/pages/home_page.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

class VictoryPage extends StatefulWidget {
  final GamePlayer winner;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const VictoryPage({
    super.key,
    required this.winner,
    required this.onReplay,
    required this.onHome,
  });

  @override
  State<VictoryPage> createState() => _VictoryPageState();
}

class _VictoryPageState extends State<VictoryPage> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _confetti;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _confetti = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: TouchlyColors.backgroundGradient),
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_confetti.value)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(children: [
                Expanded(
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
                    child: FadeTransition(
                      opacity: _entrance,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(alignment: Alignment.center, children: [
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: TouchlyColors.yellow.withOpacity(0.08),
                              ),
                            ),
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: TouchlyColors.yellow.withOpacity(0.16),
                                border: Border.all(
                                    color: TouchlyColors.yellow.withOpacity(0.4), width: 2),
                              ),
                            ),
                            const Text('👑', style: TextStyle(fontSize: 68)),
                          ]),
                          const SizedBox(height: 24),
                          const Text('VICTOIRE !',
                              style: TextStyle(
                                  color: TouchlyColors.yellow,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(widget.winner.name,
                              style: const TextStyle(
                                  color: TouchlyColors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            'remporte la partie avec ${widget.winner.points} bonnes réponses !',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: TouchlyColors.textSub, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _VictoryButton(label: '🔄  Rejouer', primary: true, onTap: widget.onReplay),
                const SizedBox(height: 12),
                _VictoryButton(
                    label: '🏠  Retour à l\'accueil', primary: false,
                    onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const GameHomePage()),
                      (_) => false,
                ),),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _VictoryButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _VictoryButton({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: primary ? TouchlyColors.primaryButtonGradient : null,
        color: primary ? null : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: primary ? null : Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: primary
            ? [
          BoxShadow(
              color: TouchlyColors.yellow.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 6)),
        ]
            : null,
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                color: primary ? TouchlyColors.navy : TouchlyColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900)),
      ),
    ),
  );
}

/// Pluie de confettis dessinée en CustomPainter — pas de dépendance
/// externe, léger, et parfaitement fluide.
class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static final _rand = Random(42);
  static final List<_ConfettiParticle> _particles = List.generate(
    40,
        (i) => _ConfettiParticle(
      x: _rand.nextDouble(),
      speed: 0.3 + _rand.nextDouble() * 0.7,
      size: 4 + _rand.nextDouble() * 5,
      color: [
        TouchlyColors.yellow,
        TouchlyColors.correct,
        TouchlyColors.answerB,
        TouchlyColors.answerC,
        TouchlyColors.answerA,
      ][_rand.nextInt(5)],
      phase: _rand.nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final progress = (t * p.speed + p.phase) % 1.0;
      final dx = p.x * size.width + sin(progress * pi * 4) * 14;
      final dy = progress * size.height;
      paint.color = p.color.withOpacity(1 - progress * 0.4);
      canvas.drawCircle(Offset(dx, dy), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class _ConfettiParticle {
  final double x, speed, size, phase;
  final Color color;
  _ConfettiParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.phase,
  });
}