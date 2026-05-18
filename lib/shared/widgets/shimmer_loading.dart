import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      highlightColor: isDark ? AppColors.darkElevated : const Color(0xFFE8EAF0),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerTransactionList extends StatelessWidget {
  final int itemCount;

  const ShimmerTransactionList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _ShimmerTransactionTile(),
    );
  }
}

class _ShimmerTransactionTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShimmerBox(width: 48, height: 48, borderRadius: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(
                width: double.infinity,
                height: 14,
                borderRadius: 6,
              ),
              const SizedBox(height: 6),
              ShimmerBox(width: 100, height: 12, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ShimmerBox(width: 70, height: 16, borderRadius: 6),
      ],
    );
  }
}
