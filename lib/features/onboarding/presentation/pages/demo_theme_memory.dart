import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise localement (SharedPreferences) le thème joué pendant la
/// démo — avant inscription — pour pouvoir le proposer à l'utilisateur
/// une fois connecté sur GameHomePage.
///
/// Pourquoi pas juste un paramètre de navigation ? Parce que le
/// parcours Démo → Register → Activation → Login → Home traverse
/// plusieurs écrans indépendants ; propager un `themeId` à la main à
/// travers chacun d'eux est fragile (un seul maillon oublié = perdu).
/// Le stockage local sert de "mémoire" fiable, lue une seule fois à
/// l'arrivée sur la home.
class DemoThemeMemory {
  DemoThemeMemory._();

  static const _key = 'touchly_demo_theme_id';

  static Future<void> save(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, themeId);
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}