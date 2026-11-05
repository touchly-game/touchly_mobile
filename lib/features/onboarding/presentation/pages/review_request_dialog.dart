import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _yellow      = Color(0xFFFFD700);
const _navy        = Color(0xFF0A1A4E);
const _textPrimary = Color(0xFFFFFFFF);
const _textSub     = Color(0xFFB3C8F0);

// ─────────────────────────────────────────────
//  ReviewRequestService
//  Règles d'affichage :
//  • 1 fois par session (flag statique)
//  • jamais si opt-out ("Ne plus afficher")
//  • jamais si un avis a déjà été laissé
// ─────────────────────────────────────────────
class ReviewRequestService {
  ReviewRequestService._();

  static const _kOptOutKey    = 'review_popup_opt_out';
  static const _kReviewedKey  = 'review_popup_reviewed';

  static bool _shownThisSession = false;

  static void resetSession() => _shownThisSession = false;

  static Future<void> maybeShow(
      BuildContext context, {
        Duration delay = const Duration(seconds: 2),
      }) async {
    if (_shownThisSession) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kOptOutKey) ?? false) return;
    if (prefs.getBool(_kReviewedKey) ?? false) return; // déjà noté → on ne redemande pas

    await Future.delayed(delay);
    if (!context.mounted || _shownThisSession) return;

    _shownThisSession = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const ReviewRequestDialog(),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(curved),
              child: child),
        );
      },
    );
  }

  static Future<void> optOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOptOutKey, true);
  }

  static Future<void> markReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReviewedKey, true);
  }

  /// Enregistre l'avis dans Supabase (table app_reviews).
  /// Ne bloque jamais l'UI : les erreurs sont silencieuses côté user.
  static Future<void> saveReview({
    required int rating,
    String? feedback,
    required bool sentToStore,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('app_reviews').insert({
        'user_id': user?.id,
        'rating': rating,
        'feedback': feedback,
        'sent_to_store': sentToStore,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('❌ Erreur enregistrement avis: $e');
    }
  }
}

// ─────────────────────────────────────────────
//  ReviewRequestDialog
//  Étape 1 : notation étoiles
//  Étape 2a (4-5★) : redirection store natif
//  Étape 2b (1-3★) : champ feedback → Supabase
//  Étape 3 : remerciement
// ─────────────────────────────────────────────
class ReviewRequestDialog extends StatefulWidget {
  const ReviewRequestDialog({super.key});

  @override
  State<ReviewRequestDialog> createState() => _ReviewRequestDialogState();
}

enum _Step { rate, feedback, thanks }

class _ReviewRequestDialogState extends State<ReviewRequestDialog>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  _Step _step = _Step.rate;
  final _feedbackCtrl = TextEditingController();
  bool _sending = false;

  late final AnimationController _starsController;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _starsController.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────
  void _onStarTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _rating = index + 1);

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (_rating >= 4) {
        _goToStore();
      } else {
        setState(() => _step = _Step.feedback);
      }
    });
  }

  Future<void> _goToStore() async {
    // Enregistre l'avis positif chez toi AVANT la redirection
    await ReviewRequestService.saveReview(
      rating: _rating == 0 ? 5 : _rating,
      sentToStore: true,
    );
    await ReviewRequestService.markReviewed();

    if (mounted) Navigator.of(context).pop();

    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    } else {
      await inAppReview.openStoreListing(
        appStoreId: 'TON_APP_STORE_ID', // ← à remplacer (iOS)
      );
    }
  }

  Future<void> _sendFeedback() async {
    setState(() => _sending = true);
    await ReviewRequestService.saveReview(
      rating: _rating,
      feedback: _feedbackCtrl.text.trim().isEmpty
          ? null
          : _feedbackCtrl.text.trim(),
      sentToStore: false,
    );
    await ReviewRequestService.markReviewed();
    if (mounted) setState(() { _sending = false; _step = _Step.thanks; });
    // Fermeture auto après le remerciement
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _later() => Navigator.of(context).pop();

  Future<void> _never() async {
    await ReviewRequestService.optOut();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: 28, right: 28,
          // Remonte le dialog quand le clavier s'ouvre (étape feedback)
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 40 : 0,
        ),
        child: Material(
          color: Colors.transparent,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF12409F), Color(0xFF0A2A6E)],
                ),
                borderRadius: BorderRadius.circular(26),
                border:
                Border.all(color: Colors.white.withOpacity(0.14), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: _yellow.withOpacity(0.10),
                    blurRadius: 60,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: switch (_step) {
                _Step.rate     => _buildRateStep(),
                _Step.feedback => _buildFeedbackStep(),
                _Step.thanks   => _buildThanksStep(),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Étape 1 : étoiles ─────────────────────
  Widget _buildRateStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: _CloseButton(onTap: _later),
        ),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _yellow.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _yellow.withOpacity(0.30), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _yellow.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(child: Text('💛', style: TextStyle(fontSize: 30))),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tu t’amuses bien ?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary, fontSize: 19,
            fontWeight: FontWeight.w900, letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Ton avis nous aide énormément à faire\ngrandir Touchly. Ça prend 30 secondes !',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSub, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final anim = CurvedAnimation(
              parent: _starsController,
              curve: Interval(i * 0.12, 0.6 + i * 0.08,
                  curve: Curves.easeOutBack),
            );
            final filled = i < _rating;
            return ScaleTransition(
              scale: anim,
              child: GestureDetector(
                onTap: () => _onStarTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedScale(
                    scale: filled ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 38,
                      color: filled ? _yellow : _textSub.withOpacity(0.45),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 22),
        _SecondaryButton(label: 'Plus tard', onTap: _later),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _never,
          child: Text(
            'Ne plus afficher',
            style: TextStyle(
              color: _textSub.withOpacity(0.55),
              fontSize: 12, fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: _textSub.withOpacity(0.35),
            ),
          ),
        ),
      ],
    );
  }

  // ── Étape 2b : feedback (notes 1-3) ───────
  Widget _buildFeedbackStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: _CloseButton(onTap: _later),
        ),
        const Text('🛠️', style: TextStyle(fontSize: 34)),
        const SizedBox(height: 12),
        const Text(
          'Merci pour ta franchise !',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary, fontSize: 18,
            fontWeight: FontWeight.w900, letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Dis-nous ce qu’on peut améliorer,\non lit tous les messages 👀',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSub, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: TextField(
            controller: _feedbackCtrl,
            maxLines: 4,
            maxLength: 500,
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            cursorColor: _yellow,
            decoration: InputDecoration(
              hintText: 'Ex : les questions sont trop dures, il manque…',
              hintStyle:
              TextStyle(color: _textSub.withOpacity(0.5), fontSize: 13),
              counterStyle:
              TextStyle(color: _textSub.withOpacity(0.4), fontSize: 10),
              contentPadding: const EdgeInsets.all(14),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _sending ? null : _sendFeedback,
          child: Container(
            width: double.infinity, height: 50,
            decoration: BoxDecoration(
              gradient:
              const LinearGradient(colors: [_yellow, Color(0xFFFFB300)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _yellow.withOpacity(0.40),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: _sending
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: _navy),
              )
                  : const Text(
                '📨  Envoyer mon retour',
                style: TextStyle(
                  color: _navy, fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Étape 3 : merci ───────────────────────
  Widget _buildThanksStep() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🙏', style: TextStyle(fontSize: 42)),
          SizedBox(height: 12),
          Text(
            'Merci beaucoup !',
            style: TextStyle(
              color: _textPrimary, fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Ton retour a bien été envoyé.',
            style: TextStyle(color: _textSub, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Petits widgets partagés
// ─────────────────────────────────────────────
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: const Icon(Icons.close_rounded, color: _textSub, size: 16),
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: _textSub, fontSize: 13, fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}