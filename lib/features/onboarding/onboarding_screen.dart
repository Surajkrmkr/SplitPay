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
  String _selectedCurrency = '₹';

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

  Future<void> _complete() async {
    await ref.read(currencyProvider.notifier).setCurrency(_selectedCurrency);
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
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
                      final isSelected = symbol == _selectedCurrency;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCurrency = symbol),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _complete,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Get Started',
                                style: TextStyle(
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
                ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
                SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
