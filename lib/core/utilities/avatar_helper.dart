import 'package:flutter/material.dart';

/// Provides consistent, solid, and elegant avatar colors for tenants.
/// Avatars remain consistent across screens and never turn red or depend on payment status.
class AvatarHelper {
  static const List<Color> _palette = [
    Color(0xFF2563EB), // Deep Royal Blue
    Color(0xFF7C3AED), // Royal Purple
    Color(0xFF0D9488), // Deep Teal
    Color(0xFFD97706), // Rich Amber
    Color(0xFF059669), // Vivid Emerald
    Color(0xFF4F46E5), // Indigo
    Color(0xFFDB2777), // Pink Magenta
    Color(0xFF0284C7), // Sky Cyan
    Color(0xFF9333EA), // Violet
    Color(0xFF0F766E), // Dark Teal
    Color(0xFFEA580C), // Warm Orange
    Color(0xFF4338CA), // Classic Indigo
  ];

  /// Returns a stable solid color based on the tenant's name.
  static Color getSolidColor(String name) {
    if (name.isEmpty) return _palette[0];
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return _palette[hash % _palette.length];
  }

  /// Builds a modern, circular solid avatar widget with the tenant's first letter.
  static Widget buildAvatar({
    required String name,
    double radius = 20,
    double? size,
    double fontSize = 16,
  }) {
    final effectiveRadius = size != null ? size / 2 : radius;
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: effectiveRadius,
      backgroundColor: getSolidColor(name),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
