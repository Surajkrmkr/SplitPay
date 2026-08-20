import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/ad_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../providers/group_provider.dart';
import '../../shared/widgets/app_ad_banner.dart';
import '../../shared/widgets/app_search_bar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'create_group/create_group_sheet.dart';
import 'widgets/group_card.dart';
import 'widgets/my_balance_summary.dart';
import '../../shared/utils/guest_guard.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    final groupsAsync = ref.watch(groupsProvider);
    final filteredGroups = ref.watch(searchedGroupsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: primary,
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
                                color:
                                    isDark ? Colors.white : AppColors.textLight,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
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
                        onTap: () => requireAuth(
                          context,
                          ref,
                          () => context.push('/groups/join'),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? cardBg
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Icon(
                            Icons.link_rounded,
                            color: primary,
                            size: 22,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .scale(begin: const Offset(0.8, 0.8)),
                      const SizedBox(width: 10),
                      // Create group button
                      GestureDetector(
                        onTap: () => requireAuth(
                          context,
                          ref,
                          () => _openCreateSheet(context, ref),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primary, primary.withValues(alpha: 0.85)],
                            ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.35),
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
                      )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .scale(begin: const Offset(0.8, 0.8)),
                    ],
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
                ),
              ),

              // Search bar (only when data has loaded)
              if (groupsAsync.hasValue &&
                  (groupsAsync.valueOrNull?.isNotEmpty ?? false))
                SliverToBoxAdapter(
                  child: AppSearchBar(
                    hintText: 'Search groups...',
                    onChanged: (v) =>
                        ref.read(groupSearchQueryProvider.notifier).state = v,
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
                    subtitle: friendlyErrorMessage(e),
                    actionLabel: 'Retry',
                    onAction: () => ref.read(groupsProvider.notifier).refresh(),
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
                        onAction: () => requireAuth(
                          context,
                          ref,
                          () => _openCreateSheet(context, ref),
                        ),
                      ),
                    );
                  }

                  if (filteredGroups.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No groups found',
                        subtitle: 'Try a different search term.',
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return const MyBalanceSummary();
                        }
                        final group = filteredGroups[index - 1];
                        return GroupCard(
                          group: group,
                          index: index - 1,
                          onTap: () => context.push('/groups/${group.id}'),
                        );
                      },
                      childCount: filteredGroups.length + 1,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(
                child: AppAdBanner(
                  placement: AdPlacement.groupsListBanner,
                  margin: EdgeInsets.fromLTRB(20, 12, 20, 12),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100 + MediaQuery.of(context).padding.bottom,
                ),
              ),
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
