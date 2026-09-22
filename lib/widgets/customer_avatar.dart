import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class CustomerAvatar extends StatelessWidget {
  final String name;
  final String? photoPath;
  final double radius;

  const CustomerAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && File(photoPath!).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(photoPath!)),
      );
    }

    // Generate initials + color from name
    final initials = _initials(name);
    final color = _colorFromName(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _colorFromName(String name) {
    final colors = [
      AppTheme.primary,
      AppTheme.accent,
      const Color(0xFF7B1FA2),
      const Color(0xFF00838F),
      const Color(0xFFE65100),
      const Color(0xFF37474F),
      const Color(0xFF558B2F),
      const Color(0xFF6A1B9A),
    ];
    final index = name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }
}
