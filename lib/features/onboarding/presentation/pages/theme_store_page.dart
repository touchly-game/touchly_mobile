import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:touchly/core/models/app_theme.dart';
import 'package:touchly/features/onboarding/presentation/pages/points_service.dart';


// ─────────────────────────────────────────────
//  Design tokens Touchly
// ─────────────────────────────────────────────
const _bgLight       = Color(0xFF2979FF);
const _surface       = Color(0xFF0D3A8E);
const _surfaceBorder = Color(0xFF1A4DB5);
const _yellow        = Color(0xFFFFD700);
const _navy          = Color(0xFF0A1A4E);
const _textPrimary   = Color(0xFFFFFFFF);
const _textSub       = Color(0xFFB3C8F0);
const _successColor  = Color(0xFF3DD68C);
const _errorColor    = Color(0xFFFF5A7D);
const _purple        = Color(0xFF7C3AED);
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  CartManager — singleton en mémoire
// ─────────────────────────────────────────────
class CartManager extends ChangeNotifier {
  static final CartManager _instance = CartManager._();
  factory CartManager() => _instance;
  CartManager._();

  final List<AppTheme> _items = [];

  List<AppTheme> get items => List.unmodifiable(_items);
  int    get count => _items.length;
  double get total => _items.fold(0.0, (s, t) => s + (t.price ?? 0.0));
  bool contains(String id) => _items.any((t) => t.id == id);

  void add(AppTheme theme) {
    if (!contains(theme.id)) { _items.add(theme); notifyListeners(); }
  }
  void remove(String id) {
    _items.removeWhere((t) => t.id == id); notifyListeners();
  }
  void clear() { _items.clear(); notifyListeners(); }
}

// ─────────────────────────────────────────────
//  ThemeStorePage
// ─────────────────────────────────────────────
class ThemeStorePage extends StatefulWidget {
  final VoidCallback? onPurchase;
  const ThemeStorePage({super.key, this.onPurchase});

  @override
  State<ThemeStorePage> createState() => _ThemeStorePageState();
}

class _ThemeStorePageState extends State<ThemeStorePage>
    with SingleTickerProviderStateMixin {
  List<AppTheme> _themes   = [];
  List<String>   _ownedIds = [];
  bool           _loading  = true;
  String?        _activating;      // id du thème gratuit en cours d'activation
  String?        _redeemingPoints; // id du thème en cours de déblocage par points

  UserPoints _points = UserPoints.zero; // ← NOUVEAU

  String _filter = 'all';
  late final TabController _tabCtrl;
  final _cart = CartManager();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _filter = ['all', 'free', 'paid'][_tabCtrl.index]);
      }
    });
    _cart.addListener(_onCartChange);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _cart.removeListener(_onCartChange);
    super.dispose();
  }

  void _onCartChange() => setState(() {});

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final results = await Future.wait([
        Supabase.instance.client
            .from('themes')
            .select('*')
            .eq('is_active', true)
            .order('is_free', ascending: false)
            .order('price'),
        if (user != null)
          Supabase.instance.client
              .from('user_themes')
              .select('theme_id')
              .eq('user_id', user.id)
        else
          Future.value(<dynamic>[]),
      ]);

      // Chargé séparément : ne doit jamais bloquer l'affichage des
      // thèmes si la lecture du solde échoue.
      final points = await PointsService.fetchCurrentUserPoints();

      if (mounted) {
        setState(() {
          _themes   = (results[0] as List)
              .map((e) => AppTheme.fromMap(e as Map<String, dynamic>))
              .toList();
          _ownedIds = (results[1] as List)
              .map((e) => e['theme_id'] as String)
              .toList();
          _points = points; // ← NOUVEAU
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) _showSnack('Erreur lors du chargement.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Activation directe pour les thèmes gratuits
  Future<void> _activateFree(AppTheme theme) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _activating = theme.id);
    try {
      await Supabase.instance.client.from('user_themes').insert({
        'user_id':  user.id,
        'theme_id': theme.id,
      });
      setState(() => _ownedIds = [..._ownedIds, theme.id]);
      widget.onPurchase?.call();
      if (mounted) _showSnack('${theme.emoji}  "${theme.name}" activé !');
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        setState(() => _ownedIds = [..._ownedIds, theme.id]);
      } else {
        if (mounted) _showSnack('Erreur : ${e.message}', error: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Une erreur est survenue.', error: true);
    } finally {
      if (mounted) setState(() => _activating = null);
    }
  }

  // ── Déblocage par points ─────────────────────  ← NOUVEAU
  Future<void> _redeemWithPoints(AppTheme theme) async {
    if (theme.pointPrice == null) return;
    setState(() => _redeemingPoints = theme.id);
    HapticFeedback.mediumImpact();
    try {
      final success = await PointsService.redeemThemeWithPoints(theme.id);
      if (!mounted) return;

      if (success) {
        setState(() {
          _ownedIds = [..._ownedIds, theme.id];
          _points = UserPoints(
            balance: _points.balance - theme.pointPrice!,
            lifetime: _points.lifetime, // le lifetime ne bouge jamais à la dépense
          );
        });
        widget.onPurchase?.call();
        _showSnack('${theme.emoji}  "${theme.name}" débloqué avec tes points !');
      } else {
        _showSnack('Solde de points insuffisant.', error: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Une erreur est survenue.', error: true);
    } finally {
      if (mounted) setState(() => _redeemingPoints = null);
    }
  }

  // Ajout au panier pour les thèmes payants
  void _addToCart(AppTheme theme) {
    if (_cart.contains(theme.id)) return;
    _cart.add(theme);
    HapticFeedback.lightImpact();
    _showSnack('${theme.emoji}  "${theme.name}" ajouté au panier');
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(
              color: error ? _errorColor : _textPrimary,
              fontWeight: FontWeight.w600)),
      backgroundColor: error ? _errorColor.withOpacity(0.15) : _surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  List<AppTheme> get _filtered {
    switch (_filter) {
      case 'free':  return _themes.where((t) => t.isFree).toList();
      case 'paid':  return _themes.where((t) => !t.isFree).toList();
      default:      return _themes;
    }
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartPage(
          onPurchaseComplete: () {
            _loadData();
            widget.onPurchase?.call();
          },
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1A5AE8), Color(0xFF0A2A6E), Color(0xFF060E30)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60, right: -40,
              child: Container(width: 220, height: 220,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _yellow.withOpacity(0.07))),
            ),
            Positioned(
              bottom: 100, left: -50,
              child: Container(width: 180, height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _bgLight.withOpacity(0.1))),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── Header ───────────────────────────
                  _StoreHeader(
                    cartCount: _cart.count,
                    pointsBalance: _points.balance, // ← NOUVEAU
                    onBack: () => Navigator.pop(context),
                    onCartTap: _openCart,
                  ),
                  const SizedBox(height: 16),

                  // ── Stats ────────────────────────────
                  if (!_loading) ...[
                    _StatsRow(
                      total: _themes.length,
                      free:  _themes.where((t) => t.isFree).length,
                      owned: _ownedIds.length,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Tabs ─────────────────────────────
                  _FilterTabs(controller: _tabCtrl),
                  const SizedBox(height: 16),

                  // ── Liste ────────────────────────────
                  Expanded(
                    child: _loading
                        ? const _LoadingView()
                        : _filtered.isEmpty
                        ? const _EmptyView()
                        : RefreshIndicator(
                      color: _yellow,
                      backgroundColor: _surface,
                      onRefresh: _loadData,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final theme = _filtered[i];
                          final owned = _ownedIds.contains(theme.id);
                          final inCart = _cart.contains(theme.id);
                          return _ThemeCard(
                            theme: theme,
                            isOwned: owned,
                            inCart: inCart,
                            isActivating: _activating == theme.id,
                            isRedeemingPoints: _redeemingPoints == theme.id, // ← NOUVEAU
                            pointsBalance: _points.balance,                  // ← NOUVEAU
                            onAction: owned
                                ? null
                                : theme.isFree
                                ? () => _activateFree(theme)
                                : () => _addToCart(theme),
                            onRedeemWithPoints: (owned || theme.pointPrice == null) // ← NOUVEAU
                                ? null
                                : () => _redeemWithPoints(theme),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bouton panier flottant (si items) ────
            if (_cart.count > 0)
              Positioned(
                bottom: 24, left: 20, right: 20,
                child: _FloatingCartBar(
                  count: _cart.count,
                  total: _cart.total,
                  onTap: _openCart,
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
class _StoreHeader extends StatelessWidget {
  final int cartCount;
  final int pointsBalance; // ← NOUVEAU
  final VoidCallback onBack;
  final VoidCallback onCartTap;

  const _StoreHeader({
    required this.cartCount,
    required this.pointsBalance,
    required this.onBack,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Boutique de Thèmes',
                    style: TextStyle(color: _textPrimary, fontSize: 20,
                        fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                SizedBox(height: 2),
                Text('Débloque de nouveaux packs de questions',
                    style: TextStyle(color: _textSub, fontSize: 12)),
              ],
            ),
          ),

          // ── Solde de points — NOUVEAU ──
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _yellow.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: _yellow, size: 14),
                const SizedBox(width: 4),
                Text('$pointsBalance',
                    style: const TextStyle(color: _yellow, fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),

          // Bouton panier avec badge
          GestureDetector(
            onTap: onCartTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded,
                      color: _textPrimary, size: 20),
                ),
                if (cartCount > 0)
                  Positioned(
                    top: -6, right: -6,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_yellow, Color(0xFFFFB300)]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _yellow.withOpacity(0.5),
                              blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Center(
                        child: Text('$cartCount',
                            style: const TextStyle(color: _navy,
                                fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stats rapides
// ─────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, free, owned;
  const _StatsRow({required this.total, required this.free, required this.owned});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatPill(label: '$total thèmes', icon: Icons.grid_view_rounded),
          const SizedBox(width: 8),
          _StatPill(label: '$free gratuits',
              icon: Icons.card_giftcard_rounded, color: _successColor),
          const SizedBox(width: 8),
          _StatPill(label: '$owned débloqués',
              icon: Icons.lock_open_rounded, color: _yellow),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.icon, this.color = _textSub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tabs filtre
// ─────────────────────────────────────────────
class _FilterTabs extends StatelessWidget {
  final TabController controller;
  const _FilterTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
              color: _yellow, borderRadius: BorderRadius.circular(10)),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _navy,
          unselectedLabelColor: _textSub,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [Tab(text: 'Tous'), Tab(text: 'Gratuits'), Tab(text: 'Premium')],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Carte thème
// ─────────────────────────────────────────────
class _ThemeCard extends StatelessWidget {
  final AppTheme theme;
  final bool isOwned;
  final bool inCart;
  final bool isActivating;
  final bool isRedeemingPoints;   // ← NOUVEAU
  final int pointsBalance;        // ← NOUVEAU
  final VoidCallback? onAction;
  final VoidCallback? onRedeemWithPoints; // ← NOUVEAU

  const _ThemeCard({
    required this.theme,
    required this.isOwned,
    required this.inCart,
    required this.isActivating,
    required this.isRedeemingPoints,
    required this.pointsBalance,
    required this.onAction,
    required this.onRedeemWithPoints,
  });

  @override
  Widget build(BuildContext context) {
    final canRedeemWithPoints = onRedeemWithPoints != null;
    final hasEnoughPoints =
        theme.pointPrice != null && pointsBalance >= theme.pointPrice!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOwned
              ? _successColor.withOpacity(0.35)
              : inCart
              ? _yellow.withOpacity(0.35)
              : Colors.white.withOpacity(0.1),
          width: (isOwned || inCart) ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visuel gauche
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: theme.imageUrl != null
                ? Image.network(theme.imageUrl!, width: 100, height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _EmojiThumb(emoji: theme.emoji))
                : _EmojiThumb(emoji: theme.emoji),
          ),

          // Contenu droite
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + badge prix
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(theme.name,
                            style: const TextStyle(color: _textPrimary,
                                fontSize: 15, fontWeight: FontWeight.w800,
                                letterSpacing: -0.2)),
                      ),
                      const SizedBox(width: 8),
                      if (theme.isFree)
                        _Badge(label: 'GRATUIT', color: _successColor)
                      else
                        _Badge(
                          label: '${theme.price?.toStringAsFixed(2)}€',
                          color: _yellow,
                        ),
                    ],
                  ),

                  if (theme.description != null) ...[
                    const SizedBox(height: 5),
                    Text(theme.description!,
                        style: const TextStyle(color: _textSub,
                            fontSize: 12, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],

                  const SizedBox(height: 12),

                  // Bouton(s) action
                  if (isOwned)
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: _successColor, size: 15),
                        SizedBox(width: 6),
                        Text('Dans ta bibliothèque',
                            style: TextStyle(color: _successColor,
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    )
                  else if (theme.isFree)
                    _ActionButton(
                      label: isActivating ? null : '🚀  Activer',
                      isLoading: isActivating,
                      color: _successColor,
                      onTap: onAction,
                    )
                  else ...[
                      if (inCart)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.shopping_cart_rounded,
                                  color: _yellow, size: 15),
                              SizedBox(width: 6),
                              Text('Dans le panier',
                                  style: TextStyle(color: _yellow,
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ActionButton(
                            label: '🛒  Ajouter au panier',
                            isLoading: false,
                            color: _yellow,
                            textColor: _navy,
                            onTap: onAction,
                          ),
                        ),

                      // ── Option de déblocage par points — NOUVEAU ──
                      if (canRedeemWithPoints)
                        _PointsRedeemButton(
                          pointPrice: theme.pointPrice!,
                          enabled: hasEnoughPoints,
                          isLoading: isRedeemingPoints,
                          onTap: hasEnoughPoints ? onRedeemWithPoints : null,
                        ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton "Débloquer avec X points" — NOUVEAU ──
class _PointsRedeemButton extends StatelessWidget {
  final int pointPrice;
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PointsRedeemButton({
    required this.pointPrice,
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? _purple.withOpacity(0.14) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? _purple.withOpacity(0.4) : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded,
                  color: enabled ? _purple : _textSub.withOpacity(0.4), size: 14),
              const SizedBox(width: 5),
              Text(
                enabled
                    ? 'Débloquer avec $pointPrice pts'
                    : 'Il manque des points ($pointPrice pts)',
                style: TextStyle(
                  color: enabled ? _purple : _textSub.withOpacity(0.4),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiThumb extends StatelessWidget {
  final String emoji;
  const _EmojiThumb({required this.emoji});

  @override
  Widget build(BuildContext context) => Container(
    width: 100, height: 110,
    color: Colors.white.withOpacity(0.05),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40))),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3), width: 1),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w900, letterSpacing: 0.3)),
  );
}

class _ActionButton extends StatelessWidget {
  final String? label;
  final bool isLoading;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.isLoading,
    required this.color,
    this.textColor = _textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, height: 38,
        decoration: BoxDecoration(
          gradient: isLoading ? null
              : LinearGradient(colors: [color, color.withOpacity(0.8)]),
          color: isLoading ? Colors.white.withOpacity(0.08) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isLoading ? null : [
            BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _textPrimary))
              : Text(label ?? '',
              style: TextStyle(color: textColor, fontSize: 13,
                  fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Barre panier flottante
// ─────────────────────────────────────────────
class _FloatingCartBar extends StatelessWidget {
  final int count;
  final double total;
  final VoidCallback onTap;

  const _FloatingCartBar({
    required this.count,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_yellow, Color(0xFFFFB300)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: _yellow.withOpacity(0.45),
                blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: _navy.withOpacity(0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.shopping_cart_rounded,
                  color: _navy, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count thème${count > 1 ? 's' : ''} dans le panier',
                    style: const TextStyle(color: _navy,
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Voir le panier et payer',
                    style: TextStyle(color: _navy.withOpacity(0.6),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${total.toStringAsFixed(2)}€',
                style: const TextStyle(color: _navy,
                    fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CartPage
// ─────────────────────────────────────────────
class CartPage extends StatefulWidget {
  final VoidCallback? onPurchaseComplete;
  const CartPage({super.key, this.onPurchaseComplete});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _cart = CartManager();
  bool _purchasing = false;
  bool _success    = false;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_rebuild);
  }

  @override
  void dispose() {
    _cart.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _checkout() async {
    if (_cart.items.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _purchasing = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Non connecté');

      for (final theme in _cart.items) {
        await Supabase.instance.client.from('user_themes').insert({
          'user_id':  user.id,
          'theme_id': theme.id,
        });
      }

      _cart.clear();
      widget.onPurchaseComplete?.call();

      if (mounted) {
        setState(() { _purchasing = false; _success = true; });
        HapticFeedback.heavyImpact();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _purchasing = false);
        _showSnack('Erreur : ${e.message}', error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _purchasing = false);
        _showSnack('Une erreur est survenue.', error: true);
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(
              color: error ? _errorColor : _textPrimary,
              fontWeight: FontWeight.w600)),
      backgroundColor: error ? _errorColor.withOpacity(0.15) : _surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFF1A5AE8), Color(0xFF0A2A6E), Color(0xFF060E30)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -60, right: -40,
                child: Container(width: 200, height: 200,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _yellow.withOpacity(0.07)))),
            SafeArea(
              child: _success
                  ? _SuccessView(onClose: () => Navigator.pop(context))
                  : Column(
                children: [
                  _CartHeader(
                    count: _cart.count,
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _cart.items.isEmpty
                        ? const _EmptyCartView()
                        : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _cart.items.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (_, i) => _CartItem(
                        theme: _cart.items[i],
                        onRemove: () =>
                            _cart.remove(_cart.items[i].id),
                      ),
                    ),
                  ),
                  if (_cart.items.isNotEmpty)
                    _CartFooter(
                      total: _cart.total,
                      itemCount: _cart.count,
                      isPurchasing: _purchasing,
                      onCheckout: _checkout,
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
//  Header CartPage
// ─────────────────────────────────────────────
class _CartHeader extends StatelessWidget {
  final int count;
  final VoidCallback onBack;
  const _CartHeader({required this.count, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mon panier',
                    style: TextStyle(color: _textPrimary, fontSize: 20,
                        fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                Text(
                  count == 0
                      ? 'Panier vide'
                      : '$count thème${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
                  style: const TextStyle(color: _textSub, fontSize: 12),
                ),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _yellow.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _yellow.withOpacity(0.3), width: 1),
              ),
              child: Text('$count',
                  style: const TextStyle(color: _yellow, fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Item du panier
// ─────────────────────────────────────────────
class _CartItem extends StatelessWidget {
  final AppTheme theme;
  final VoidCallback onRemove;
  const _CartItem({required this.theme, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: theme.imageUrl != null
                ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.network(theme.imageUrl!, width: 52,
                    height: 52, fit: BoxFit.cover))
                : Center(child: Text(theme.emoji,
                style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(theme.name,
                    style: const TextStyle(color: _textPrimary,
                        fontSize: 15, fontWeight: FontWeight.w800)),
                if (theme.description != null) ...[
                  const SizedBox(height: 2),
                  Text(theme.description!,
                      style: const TextStyle(color: _textSub, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                theme.price != null
                    ? '${theme.price!.toStringAsFixed(2)}€'
                    : 'Gratuit',
                style: const TextStyle(color: _yellow,
                    fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _errorColor.withOpacity(0.25), width: 1),
                  ),
                  child: const Text('Retirer',
                      style: TextStyle(color: _errorColor,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Footer CartPage
// ─────────────────────────────────────────────
class _CartFooter extends StatelessWidget {
  final double total;
  final int itemCount;
  final bool isPurchasing;
  final VoidCallback onCheckout;

  const _CartFooter({
    required this.total,
    required this.itemCount,
    required this.isPurchasing,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$itemCount thème${itemCount > 1 ? 's' : ''}',
                  style: const TextStyle(color: _textSub, fontSize: 14)),
              Text('${total.toStringAsFixed(2)}€',
                  style: const TextStyle(color: _textSub, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(color: _textPrimary, fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text('${total.toStringAsFixed(2)}€',
                  style: const TextStyle(color: _yellow, fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _successColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _successColor.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded,
                    color: _successColor.withOpacity(0.8), size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Paiement sécurisé — thèmes débloqués instantanément',
                    style: TextStyle(color: _successColor, fontSize: 11,
                        fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: isPurchasing ? null : onCheckout,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                gradient: isPurchasing ? null
                    : const LinearGradient(colors: [_yellow, Color(0xFFFFB300)]),
                color: isPurchasing ? Colors.white.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isPurchasing ? null : [
                  BoxShadow(color: _yellow.withOpacity(0.4),
                      blurRadius: 24, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(
                child: isPurchasing
                    ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: _textPrimary))
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payment_rounded, color: _navy, size: 20),
                    const SizedBox(width: 10),
                    Text('Payer ${total.toStringAsFixed(2)}€',
                        style: const TextStyle(color: _navy, fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  États panier vide / succès
// ─────────────────────────────────────────────
class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: _textSub, size: 36),
          ),
          const SizedBox(height: 18),
          const Text('Panier vide',
              style: TextStyle(color: _textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Ajoute des thèmes depuis la boutique',
              style: TextStyle(color: _textSub, fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: _yellow.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _yellow.withOpacity(0.3)),
              ),
              child: const Text('← Retour à la boutique',
                  style: TextStyle(color: _yellow, fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onClose;
  const _SuccessView({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 110, height: 110,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _successColor.withOpacity(0.06))),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _successColor.withOpacity(0.15),
                  border: Border.all(
                      color: _successColor.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.check_rounded,
                    color: _successColor, size: 40),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text('Thèmes débloqués !',
              style: TextStyle(color: _successColor, fontSize: 26,
                  fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 10),
          const Text(
            'Tes thèmes sont maintenant disponibles\nsur la page d\'accueil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_yellow, Color(0xFFFFB300)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _yellow.withOpacity(0.4),
                    blurRadius: 24, offset: const Offset(0, 6))],
              ),
              child: const Center(
                child: Text('🏠  Retour à la boutique',
                    style: TextStyle(color: _navy, fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  États liste vide / chargement
// ─────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 36, height: 36,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _yellow)),
      SizedBox(height: 16),
      Text('Chargement du store...',
          style: TextStyle(color: _textSub, fontSize: 14)),
    ]),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('😢', style: TextStyle(fontSize: 56)),
      SizedBox(height: 14),
      Text('Aucun thème disponible',
          style: TextStyle(color: _textPrimary, fontSize: 18,
              fontWeight: FontWeight.w800)),
      SizedBox(height: 6),
      Text('Revenez bientôt pour de nouveaux packs !',
          style: TextStyle(color: _textSub, fontSize: 13)),
    ]),
  );
}