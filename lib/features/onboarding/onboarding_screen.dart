import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  String _selectedCurrency = '₹';

  static const _infoPages = [
    _OnboardingData(
      emoji: '💸',
      imagePath: 'assets/icon/app_icon.png',
      gradient: [Color(0xFF004E35), Color(0xFF002418)],
      accentColor: AppColors.primary,
      title: 'Track Every Penny',
      subtitle:
          'Effortlessly log your income and expenses. Know exactly where your money goes each day.',
    ),
    _OnboardingData(
      emoji: '📊',
      gradient: [Color(0xFF1A2455), Color(0xFF0D1330)],
      accentColor: AppColors.secondary,
      title: 'Visualize Spending',
      subtitle:
          'Beautiful charts and insights reveal your spending patterns. Make smarter financial decisions.',
    ),
    _OnboardingData(
      emoji: '🎯',
      gradient: [Color(0xFF3D1A2A), Color(0xFF1E0D15)],
      accentColor: Color(0xFFFF6B9D),
      title: 'Stay on Budget',
      subtitle:
          'Set spending awareness and achieve your financial goals. Your money, under control.',
    ),
  ];

  // Total pages = 3 info + 1 currency
  static const int _totalPages = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await ref.read(currencyProvider.notifier).setCurrency(_selectedCurrency);
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _totalPages,
            itemBuilder: (_, i) {
              if (i < _infoPages.length) {
                return _OnboardingPage(data: _infoPages[i]);
              }
              return _CurrencyPage(
                selectedCurrency: _selectedCurrency,
                onSelected: (c) => setState(() => _selectedCurrency = c),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomControls(
              currentPage: _currentPage,
              total: _totalPages,
              accentColor: _currentPage < _infoPages.length
                  ? _infoPages[_currentPage].accentColor
                  : AppColors.primary,
              onNext: () {
                if (_currentPage < _totalPages - 1) {
                  _controller.nextPage(
                    duration: 350.ms,
                    curve: Curves.easeInOut,
                  );
                } else {
                  _complete();
                }
              },
              onSkip: _complete,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Currency Page ─────────────────────────────────────────────

class _CurrencyPage extends StatelessWidget {
  final String selectedCurrency;
  final ValueChanged<String> onSelected;

  const _CurrencyPage({
    required this.selectedCurrency,
    required this.onSelected,
  });

  static const _currencies = [
    ('₹', 'Indian Rupee', 'INR'),
    ('\$', 'US Dollar', 'USD'),
    ('€', 'Euro', 'EUR'),
    ('£', 'British Pound', 'GBP'),
    ('¥', 'Japanese Yen', 'JPY'),
    ('A\$', 'Australian Dollar', 'AUD'),
    ('C\$', 'Canadian Dollar', 'CAD'),
    ('S\$', 'Singapore Dollar', 'SGD'),
    ('د.إ', 'UAE Dirham', 'AED'),
    ('৳', 'Bangladeshi Taka', 'BDT'),
    ('₩', 'South Korean Won', 'KRW'),
    ('R', 'South African Rand', 'ZAR'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF004E35), AppColors.darkBg],
          stops: [0.0, 0.65],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 2),
                  ),
                  child: const Center(
                    child: Text('💱', style: TextStyle(fontSize: 36)),
                  ),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .fadeIn(duration: 400.ms),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  'Choose Your Currency',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.3, end: 0, delay: 200.ms),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Pick the currency you use daily. You can change this anytime in Settings.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _currencies.length,
                  itemBuilder: (_, i) {
                    final (symbol, name, code) = _currencies[i];
                    final isSelected = symbol == selectedCurrency;
                    return GestureDetector(
                      onTap: () => onSelected(symbol),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.darkCard.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.darkBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              symbol,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              code,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.8)
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: (i * 40).ms).fadeIn().scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1, 1),
                          duration: 250.ms,
                        );
                  },
                ),
              ),
              const SizedBox(height: 160),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info Page ─────────────────────────────────────────────────

class _OnboardingData {
  final String emoji;
  final String? imagePath;
  final List<Color> gradient;
  final Color accentColor;
  final String title;
  final String subtitle;

  const _OnboardingData({
    required this.emoji,
    this.imagePath,
    required this.gradient,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [data.gradient[0], AppColors.darkBg],
          stops: const [0.0, 0.7],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              // App-icon pages render the icon flat (it has its own background);
              // emoji pages keep the gradient-circle hero element.
              (data.imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(44),
                          child: Image.asset(
                            data.imagePath!,
                            width: 200,
                            height: 200,
                          ),
                        )
                      : Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                data.gradient[0].withValues(alpha: 0.8),
                                data.gradient[1],
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: data.accentColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              data.emoji,
                              style: const TextStyle(fontSize: 80),
                            ),
                          ),
                        ))
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 56),
              Text(
                data.title,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, delay: 200.ms),
              const SizedBox(height: 16),
              Text(
                data.subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, delay: 350.ms),
              const SizedBox(height: 160),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom Controls ───────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int total;
  final Color accentColor;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _BottomControls({
    required this.currentPage,
    required this.total,
    required this.accentColor,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == total - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        32,
        24,
        32,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.darkBg.withValues(alpha: 0),
            AppColors.darkBg,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              total,
              (i) => AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == currentPage ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? accentColor
                      : AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              if (!isLast)
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                const Spacer(),
              const Spacer(),
              AnimatedContainer(
                duration: 300.ms,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onNext,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
