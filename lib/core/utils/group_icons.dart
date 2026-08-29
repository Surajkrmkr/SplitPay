import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Predefined icons users can pick for a group at creation time.
/// Stored in the group's `avatar` field as `app-icon:<key>` so we don't need
/// to change the schema. [AvatarWidget] detects the prefix and renders an icon.
class GroupIcons {
  static const String _prefix = 'app-icon:';

  static const Map<String, IconData> all = {
    'group': Icons.group_rounded,
    'travel': Icons.flight_takeoff_rounded,
    'home': Icons.home_rounded,
    'food': Icons.restaurant_rounded,
    'party': Icons.celebration_rounded,
    'sports': Icons.sports_basketball_rounded,
    'beach': Icons.beach_access_rounded,
    'office': Icons.work_rounded,
    'school': Icons.school_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'gift': Icons.card_giftcard_rounded,
    'movie': Icons.movie_rounded,
  };

  static const Map<String, Color> colors = {
    'group': AppColors.secondary,
    'travel': AppColors.catTravel,
    'home': AppColors.catBills,
    'food': AppColors.catFood,
    'party': AppColors.catEntertainment,
    'sports': Color(0xFF00D09C),
    'beach': AppColors.catTravel,
    'office': AppColors.textSecondary,
    'school': AppColors.catSubscription,
    'shopping': AppColors.catShopping,
    'gift': AppColors.expense,
    'movie': AppColors.catEntertainment,
  };

  static IconData? iconFor(String? avatar) {
    if (avatar == null || !avatar.startsWith(_prefix)) return null;
    return all[avatar.substring(_prefix.length)];
  }

  static Color? colorFor(String? avatar) {
    if (avatar == null || !avatar.startsWith(_prefix)) return null;
    return colors[avatar.substring(_prefix.length)];
  }

  static String encode(String key) => '$_prefix$key';

  static const String defaultKey = 'group';
}
