import 'package:flutter/material.dart';

/// Affiche un texte en interprétant `**gras**` comme un span en gras
/// coloré avec [accentColor]. Évite de dupliquer du texte riche codé
/// en dur dans chaque widget de règles.
class BoldAccentText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Color accentColor;
  final TextAlign? textAlign;

  const BoldAccentText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.accentColor,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: accentColor, fontWeight: FontWeight.w900),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}