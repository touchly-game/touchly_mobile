import 'dart:ui';

class AppTheme {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double? price;
  final bool isFree;
  final String emoji;
  final Color? accentColor;

  AppTheme({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.price,
    this.isFree = false,
    this.emoji = '🎮',
    this.accentColor
  });

  factory AppTheme.fromMap(Map<String, dynamic> m) => AppTheme(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String?,
    imageUrl: m['image_url'] as String?,
    price: (m['price'] as num?)?.toDouble(),
    isFree: m['is_free'] as bool? ?? false,
    emoji: m['emoji'] as String? ?? '🎮',
    accentColor: m['accent_color'] != null
        ? Color(int.parse((m['accent_color'] as String).replaceFirst('#', '0xFF')))
        : null,
  );

}