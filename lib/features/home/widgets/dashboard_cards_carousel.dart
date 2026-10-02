import 'dart:async';
import 'package:flutter/material.dart';
import 'balance_card.dart';
import 'group_overview_card.dart';

class DashboardCardsCarousel extends StatefulWidget {
  const DashboardCardsCarousel({super.key});

  @override
  State<DashboardCardsCarousel> createState() => _DashboardCardsCarouselState();
}

class _DashboardCardsCarouselState extends State<DashboardCardsCarousel> {
  static const _cardCount = 2;
  final _pageController = PageController();
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _autoSlideTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _showNextCard(),
    );
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showNextCard() {
    if (!mounted || !_pageController.hasClients) return;
    final nextPage = (_currentPage + 1) % _cardCount;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: const [
              BalanceCard(),
              GroupOverviewCard(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _cardCount,
            (index) => GestureDetector(
              onTap: () => _goToPage(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == _currentPage ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.18)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
