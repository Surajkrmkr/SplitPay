import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  // 80 icons organised by spend category.
  // Uses IconData so the picker can render them with Icon() or FaIcon().
  static const List<_CategoryIcon> _iconEntries = [
    // ── Food & Dining ──────────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.utensils, 'Restaurant'),
    _CategoryIcon(FontAwesomeIcons.pizzaSlice, 'Pizza'),
    _CategoryIcon(FontAwesomeIcons.burger, 'Burger'),
    _CategoryIcon(FontAwesomeIcons.mugHot, 'Coffee'),
    _CategoryIcon(FontAwesomeIcons.iceCream, 'Ice Cream'),
    _CategoryIcon(FontAwesomeIcons.martiniGlass, 'Bar'),
    _CategoryIcon(FontAwesomeIcons.wineGlass, 'Wine'),
    _CategoryIcon(FontAwesomeIcons.fish, 'Seafood'),
    _CategoryIcon(FontAwesomeIcons.cookieBite, 'Bakery'),
    _CategoryIcon(FontAwesomeIcons.bowlFood, 'Meal Kit'),

    // ── Grocery & Daily Shopping ───────────────────────────────
    _CategoryIcon(FontAwesomeIcons.cartShopping, 'Grocery'),
    _CategoryIcon(FontAwesomeIcons.bagShopping, 'Shopping'),
    _CategoryIcon(FontAwesomeIcons.store, 'Store'),
    _CategoryIcon(FontAwesomeIcons.bottleWater, 'Drinks'),
    _CategoryIcon(FontAwesomeIcons.seedling, 'Organic'),
    _CategoryIcon(FontAwesomeIcons.appleWhole, 'Fruits'),

    // ── Quick Commerce (Zepto, Blinkit, Swiggy Instamart) ──────
    _CategoryIcon(FontAwesomeIcons.truckFast, 'Quick Delivery'),
    _CategoryIcon(FontAwesomeIcons.bolt, 'Instamart'),
    _CategoryIcon(FontAwesomeIcons.boxOpen, 'Delivery'),
    _CategoryIcon(FontAwesomeIcons.clockRotateLeft, 'Express'),

    // ── Online Shopping (Flipkart, Amazon, Meesho) ─────────────
    _CategoryIcon(FontAwesomeIcons.laptop, 'Electronics'),
    _CategoryIcon(FontAwesomeIcons.shirt, 'Clothing'),
    _CategoryIcon(FontAwesomeIcons.tag, 'Deals'),
    _CategoryIcon(FontAwesomeIcons.gift, 'Gifts'),
    _CategoryIcon(FontAwesomeIcons.boxesStacked, 'Orders'),

    // ── Transport ─────────────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.car, 'Car'),
    _CategoryIcon(FontAwesomeIcons.taxi, 'Cab / Auto'),
    _CategoryIcon(FontAwesomeIcons.bus, 'Bus'),
    _CategoryIcon(FontAwesomeIcons.trainSubway, 'Metro / Train'),
    _CategoryIcon(FontAwesomeIcons.motorcycle, 'Bike Taxi'),
    _CategoryIcon(FontAwesomeIcons.bicycle, 'Bicycle'),
    _CategoryIcon(FontAwesomeIcons.plane, 'Flight'),
    _CategoryIcon(FontAwesomeIcons.gasPump, 'Fuel'),
    _CategoryIcon(FontAwesomeIcons.squareParking, 'Parking'),

    // ── Health & Wellness ─────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.hospitalUser, 'Hospital'),
    _CategoryIcon(FontAwesomeIcons.pills, 'Medicine'),
    _CategoryIcon(FontAwesomeIcons.dumbbell, 'Gym'),
    _CategoryIcon(FontAwesomeIcons.spa, 'Spa / Salon'),
    _CategoryIcon(FontAwesomeIcons.heartPulse, 'Health'),
    _CategoryIcon(FontAwesomeIcons.tooth, 'Dental'),
    _CategoryIcon(FontAwesomeIcons.eye, 'Eye Care'),

    // ── Home & Utilities ──────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.house, 'Rent'),
    _CategoryIcon(FontAwesomeIcons.lightbulb, 'Electricity'),
    _CategoryIcon(FontAwesomeIcons.droplet, 'Water'),
    _CategoryIcon(FontAwesomeIcons.wifi, 'Internet'),
    _CategoryIcon(FontAwesomeIcons.wrench, 'Repair'),
    _CategoryIcon(FontAwesomeIcons.couch, 'Furniture'),
    _CategoryIcon(FontAwesomeIcons.broom, 'Cleaning'),
    _CategoryIcon(FontAwesomeIcons.fire, 'Gas'),

    // ── Entertainment ─────────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.gamepad, 'Gaming'),
    _CategoryIcon(FontAwesomeIcons.film, 'Movies'),
    _CategoryIcon(FontAwesomeIcons.music, 'Music'),
    _CategoryIcon(FontAwesomeIcons.headphones, 'Streaming'),
    _CategoryIcon(FontAwesomeIcons.ticket, 'Events'),
    _CategoryIcon(FontAwesomeIcons.bookOpen, 'Books'),
    _CategoryIcon(FontAwesomeIcons.tv, 'OTT / TV'),

    // ── Travel & Holidays ─────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.hotel, 'Hotel'),
    _CategoryIcon(FontAwesomeIcons.mountain, 'Trek'),
    _CategoryIcon(FontAwesomeIcons.umbrellaBeach, 'Beach'),
    _CategoryIcon(FontAwesomeIcons.passport, 'Travel Docs'),
    _CategoryIcon(FontAwesomeIcons.mapPin, 'Sightseeing'),
    _CategoryIcon(FontAwesomeIcons.suitcaseRolling, 'Luggage'),

    // ── Education ─────────────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.graduationCap, 'Tuition'),
    _CategoryIcon(FontAwesomeIcons.chalkboardUser, 'Coaching'),
    _CategoryIcon(FontAwesomeIcons.penNib, 'Stationery'),
    _CategoryIcon(FontAwesomeIcons.microchip, 'Courses'),

    // ── Finance & Insurance ───────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.moneyBill, 'Cash'),
    _CategoryIcon(FontAwesomeIcons.creditCard, 'Card'),
    _CategoryIcon(FontAwesomeIcons.wallet, 'Wallet'),
    _CategoryIcon(FontAwesomeIcons.piggyBank, 'Savings'),
    _CategoryIcon(FontAwesomeIcons.shield, 'Insurance'),
    _CategoryIcon(FontAwesomeIcons.chartLine, 'Investment'),

    // ── Pets ──────────────────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.dog, 'Dog'),
    _CategoryIcon(FontAwesomeIcons.cat, 'Cat'),
    _CategoryIcon(FontAwesomeIcons.paw, 'Pet Care'),

    // ── Social & Celebrations ─────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.champagneGlasses, 'Party'),
    _CategoryIcon(FontAwesomeIcons.cakeCandles, 'Birthday'),
    _CategoryIcon(FontAwesomeIcons.handHoldingHeart, 'Charity'),
    _CategoryIcon(FontAwesomeIcons.children, 'Kids'),

    // ── Work ──────────────────────────────────────────────────
    _CategoryIcon(FontAwesomeIcons.briefcase, 'Business'),
    _CategoryIcon(FontAwesomeIcons.print, 'Office'),
    _CategoryIcon(FontAwesomeIcons.buildingColumns, 'Tax / Govt'),
  ];

  static const List<Color> colors = [
    Color(0xFF6366F1), // indigo
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // purple
    Color(0xFF10B981), // green
    Color(0xFFEF4444), // red
    Color(0xFF3B82F6), // blue
    Color(0xFFF97316), // orange
    Color(0xFF06B6D4), // cyan
    Color(0xFF84CC16), // lime
    Color(0xFFA855F7), // violet
  ];

  // Public flat list of icon data — used by the category icon picker in Settings.
  static List<IconData> get icons =>
      _iconEntries.map((e) => e.iconData.data).toList();

  // Returns the FA IconData for this category.
  IconData get icon =>
      _iconEntries[iconIndex % _iconEntries.length].iconData.data;

  // Returns the label hint for this icon.
  String get iconLabel => _iconEntries[iconIndex % _iconEntries.length].label;

  Color get color => colors[colorIndex % colors.length];

  Map<String, dynamic> toMap() => {
        'label': label,
        'colorValue': colorIndex,
        'iconCodePoint': iconIndex,
      };

  factory CustomCategory.fromMap(Map map) => CustomCategory(
        id: map['id'] as String,
        label: map['label'] as String,
        colorIndex: map['colorValue'] as int,
        iconIndex: map['iconCodePoint'] as int,
      );
}

class _CategoryIcon {
  final FaIconData iconData;
  final String label;
  const _CategoryIcon(this.iconData, this.label);
}
