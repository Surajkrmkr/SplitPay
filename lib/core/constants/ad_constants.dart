import 'dart:io';
import 'package:flutter/foundation.dart';

/// Enum representing each unique ad placement location in the app.
/// Every screen placement has its own Ad Unit ID to enable analytics
/// on user time and engagement per screen.
enum AdPlacement {
  /// Homescreen: Below "Split with friends" banner
  homeSplitBanner,

  /// Homescreen: Below "Quick Insights" section
  homeQuickInsightsBanner,

  /// Add Expense Sheet: Below "Suggested apps"
  addExpenseBanner,

  /// Recent Transactions Page: Large banner displayed every 4 transactions
  transactionsListBanner,

  /// Analytics Screen: Below "By Category" spending pie chart
  analyticsCategoryBanner,

  /// Groups Screen: End of groups list
  groupsListBanner,

  /// Group Details Screen: Total Tab, bottom of monthly spend graph
  groupDetailsTotalBanner,

  /// Budget Screen: Below "Total Budget" summary card
  budgetSummaryBanner,
}

/// Centralized ad configuration and Ad Unit ID constants.
/// Replace test IDs with production Google AdMob unit IDs before releasing.
abstract class AdConstants {
  // ── Sample Test Ad Unit IDs (Google AdMob Defaults) ──────────────────────
  static const String _testAndroidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';

  static const String _testAndroidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  static const String _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  // ── 1. Banner: Homescreen - Below Split with friends ────────────────────────
  static const String homeSplitAndroidUnitId = _testAndroidBanner;
  static const String homeSplitIosUnitId = _testIosBanner;

  // ── 2. Banner: Homescreen - Below Quick Insights ────────────────────────────
  static const String homeQuickInsightsAndroidUnitId = _testAndroidBanner;
  static const String homeQuickInsightsIosUnitId = _testIosBanner;

  // ── 3. Banner: Add Expense Sheet - Below Suggested Apps ─────────────────────
  static const String addExpenseAndroidUnitId = _testAndroidBanner;
  static const String addExpenseIosUnitId = _testIosBanner;

  // ── 4. Banner: Recent Transactions - Every 4 Transactions ──────────────────
  static const String transactionsListAndroidUnitId = _testAndroidBanner;
  static const String transactionsListIosUnitId = _testIosBanner;

  // ── 5. Banner: Analytics - Below By Category ────────────────────────────────
  static const String analyticsCategoryAndroidUnitId = _testAndroidBanner;
  static const String analyticsCategoryIosUnitId = _testIosBanner;

  // ── 6. Banner: Groups Screen - End of Groups List ───────────────────────────
  static const String groupsListAndroidUnitId = _testAndroidBanner;
  static const String groupsListIosUnitId = _testIosBanner;

  // ── 7. Banner: Group Details - Total Tab Bottom of Graph ────────────────────
  static const String groupDetailsTotalAndroidUnitId = _testAndroidBanner;
  static const String groupDetailsTotalIosUnitId = _testIosBanner;

  // ── 8. Banner: Budget Screen - Below Total Budget Card ──────────────────────
  static const String budgetSummaryAndroidUnitId = _testAndroidBanner;
  static const String budgetSummaryIosUnitId = _testIosBanner;

  // ── Future Scope: Interstitial & Rewarded Ad Unit IDs ───────────────────────
  static const String interstitialAndroidUnitId = _testAndroidInterstitial;
  static const String interstitialIosUnitId = _testIosInterstitial;

  static const String rewardedAndroidUnitId = _testAndroidRewarded;
  static const String rewardedIosUnitId = _testIosRewarded;

  /// Returns the platform-specific Ad Unit ID for the given [placement].
  static String getAdUnitId(AdPlacement placement) {
    if (kIsWeb) return '';

    final isAndroid = Platform.isAndroid;

    switch (placement) {
      case AdPlacement.homeSplitBanner:
        return isAndroid ? homeSplitAndroidUnitId : homeSplitIosUnitId;
      case AdPlacement.homeQuickInsightsBanner:
        return isAndroid
            ? homeQuickInsightsAndroidUnitId
            : homeQuickInsightsIosUnitId;
      case AdPlacement.addExpenseBanner:
        return isAndroid ? addExpenseAndroidUnitId : addExpenseIosUnitId;
      case AdPlacement.transactionsListBanner:
        return isAndroid
            ? transactionsListAndroidUnitId
            : transactionsListIosUnitId;
      case AdPlacement.analyticsCategoryBanner:
        return isAndroid
            ? analyticsCategoryAndroidUnitId
            : analyticsCategoryIosUnitId;
      case AdPlacement.groupsListBanner:
        return isAndroid ? groupsListAndroidUnitId : groupsListIosUnitId;
      case AdPlacement.groupDetailsTotalBanner:
        return isAndroid
            ? groupDetailsTotalAndroidUnitId
            : groupDetailsTotalIosUnitId;
      case AdPlacement.budgetSummaryBanner:
        return isAndroid
            ? budgetSummaryAndroidUnitId
            : budgetSummaryIosUnitId;
    }
  }

  /// Returns the platform-specific Interstitial Ad Unit ID for future integration.
  static String get interstitialAdUnitId =>
      kIsWeb ? '' : (Platform.isAndroid ? interstitialAndroidUnitId : interstitialIosUnitId);

  /// Returns the platform-specific Rewarded Ad Unit ID for future integration.
  static String get rewardedAdUnitId =>
      kIsWeb ? '' : (Platform.isAndroid ? rewardedAndroidUnitId : rewardedIosUnitId);
}
