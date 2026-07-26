import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/ad_constants.dart';
import 'app_logger.dart';

/// Singleton service managing Google Mobile Ads lifecycle, initialization,
/// and future full-screen ads (Interstitial and Rewarded).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  /// Initializes the Google Mobile Ads SDK. Safe for non-supported platforms (Web).
  Future<void> initialize() async {
    if (!AdConstants.enableAds || kIsWeb) return;
    try {
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      AppLogger.instance.i('Google Mobile Ads initialized', tag: 'AdService');
      status.adapterStatuses.forEach((key, value) {
        AppLogger.instance.d('Ad Adapter [$key]: ${value.state.name}', tag: 'AdService');
      });
    } catch (e, stack) {
      AppLogger.instance.e('Failed to initialize Google Mobile Ads: $e',
          tag: 'AdService', extra: stack.toString());
    }
  }

  // ── FUTURE INTEGRATIONS: Interstitial Ads Scope ───────────────────────────

  /// Preloads an Interstitial Ad for future display.
  void loadInterstitialAd({
    String? adUnitId,
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    if (!AdConstants.enableAds || kIsWeb) return;
    final unitId = adUnitId ?? AdConstants.interstitialAdUnitId;
    if (unitId.isEmpty) return;

    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          AppLogger.instance.i('Interstitial ad loaded', tag: 'AdService');
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          AppLogger.instance.w('Interstitial ad failed to load: ${error.message}', tag: 'AdService');
          onAdFailedToLoad?.call(error);
        },
      ),
    );
  }

  /// Displays the loaded Interstitial Ad if available.
  void showInterstitialAd({
    VoidCallback? onAdDismissed,
    Function(AdError)? onAdFailedToShow,
  }) {
    if (!AdConstants.enableAds || _interstitialAd == null) {
      AppLogger.instance.w('Attempted to show interstitial ad when disabled or before loading', tag: 'AdService');
      onAdDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        onAdFailedToShow?.call(error);
      },
    );

    _interstitialAd!.show();
  }

  // ── FUTURE INTEGRATIONS: Rewarded Ads Scope ──────────────────────────────

  /// Preloads a Rewarded Ad for future display.
  void loadRewardedAd({
    String? adUnitId,
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    if (!AdConstants.enableAds || kIsWeb) return;
    final unitId = adUnitId ?? AdConstants.rewardedAdUnitId;
    if (unitId.isEmpty) return;

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          AppLogger.instance.i('Rewarded ad loaded', tag: 'AdService');
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          AppLogger.instance.w('Rewarded ad failed to load: ${error.message}', tag: 'AdService');
          onAdFailedToLoad?.call(error);
        },
      ),
    );
  }

  /// Displays the loaded Rewarded Ad and invokes [onUserEarnedReward].
  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
    Function(AdError)? onAdFailedToShow,
  }) {
    if (!AdConstants.enableAds || _rewardedAd == null) {
      AppLogger.instance.w('Attempted to show rewarded ad when disabled or before loading', tag: 'AdService');
      onAdDismissed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        onAdFailedToShow?.call(error);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) => onUserEarnedReward(reward),
    );
  }
}
