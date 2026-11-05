import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
/// Nombre de points crédités pour une partie menée jusqu'au bout
/// (victoire à 5 points OU fin du paquet de questions). Un seul
/// crédit par partie complète — pas de gain par manche.
const int kPointsPerCompletedGame = 10;

class UserPoints {
  final int balance;
  final int lifetime;
  const UserPoints({required this.balance, required this.lifetime});

  factory UserPoints.fromMap(Map<String, dynamic> m) => UserPoints(
    balance: (m['points_balance'] as int?) ?? 0,
    lifetime: (m['points_lifetime'] as int?) ?? 0,
  );

  static const zero = UserPoints(balance: 0, lifetime: 0);
}

class PointsService {
  PointsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Récupère le solde et le total à vie de l'utilisateur connecté.
  /// Retourne `UserPoints.zero` si non connecté ou en cas d'erreur —
  /// ne bloque jamais l'affichage de la home page.
  static Future<UserPoints> fetchCurrentUserPoints() async {
    final user = _client.auth.currentUser;
    if (user == null) return UserPoints.zero;

    try {
      final data = await _client
          .from('app_users')
          .select('points_balance, points_lifetime')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return UserPoints.zero;
      return UserPoints.fromMap(data);
    } catch (e) {
      // Échec silencieux : les points sont un bonus, pas un blocant.
      return UserPoints.zero;
    }
  }

  static Future<void> awardGameCompleted() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('❌ Aucun utilisateur connecté');
      return;
    }
    try {
      final result = await _client.rpc('award_game_points', params: {
        'p_points': kPointsPerCompletedGame,
      });
      debugPrint('✅ Points crédités: $result');
    } catch (e) {
      debugPrint('❌ Erreur award_game_points: $e');
    }
  }

  static Future<bool> redeemThemeWithPoints(String themeId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final result = await _client.rpc('redeem_theme_with_points', params: {
        'p_user_id': user.id,
        'p_theme_id': themeId,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }
}