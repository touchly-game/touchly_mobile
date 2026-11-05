import 'package:flutter/material.dart';
import 'package:touchly/core/models/game_mode.dart';
import 'package:touchly/features/onboarding/presentation/pages/touchly_colors.dart';


const String kGameModesRibbonText =
    "Notre application débloque des **modes de jeux inédits** et des **milliers de questions** !";

const List<GameModeTip> kGameModesTips = [
  GameModeTip(
    emoji: '💦',
    text: "N'hésite pas à rincer la main de temps en temps afin de retrouver du collant",
  ),
  GameModeTip(
    emoji: '🎭',
    text: "Essaye de feinter ton adversaire pour le faire lancer avant le GO et le pénaliser d'un tour",
  ),
  GameModeTip(
    emoji: '🎯',
    text: "Sans certitude ? Vise une bombe et renvoie-la avec ta carte détournement",
  ),
  GameModeTip(
    emoji: '🪃',
    text: "Lancer la main en cloche avec force permet de coller une plus grande surface de carte",
  ),
];

final List<GameMode> kGameModes = [
  // ── Mode Classique — mode principal, mis en avant ───────────────
  GameMode(
    id: GameModeId.classic,
    name: 'Mode Classique',
    tagline: 'Le mode de base — simple, rapide, addictif',
    emoji: '⭐',
    icon: Icons.emoji_events_rounded,
    accent: TouchlyColors.yellow,
    accentDeep: TouchlyColors.yellowDeep,
    isFeatured: true,
    steps: [
      const GameModeStep(
        emoji: '👥',
        icon: Icons.groups_rounded,
        title: 'Configuration',
        kind: StepKind.specs,
        specStats: ['2-6|Joueurs', '14+|Âge', '15-30|Minutes'],
      ),
      const GameModeStep(
        emoji: '🏆',
        icon: Icons.emoji_events_rounded,
        title: 'But du jeu',
        kind: StepKind.paragraph,
        paragraph:
        "Sois le premier joueur à obtenir **5 points**. Chaque bonne carte attrapée rapporte **1 point**. Rapidité et précision sont tes meilleurs alliés.",
      ),
      const GameModeStep(
        emoji: '🎮',
        icon: Icons.sports_esports_rounded,
        title: 'Mise en place',
        kind: StepKind.numberedList,
        numberedItems: [
          'Place les cartes réponses **A, B, C** au centre de la table',
          'Dispose les cartes **Chance** et **Bombes** autour',
          'Chaque joueur reçoit une **main élastique**',
          'Mélange le paquet de **cartes Questions**',
        ],
      ),
      const GameModeStep(
        emoji: '⚡',
        icon: Icons.bolt_rounded,
        title: "Déroulement d'un tour",
        kind: StepKind.numberedList,
        numberedItems: [
          'Un joueur lit la **question** à voix haute',
          'Il annonce les **3 réponses** possibles (A, B, C)',
          'Il compte **3... 2... 1...** puis crie **« GO ! »**',
          'Tous les joueurs **lancent leur main élastique** pour attraper la bonne carte',
          'Le **premier** sur la bonne réponse gagne 1 point',
          "En cas d'égalité, **personne ne marque**",
        ],
      ),
      GameModeStep(
        emoji: '💣',
        icon: Icons.dangerous_rounded,
        title: 'Cartes Bombes',
        kind: StepKind.dangerBox,
        paragraph:
        "Aïe ! Si tu attrapes une bombe, tu **passes le prochain tour** — et elle reste devant toi.",
        dangerBadge: 'Boom !',
        dangerBold: '3 bombes devant toi = ÉLIMINATION de la partie !',
        specialAccent: TouchlyColors.danger,
      ),
      GameModeStep(
        emoji: '🍀',
        icon: Icons.spa_rounded,
        title: 'Cartes Chance',
        kind: StepKind.chanceList,
        paragraph: 'Ton joker contre les bombes — joue-la au bon moment :',
        chanceItems: const [
          ['🛡️', 'Désamorçage', 'Annule une bombe que tu viens de toucher'],
          ['⬅️', 'Redirection gauche', 'Détourne la bombe vers ton voisin de gauche'],
          ['➡️', 'Redirection droite', 'Détourne la bombe vers ton voisin de droite'],
        ],
        specialAccent: TouchlyColors.correct,
      ),
      GameModeStep(
        emoji: '🏆',
        icon: Icons.emoji_events_rounded,
        title: 'Victoire !',
        kind: StepKind.paragraph,
        paragraph:
        "Le premier joueur à attraper **5 bonnes cartes** remporte la partie ! Prépare-toi pour une **revanche immédiate** — personne ne s'arrête après une seule manche.",
        specialAccent: TouchlyColors.yellowDeep,
      ),
    ],
  ),

  // ── Mode Démineur ────────────────────────────────────────────────
  GameMode(
    id: GameModeId.demineur,
    name: 'Mode Démineur',
    tagline: 'Les cartes Chance et Bombe se cachent parmi les réponses',
    emoji: '🕵️',
    icon: Icons.gps_fixed_rounded,
    accent: TouchlyColors.answerA,
    accentDeep: const Color(0xFF4338CA),
    simpleRules: const [
      '3 cartes réponses **A/B/C** au centre',
      'Mélangez les cartes **Chance** & **Bombe** et disposez-les au hasard, faces cachées',
      'Les cartes **Chance** & **Bombe** utilisées sont toujours remises en jeu',
    ],
  ),

  // ── Mode Pioche ──────────────────────────────────────────────────
  GameMode(
    id: GameModeId.pioche,
    name: 'Mode Pioche',
    tagline: 'Le gagnant distribue les cartes — stratégie garantie',
    emoji: '🃏',
    icon: Icons.style_rounded,
    accent: TouchlyColors.danger,
    accentDeep: const Color(0xFFB91C1C),
    simpleRules: const [
      '3 cartes réponses **A/B/C** au centre',
      '2 pioches : les **Chance** sont face cachée & les **Bombe** visibles',
      'À chaque bonne réponse, le gagnant pioche une carte **Chance** ou distribue une **Bombe** à un joueur',
      'Seule la règle des 3 bombes est active — aucune pénalité pour une seule **Bombe**',
      'Le **dernier joueur en jeu** ou le **premier à 5 points** gagne la partie',
    ],
  ),

  // ── Mode Équipe ──────────────────────────────────────────────────
  GameMode(
    id: GameModeId.equipe,
    name: 'Mode Équipe',
    tagline: 'Joue en duo, combine les modes, gagne ensemble',
    emoji: '🤝',
    icon: Icons.groups_2_rounded,
    accent: TouchlyColors.correct,
    accentDeep: const Color(0xFF15803D),
    simpleRules: const [
      '3 cartes réponses **A/B/C** au centre',
      'Les deux équipiers se placent du même côté',
      'Choisissez parmi les modes **classique / pioche / démineur**',
      'Seule la règle des 3 bombes est active — aucune pénalité pour une seule **Bombe**',
      'Le **dernier duo en jeu** ou le **premier duo à 5 points** gagne la partie',
    ],
  ),
];