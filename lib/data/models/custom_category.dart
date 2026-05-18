import 'package:flutter/material.dart';

class CustomCategory {
  final String id;
  final String label;
  final int iconIndex;
  final int colorIndex;

  const CustomCategory({
    required this.id,
    required this.label,
    required this.iconIndex,
    required this.colorIndex,
  });

  static const List<IconData> icons = [
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.celebration_rounded,
    Icons.sports_soccer_rounded,
    Icons.music_note_rounded,
    Icons.school_rounded,
    Icons.work_rounded,
    Icons.pets_rounded,
    Icons.local_florist_rounded,
    Icons.sports_esports_rounded,
    Icons.fitness_center_rounded,
    Icons.beach_access_rounded,
    Icons.spa_rounded,
    Icons.directions_bike_rounded,
    Icons.car_rental_rounded,
    Icons.phone_android_rounded,
    Icons.child_care_rounded,
  ];

  static const List<Color> colors = [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
  ];

  IconData get icon => icons[iconIndex % icons.length];
  Color get color => colors[colorIndex % colors.length];

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'iconIndex': iconIndex,
        'colorIndex': colorIndex,
      };

  factory CustomCategory.fromMap(Map map) => CustomCategory(
        id: map['id'] as String,
        label: map['label'] as String,
        iconIndex: map['iconIndex'] as int,
        colorIndex: map['colorIndex'] as int,
      );
}
