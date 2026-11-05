import 'package:flutter/material.dart';

enum GameModeId { classic, demineur, pioche, equipe }

/// Type de contenu d'une étape de règles (mode Classique uniquement,
/// qui a besoin de plusieurs présentations différentes selon l'étape :
/// stats de config, paragraphe, liste numérotée, cartes Chance, alerte
/// danger...).
enum StepKind { specs, paragraph, numberedList, chanceList, dangerBox }

class GameModeStep {
  final String emoji;
  final IconData icon;
  final String title;
  final StepKind kind;

  /// StepKind.specs — paires "valeur|label", ex: "2-6|Joueurs"
  final List<String> specStats;

  /// StepKind.paragraph
  final String? paragraph;

  /// StepKind.numberedList
  final List<String> numberedItems;

  /// StepKind.chanceList — triplets [emoji, label, texte]
  final List<List<String>> chanceItems;

  /// StepKind.dangerBox
  final String? dangerIntro;
  final String? dangerBadge;
  final String? dangerBold;

  /// Étape "spéciale" (bombe/chance/victoire) → accent visuel dédié
  final Color? specialAccent;

  const GameModeStep({
    required this.emoji,
    required this.icon,
    required this.title,
    required this.kind,
    this.specStats = const [],
    this.paragraph,
    this.numberedItems = const [],
    this.chanceItems = const [],
    this.dangerIntro,
    this.dangerBadge,
    this.dangerBold,
    this.specialAccent,
  });
}

class GameModeTip {
  final String emoji;
  final String text;
  const GameModeTip({required this.emoji, required this.text});
}

class GameMode {
  final GameModeId id;
  final String name;
  final String tagline;
  final String emoji;
  final IconData icon;
  final Color accent;
  final Color accentDeep;
  final bool isFeatured;

  /// Mode Classique uniquement : parcours détaillé étape par étape.
  final List<GameModeStep> steps;

  /// Modes alternatifs uniquement : règles courtes en puces.
  /// Supporte le markdown minimal **gras**.
  final List<String> simpleRules;

  bool get isClassic => steps.isNotEmpty;

  const GameMode({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.icon,
    required this.accent,
    required this.accentDeep,
    this.isFeatured = false,
    this.steps = const [],
    this.simpleRules = const [],
  });
}