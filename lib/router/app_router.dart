import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/groups/group_detail/group_detail_screen.dart';
import '../features/groups/group_settings/group_settings_screen.dart';
import '../features/groups/invite/invite_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/budget/budget_screen.dart';
import '../features/budget/budget_detail_screen.dart';
import '../data/models/notification_model.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/settings/notification_settings_screen.dart';
import '../features/settings/category_management_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/main_shell/main_shell.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/settings_provider.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, routerState) {
      // Read (not watch) — the router is refreshed via ref.listen below.
      final authAsync = ref.read(authProvider);
      final authValue = authAsync.valueOrNull;
      final onboardingDone = ref.read(onboardingCompletedProvider);
      final loc = routerState.matchedLocation;

      // Splash handles its own navigation — never redirect it.
      if (loc == '/splash') return null;

      // Login: only leave if we are definitively authenticated.
      // This prevents bouncing to /splash while Google sign-in is in progress.
      if (loc == '/login') {
        if (authValue?.isAuthenticated == true) {
          return onboardingDone ? '/home' : '/onboarding';
        }
        // Guest who tapped login from a prompt — send back to home
        if (authValue?.isGuest == true) return '/home';
        return null;
      }

      // Onboarding: allow authenticated users through; push unauthenticated out.
      if (loc == '/onboarding') {
        if (authAsync.isLoading || authValue == null) return '/splash';
        if (!authValue.isAuthenticated) return '/login';
        return null;
      }

      // Protected shell routes: guard against unauthenticated / still-loading.
      if (authAsync.isLoading || authValue == null) return '/splash';
      // Guests are allowed to browse all shell routes; only truly unauthenticated
      // users get redirected to /login.
      if (!authValue.isAuthenticated && !authValue.isGuest) return '/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      // Transactions screen — outside the shell so the navbar is hidden
      GoRoute(
        path: '/transactions',
        pageBuilder: (context, state) =>
            _detailPage(context, state, const TransactionsScreen()),
      ),
      // Full analytics screen (accessible from home mini-analytics "Full report")
      GoRoute(
        path: '/analytics',
        pageBuilder: (context, state) =>
            _detailPage(context, state, const AnalyticsScreen()),
      ),
      // Budget detail — outside the shell so the navbar is hidden
      GoRoute(
        path: '/budget/:budgetId',
        pageBuilder: (context, state) => _detailPage(
          context,
          state,
          BudgetDetailScreen(budgetId: state.pathParameters['budgetId']!),
        ),
      ),
      // Group detail routes — outside the shell so the navbar is hidden
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _detailPage(context, state, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (context, state) =>
            _detailPage(context, state, const NotificationSettingsScreen()),
      ),
      GoRoute(
        path: '/settings/categories',
        pageBuilder: (context, state) =>
            _detailPage(context, state, const CategoryManagementScreen()),
      ),
      GoRoute(
        path: '/groups/join',
        pageBuilder: (context, state) =>
            _detailPage(context, state, const InviteScreen()),
      ),
      GoRoute(
        path: '/groups/:groupId',
        pageBuilder: (context, state) => _detailPage(
          context,
          state,
          GroupDetailScreen(groupId: state.pathParameters['groupId']!),
        ),
        routes: [
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) => _detailPage(
              context,
              state,
              GroupSettingsScreen(groupId: state.pathParameters['groupId']!),
            ),
          ),
          GoRoute(
            path: 'invite',
            pageBuilder: (context, state) => _detailPage(
              context,
              state,
              InviteScreen(groupId: state.pathParameters['groupId']!),
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => CustomTransitionPage(
          key: state.pageKey,
          child: MainShell(navigationShell: navigationShell),
          transitionsBuilder: _fadeTransition,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: GroupsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budget',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: BudgetScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Refresh router when auth or onboarding state changes.
  ref.listen(authProvider, (_, __) => router.refresh());
  ref.listen(onboardingCompletedProvider, (_, __) => router.refresh());

  // Navigate when a system notification is tapped (background/terminated).
  ref.listen(notificationTapProvider, (_, next) {
    next.whenData((notification) {
      final route = notification.type.routeFor(notification.groupId);
      router.push(route);
    });
  });

  return router;
});

// Pushed "detail" screens: native CupertinoPage on iOS (so the edge
// swipe-to-pop gesture works), same slide transition as before elsewhere.
Page<void> _detailPage(
    BuildContext context, GoRouterState state, Widget child) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: _slideTransition,
  );
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) =>
    FadeTransition(opacity: animation, child: child);

Widget _slideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) =>
    SlideTransition(
      position: Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
          .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
