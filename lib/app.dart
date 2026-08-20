import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      builder: (context, child) => NetworkStatusBannerListener(
        child: InAppNotificationListener(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
