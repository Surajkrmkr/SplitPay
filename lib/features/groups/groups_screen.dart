import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/group_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'create_group/create_group_sheet.dart';
import 'widgets/group_card.dart';
import 'widgets/my_balance_summary.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          onRefresh: () => ref.read(groupsProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Groups',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textLight,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Split expenses with friends',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Join with code button
                      GestureDetector(
                        onTap: () => context.push('/groups/join'),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Icon(
                            Icons.link_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
                      const SizedBox(width: 10),
                      // Create group button
                      GestureDetector(
                        onTap: () => _openCreateSheet(context, ref),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
                    ],
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
                ),
              ),

              // Body
              groupsAsync.when(
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const SkeletonGroupCard(),
                    childCount: 3,
                  ),
                ),
                error: (e, __) => SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Could not load groups',
                    subtitle: e.toString(),
                    actionLabel: 'Retry',
                    onAction: () =>
                        ref.read(groupsProvider.notifier).refresh(),
                  ),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.group_add_rounded,
                        title: 'No groups yet',
                        subtitle:
                            'Create a group to start splitting expenses with friends.',
                        actionLabel: '+ Create Group',
                        onAction: () => _openCreateSheet(context, ref),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return const MyBalanceSummary();
                        }
                        final group = groups[index - 1];
                        return GroupCard(
                          group: group,
                          index: index - 1,
                          onTap: () =>
                              context.push('/groups/${group.id}'),
                        );
                      },
                      childCount: groups.length + 1,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateGroupSheet(),
    );
  }
}
