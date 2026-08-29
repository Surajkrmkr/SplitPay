import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/services/home_widget_launch_handler.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'shared/widgets/in_app_notification_banner.dart';
import 'shared/widgets/network_status_banner.dart';

class SplitPayApp extends ConsumerWidget {
  const SplitPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SplitPay',
      debugShowCheckedModeBanner: false,
      themeMode: themeState.mode,
      theme: AppTheme.buildLightTheme(themeState.preset, themeState.bgStyle),
      darkTheme: AppTheme.buildDarkTheme(themeState.preset, themeState.bgStyle),
      routerConfig: router,
      builder: (context, child) => _HomeWidgetLaunchWatcher(
        router: router,
        child: NetworkStatusBannerListener(
          child: InAppNotificationListener(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Wires up [HomeWidgetLaunchHandler] once per [router] instance so tapping a
/// home-screen widget (cold start or while the app is already running)
/// navigates to the matching screen.
class _HomeWidgetLaunchWatcher extends StatefulWidget {
  final GoRouter router;
  final Widget child;
  const _HomeWidgetLaunchWatcher({required this.router, required this.child});

  @override
  State<_HomeWidgetLaunchWatcher> createState() =>
      _HomeWidgetLaunchWatcherState();
}

class _HomeWidgetLaunchWatcherState extends State<_HomeWidgetLaunchWatcher> {
  @override
  void initState() {
    super.initState();
    HomeWidgetLaunchHandler.init(widget.router);
  }

  @override
  void didUpdateWidget(covariant _HomeWidgetLaunchWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      HomeWidgetLaunchHandler.init(widget.router);
    }
  }

  @override
  void dispose() {
    HomeWidgetLaunchHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
