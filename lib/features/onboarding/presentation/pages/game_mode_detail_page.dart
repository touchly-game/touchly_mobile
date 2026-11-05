import 'package:flutter/material.dart';
import 'package:touchly/core/models/game_mode.dart';
import 'package:touchly/features/onboarding/presentation/pages/bold_accent_text.dart';
import 'package:touchly/features/onboarding/presentation/pages/game_mode_data.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';

class GameModeDetailPage extends StatelessWidget {
  final GameMode mode;
  const GameModeDetailPage({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: TouchlyColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _DetailHeader(mode: mode),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (mode.isClassic)
                      ...List.generate(
                        mode.steps.length,
                            (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _StepCard(
                            step: mode.steps[i],
                            index: i + 1,
                            defaultAccent: mode.accent,
                          ),
                        ),
                      )
                    else
                      _SimpleRulesCard(mode: mode),

                    const SizedBox(height: 8),
                    _TipsCard(),
                    const SizedBox(height: 16),
                    const _AppRibbon(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final GameMode mode;
  const _DetailHeader({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
      child: Hero(
        tag: 'game_mode_${mode.id}',
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: TouchlyColors.white, size: 18),
              ),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mode.accent.withOpacity(0.2),
                  border: Border.all(color: mode.accent.withOpacity(0.5), width: 1.5),
                ),
                child: Center(child: Text(mode.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.name,
                        style: const TextStyle(
                            color: TouchlyColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    Text(mode.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: TouchlyColors.textSub, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Mode Classique — carte d'étape (timeline)
// ─────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final GameModeStep step;
  final int index;
  final Color defaultAccent;
  const _StepCard({required this.step, required this.index, required this.defaultAccent});

  Color get _accent => step.specialAccent ?? defaultAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: _accent.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withOpacity(0.18),
                  border: Border.all(color: _accent.withOpacity(0.5), width: 1.5),
                ),
                child: Center(
                  child: Text('$index',
                      style: TextStyle(color: _accent, fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Text(step.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(step.title,
                    style: const TextStyle(
                        color: TouchlyColors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (step.kind) {
      case StepKind.specs:
        return Row(
          children: step.specStats.map((s) {
            final parts = s.split('|');
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Text(parts[0],
                        style: TextStyle(
                            color: _accent, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(parts[1].toUpperCase(),
                        style: TextStyle(
                            color: TouchlyColors.textSub.withOpacity(0.8),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ],
                ),
              ),
            );
          }).toList(),
        );

      case StepKind.paragraph:
        return BoldAccentText(
          text: step.paragraph ?? '',
          accentColor: _accent,
          baseStyle: const TextStyle(color: TouchlyColors.textSub, fontSize: 13.5, height: 1.5),
        );

      case StepKind.numberedList:
        return Column(
          children: step.numberedItems.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withOpacity(0.18),
                      border: Border.all(color: _accent.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text('${e.key + 1}',
                          style: TextStyle(
                              color: _accent, fontSize: 10.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BoldAccentText(
                      text: e.value,
                      accentColor: _accent,
                      baseStyle: const TextStyle(
                          color: TouchlyColors.textSub, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );

      case StepKind.chanceList:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step.paragraph != null) ...[
              BoldAccentText(
                text: step.paragraph!,
                accentColor: _accent,
                baseStyle: const TextStyle(color: TouchlyColors.textSub, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
            ],
            ...step.chanceItems.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Text(item[0], style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: TouchlyColors.textSub, fontSize: 12.5, height: 1.4),
                        children: [
                          TextSpan(
                              text: '${item[1]} : ',
                              style: const TextStyle(
                                  color: TouchlyColors.white, fontWeight: FontWeight.w800)),
                          TextSpan(text: item[2]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        );

      case StepKind.dangerBox:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step.paragraph != null)
              BoldAccentText(
                text: step.paragraph!,
                accentColor: _accent,
                baseStyle: const TextStyle(color: TouchlyColors.textSub, fontSize: 13.5, height: 1.4),
              ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TouchlyColors.navy.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accent.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step.dangerBadge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(step.dangerBadge!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  const SizedBox(height: 8),
                  BoldAccentText(
                    text: step.dangerBold ?? '',
                    accentColor: TouchlyColors.yellow,
                    baseStyle: const TextStyle(
                        color: TouchlyColors.white, fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

// ─────────────────────────────────────────────
//  Modes alternatifs — règles courtes
// ─────────────────────────────────────────────
class _SimpleRulesCard extends StatelessWidget {
  final GameMode mode;
  const _SimpleRulesCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [mode.accent.withOpacity(0.16), mode.accentDeep.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: mode.accent.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📋', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Text('Règles',
                style: TextStyle(color: TouchlyColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          ...mode.simpleRules.map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mode.accent,
                    border: Border.all(color: TouchlyColors.white.withOpacity(0.4)),
                  ),
                ),
                Expanded(
                  child: BoldAccentText(
                    text: rule,
                    accentColor: mode.accent,
                    baseStyle: const TextStyle(
                        color: TouchlyColors.white, fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Astuces & stratégies
// ─────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          TouchlyColors.yellow.withOpacity(0.16),
          TouchlyColors.yellow.withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TouchlyColors.yellow.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_rounded, color: TouchlyColors.yellow, size: 18),
            const SizedBox(width: 8),
            const Text('Astuces & stratégies',
                style: TextStyle(color: TouchlyColors.yellow, fontSize: 13, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 14),
          ...kGameModesTips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tip.text,
                      style: const TextStyle(
                          color: TouchlyColors.white, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Ruban promo app
// ─────────────────────────────────────────────
class _AppRibbon extends StatelessWidget {
  const _AppRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TouchlyColors.navy.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smartphone_rounded, color: TouchlyColors.textSub, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: BoldAccentText(
              text: kGameModesRibbonText,
              accentColor: TouchlyColors.yellow,
              baseStyle: const TextStyle(color: TouchlyColors.textSub, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}