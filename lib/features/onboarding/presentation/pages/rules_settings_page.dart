import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────
//  Design tokens Touchly (identiques à l'onboarding)
// ─────────────────────────────────────────────
const _bgBottom    = Color(0xFF060E30);
const _bgMid       = Color(0xFF0A2A6E);
const _bgTop       = Color(0xFF1A5AE8);
const _yellow      = Color(0xFFFFD700);
const _navy        = Color(0xFF0A1A4E);
const _textPrimary = Color(0xFFFFFFFF);
const _textSub     = Color(0xFFB3C8F0);
const _cardBg      = Color(0xFF0D3A8E);
// ─────────────────────────────────────────────

class RulesSettingsPage extends StatefulWidget {
  const RulesSettingsPage({super.key});

  @override
  State<RulesSettingsPage> createState() => _RulesSettingsPageState();
}

class _RulesSettingsPageState extends State<RulesSettingsPage> {
  String _selectedLanguage = 'Français';
  String _selectedRegion   = 'France';

  // ── Ouvre un lien externe (placeholder vide pour l'instant) ──
  Future<void> _openLink(String url, {String label = 'Lien'}) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            '$label — bientôt disponible',
            style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPicker(
      BuildContext context, {
        required String title,
        required List<String> options,
        required String current,
        required ValueChanged<String> onSelect,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        decoration: const BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                decoration: BoxDecoration(
                  color: _textSub.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((o) {
              final selected = o == current;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  o,
                  style: TextStyle(
                    color: selected ? _yellow : _textPrimary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: _yellow)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(o);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgMid, _bgBottom],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -70, right: -60,
                child: _GlowBlob(size: 240, color: _yellow.withOpacity(0.05))),
            Positioned(bottom: -90, left: -70,
                child: _GlowBlob(size: 280, color: const Color(0xFF2979FF).withOpacity(0.12))),

            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _Header(onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 26),

                  _SectionCard(children: [
                    _LinkTile(
                      icon: Icons.sports_esports_rounded,
                      accent: const Color(0xFF6366F1),
                      label: 'Comment jouer',
                      onTap: () => _openLink('', label: 'Comment jouer'),
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.help_outline_rounded,
                      accent: const Color(0xFF10B981),
                      label: 'Foire aux questions',
                      onTap: () => _openLink('', label: 'FAQ'),
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.campaign_rounded,
                      accent: _yellow,
                      label: 'Actualités & mises à jour',
                      onTap: () => _openLink('', label: 'Actualités'),
                    ),
                  ]),

                  const SizedBox(height: 28),
                  const _SectionLabel('SUIVEZ-NOUS'),
                  const SizedBox(height: 12),
                  _SocialRow(onTap: _openLink),

                  const SizedBox(height: 28),
                  const _SectionLabel("PARAMÈTRES DE L'APPLICATION"),
                  const SizedBox(height: 12),
                  _SectionCard(children: [
                    _LinkTile(
                      icon: Icons.public_rounded,
                      accent: const Color(0xFF2979FF),
                      label: 'Région',
                      trailingText: _selectedRegion,
                      onTap: () => _showPicker(
                        context,
                        title: 'Région',
                        options: const ['France', 'Belgique', 'Suisse', 'Canada'],
                        current: _selectedRegion,
                        onSelect: (v) => setState(() => _selectedRegion = v),
                      ),
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.language_rounded,
                      accent: const Color(0xFF6366F1),
                      label: 'Langue',
                      trailingText: _selectedLanguage,
                      onTap: () => _showPicker(
                        context,
                        title: 'Langue',
                        options: const ['Français', 'English', 'Español'],
                        current: _selectedLanguage,
                        onSelect: (v) => setState(() => _selectedLanguage = v),
                      ),
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.privacy_tip_outlined,
                      accent: const Color(0xFF10B981),
                      label: 'Confidentialité & mentions légales',
                      onTap: () => _openLink('', label: 'Confidentialité'),
                    ),
                  ]),

                  const SizedBox(height: 28),
                  const _SectionLabel('TOUCHLY'),
                  const SizedBox(height: 12),
                  _SectionCard(children: [
                    _LinkTile(
                      icon: Icons.star_border_rounded,
                      accent: _yellow,
                      label: "Noter l'application",
                      trailingIcon: Icons.chevron_right_rounded,
                      onTap: () => _openLink('', label: 'Notation'),
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.ios_share_rounded,
                      accent: const Color(0xFF2979FF),
                      label: "Partager l'application",
                      trailingIcon: Icons.chevron_right_rounded,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // TODO: brancher le package `share_plus`
                        // Share.share('Découvre Touchly, le jeu des grandes soirées 🎉');
                      },
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.mail_outline_rounded,
                      accent: const Color(0xFF10B981),
                      label: 'Nous contacter',
                      onTap: () => _openLink('', label: 'Contact'),
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.flag_outlined,
                      accent: const Color(0xFFEF4444),
                      label: 'Signaler un problème',
                      onTap: () => _openLink('', label: 'Signalement'),
                    ),
                    const _RowDivider(),
                    _LinkTile(
                      icon: Icons.description_outlined,
                      accent: const Color(0xFF6366F1),
                      label: "Conditions d'utilisation",
                      onTap: () => _openLink('', label: 'CGU'),
                    ),
                  ]),

                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'Touchly · v1.0.0',
                      style: TextStyle(
                        color: _textSub.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
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

// ─────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onBack();
          },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 22),
          ),
        ),
      ],
    ).let((row) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: 22),
        const Text(
          'RÈGLES &\nPARAMÈTRES',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ));
  }
}

// Petite extension utilitaire pour chaîner la construction du header
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ─────────────────────────────────────────────
//  Carte de section (fond bleu Touchly)
// ─────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: _textSub.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withOpacity(0.06),
      height: 1,
      indent: 68,
    );
  }
}

// ─────────────────────────────────────────────
//  Ligne cliquable (icône + label + trailing)
// ─────────────────────────────────────────────
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String? trailingText;
  final IconData trailingIcon;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.accent,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.trailingIcon = Icons.north_east_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: TextStyle(color: _textSub, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
              ],
              Icon(trailingIcon, color: _textSub.withOpacity(0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Réseaux sociaux
// ─────────────────────────────────────────────
class _SocialRow extends StatelessWidget {
  final Future<void> Function(String url, {String label}) onTap;
  const _SocialRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            // Remplacer par une icône de marque (ex: font_awesome_flutter) si besoin
            icon: Icons.camera_alt_outlined,
            label: 'Instagram',
            onTap: () => onTap('', label: 'Instagram'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            icon: Icons.music_note_rounded,
            label: 'TikTok',
            onTap: () => onTap('', label: 'TikTok'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            icon: Icons.facebook_rounded,
            label: 'Facebook',
            onTap: () => onTap('', label: 'Facebook'),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _textPrimary, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(color: _textSub, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Utilitaire — halo lumineux de fond
// ─────────────────────────────────────────────
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