import '../../data/models/transaction_model.dart';
import '../../data/models/custom_category.dart';

/// Maps each [Category] to the asset filenames inside `assets/app_icons/`
/// that are suggested when the user picks that category.
///
/// Filenames match the source files (spaces preserved, .png extension).
/// Refine the lists below to taste — the picker just iterates the list.
class CategoryAppIcons {
  static const String assetDir = 'assets/app_icons/';

  /// Returns the full asset path Flutter expects for a filename.
  static String pathFor(String fileName) => '$assetDir$fileName';

  static const List<String> allAvailableAppIcons = [
    'Amazon.png',
    'Amazon fresh.png',
    'Amazon now.png',
    'Apple music.png',
    'Apple tv.png',
    'Bigbasket.png',
    'Bistro.png',
    'Blinkit.png',
    'Bonkers corner.png',
    'BookMyShow.png',
    'Crunchy roll.png',
    'Cult.png',
    'Dazzl.png',
    'District.png',
    'Dmart ready.png',
    'First club.png',
    'Flipkart.png',
    'Flipkart minutes.png',
    'Goibibo.png',
    'IRCTC.png',
    'Instamart.png',
    'Jio hotstar.png',
    'Jio mart.png',
    'Licious.png',
    'MX player.png',
    'Magicpin.png',
    'MakeMyTrip.png',
    'Meesho.png',
    'Myntra.png',
    'Namma yatri.png',
    'Netflix.png',
    'Nykaa.png',
    'Ola.png',
    'Prime video.png',
    'Pronto.png',
    'Rapido.png',
    'Savana.png',
    'Snabbit.png',
    'Sony liv.png',
    'Soul store.png',
    'Spotify.png',
    'Star.png',
    'Swiggy.png',
    'Swish.png',
    'Toing.png',
    'Uber.png',
    'Urban company.png',
    'Vishal mart.png',
    'Yes madam.png',
    'Youtube.png',
    'Zee5.png',
    'Zepto.png',
    'Zepto cafe.png',
    'Zomato.png',
  ];

  static const Map<Category, List<String>> _byCategory = {
    Category.food: [
      'Zomato.png',
      'Swiggy.png',
      'Swish.png',
      'Bistro.png',
      'Zepto cafe.png',
      'Pronto.png',
      'Toing.png',
      'Magicpin.png',
    ],
    Category.shopping: [
      'Amazon.png',
      'Flipkart.png',
      'Myntra.png',
      'Meesho.png',
      'Nykaa.png',
      'Bonkers corner.png',
      'Soul store.png',
      'First club.png',
      'Dazzl.png',
      // Quick-commerce / grocery — often used for "shopping" too
      'Zepto.png',
      'Amazon fresh.png',
      'Amazon now.png',
      'Bigbasket.png',
      'Blinkit.png',
      'Dmart ready.png',
      'Flipkart minutes.png',
      'Instamart.png',
      'Jio mart.png',
      'Licious.png',
      'Vishal mart.png',
    ],
    Category.travel: [
      'Uber.png',
      'Ola.png',
      'Rapido.png',
      'Namma yatri.png',
      'MakeMyTrip.png',
      'Goibibo.png',
      'IRCTC.png',
    ],
    Category.entertainment: [
      'Netflix.png',
      'Prime video.png',
      'Jio hotstar.png',
      'Sony liv.png',
      'BookMyShow.png',
      'District.png',
      'Spotify.png',
      'Apple music.png',
      'Apple tv.png',
      'Youtube.png',
      'MX player.png',
      'Crunchy roll.png',
      'Savana.png',
      'Star.png',
    ],
    Category.subscription: [
      'Netflix.png',
      'Prime video.png',
      'Jio hotstar.png',
      'Sony liv.png',
      'Spotify.png',
      'Apple music.png',
      'Apple tv.png',
      'Youtube.png',
      'Crunchy roll.png',
    ],
    Category.health: [
      'Cult.png',
      'Urban company.png',
      'Yes madam.png',
      'Snabbit.png',
    ],
    // Bills, Salary, Other — no obvious app icons yet. Picker hides itself
    // when this list is empty so the UI stays clean.
    Category.bills: [],
    Category.salary: [],
    Category.other: [],
  };

  static List<String> iconsFor(Category? category) =>
      category == null ? const [] : (_byCategory[category] ?? const []);

  static List<String> iconsForCustom(CustomCategory? customCategory) =>
      customCategory?.suggestedApps ?? const [];

  /// Tries to guess a category from an app-icon filename. Used as a fallback
  /// when an old expense/transaction has an appIcon set but no category yet.
  static Category? categoryFor(String fileName) {
    for (final entry in _byCategory.entries) {
      if (entry.value.contains(fileName)) return entry.key;
    }
    return null;
  }
}
