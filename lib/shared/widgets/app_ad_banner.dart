import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/ad_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_logger.dart';

/// Reusable Ad Banner widget for Dimeflow.
/// Accepts an [AdPlacement] enum to fetch the corresponding platform Ad Unit ID.
/// Supports configurable [adSize] (standard banner, large banner, medium rectangle).
class AppAdBanner extends StatefulWidget {
  final AdPlacement placement;
  final AdSize adSize;
  final EdgeInsetsGeometry margin;
  final bool showPlaceholderOnFailure;

  const AppAdBanner({
    super.key,
    required this.placement,
    this.adSize = AdSize.banner,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.showPlaceholderOnFailure = false,
  });

  @override
  State<AppAdBanner> createState() => _AppAdBannerState();
}

class _AppAdBannerState extends State<AppAdBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdConstants.enableAds || kIsWeb) {
      setState(() => _hasFailed = true);
      return;
    }

    final adUnitId = AdConstants.getAdUnitId(widget.placement);
    if (adUnitId.isEmpty) {
      setState(() => _hasFailed = true);
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
            _hasFailed = false;
          });
          AppLogger.instance.i(
            'Ad loaded successfully for placement: ${widget.placement.name}',
            tag: 'AppAdBanner',
          );
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.instance.w(
            'Ad failed to load for placement ${widget.placement.name}: ${error.message}',
            tag: 'AppAdBanner',
          );
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _hasFailed = true;
              _bannerAd = null;
            });
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConstants.enableAds) {
      return const SizedBox.shrink();
    }

    if (_hasFailed && !widget.showPlaceholderOnFailure) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double width = widget.adSize.width.toDouble() > 0
        ? widget.adSize.width.toDouble()
        : double.infinity;
    final double height = widget.adSize.height.toDouble();

    return Padding(
      padding: widget.margin,
      child: Center(
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _isAdLoaded && _bannerAd != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AdWidget(ad: _bannerAd!),
                )
              : _buildLoadingOrErrorPlaceholder(isDark),
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }

  Widget _buildLoadingOrErrorPlaceholder(bool isDark) {
    if (_hasFailed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.ads_click_rounded,
            size: 16,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            'Ad Placement (${widget.placement.name})',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Sponsored Content',
          style: TextStyle(
            fontSize: 11,
            color:
                isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
