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
  /// Global master toggle to turn ads on or off across the entire app.
  /// Set to `false` to turn off all ads, ad fetching, and ad initialization.
  static const bool enableAds = true;

  // ── Sample Test Ad Unit IDs (Google AdMob Defaults) ──────────────────────
  static const String testAndroidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String testIosBanner = 'ca-app-pub-3940256099942544/2934735716';

  static const String _testAndroidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  static const String _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  // ── 1. Banner: Homescreen - Below Split with friends ────────────────────────
  static const String homeSplitAndroidUnitId =
      'ca-app-pub-4861691653340010/6399521843';
  static const String homeSplitIosUnitId = testIosBanner;

  // ── 2. Banner: Homescreen - Below Quick Insights ────────────────────────────
  static const String homeQuickInsightsAndroidUnitId =
      'ca-app-pub-4861691653340010/2973176488';
  static const String homeQuickInsightsIosUnitId = testIosBanner;

  // ── 3. Banner: Add Expense Sheet - Below Suggested Apps ─────────────────────
  static const String addExpenseAndroidUnitId =
      'ca-app-pub-4861691653340010/3188944692';
  static const String addExpenseIosUnitId = testIosBanner;

  // ── 4. Banner: Recent Transactions - Every 4 Transactions ──────────────────
  static const String transactionsListAndroidUnitId =
      'ca-app-pub-4861691653340010/8337329599';
  static const String transactionsListIosUnitId = testIosBanner;

  // ── 5. Banner: Analytics - Below By Category ────────────────────────────────
  static const String analyticsCategoryAndroidUnitId =
      'ca-app-pub-4861691653340010/8385431059';
  static const String analyticsCategoryIosUnitId = testIosBanner;

  // ── 6. Banner: Groups Screen - End of Groups List ───────────────────────────
  static const String groupsListAndroidUnitId =
      'ca-app-pub-4861691653340010/6720849805';
  static const String groupsListIosUnitId = testIosBanner;

  // ── 7. Banner: Group Details - Total Tab Bottom of Graph ────────────────────
  static const String groupDetailsTotalAndroidUnitId =
      'ca-app-pub-4861691653340010/6720849805';
  static const String groupDetailsTotalIosUnitId = testIosBanner;

  // ── 8. Banner: Budget Screen - Below Total Budget Card ──────────────────────
  static const String budgetSummaryAndroidUnitId = "ca-app-pub-4861691653340010/8169808638";
  static const String budgetSummaryIosUnitId = testIosBanner;

  // ── Future Scope: Interstitial & Rewarded Ad Unit IDs ───────────────────────
  static const String interstitialAndroidUnitId = _testAndroidInterstitial;
  static const String interstitialIosUnitId = _testIosInterstitial;

  static const String rewardedAndroidUnitId = _testAndroidRewarded;
  static const String rewardedIosUnitId = _testIosRewarded;

  /// Returns the platform-specific Ad Unit ID for the given [placement].
  static String getAdUnitId(AdPlacement placement) {
    if (!enableAds || kIsWeb) return '';

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
      (!enableAds || kIsWeb)
          ? ''
          : (Platform.isAndroid ? interstitialAndroidUnitId : interstitialIosUnitId);

  /// Returns the platform-specific Rewarded Ad Unit ID for future integration.
  static String get rewardedAdUnitId =>
      (!enableAds || kIsWeb)
          ? ''
          : (Platform.isAndroid ? rewardedAndroidUnitId : rewardedIosUnitId);
}
