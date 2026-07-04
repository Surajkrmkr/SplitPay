import '../../data/models/transaction_model.dart';

/// Maps each [Category] to the asset filenames inside `assets/app_icons/`
/// that are suggested when the user picks that category.
///
/// Filenames match the source files (spaces preserved, .png extension).
/// Refine the lists below to taste — the picker just iterates the list.
class CategoryAppIcons {
  static const String assetDir = 'assets/app_icons/';

  /// Returns the full asset path Flutter expects for a filename.
  static String pathFor(String fileName) => '$assetDir$fileName';

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

  static List<String> iconsFor(Category category) =>
      _byCategory[category] ?? const [];

  /// Tries to guess a category from an app-icon filename. Used as a fallback
  /// when an old expense/transaction has an appIcon set but no category yet.
  static Category? categoryFor(String fileName) {
    for (final entry in _byCategory.entries) {
      if (entry.value.contains(fileName)) return entry.key;
    }
    return null;
  }
}
