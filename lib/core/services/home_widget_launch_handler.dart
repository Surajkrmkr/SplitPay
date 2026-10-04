import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

/// Maps a `dimeflow://widget/<key>` tap target to the in-app route it should
/// open. Kept in sync with the `dimeflow://widget/...` URIs the native
/// widgets (Android `PendingIntent`s, iOS `.widgetURL(_:)`) launch with —
/// see `HomeWidgetService` / the native widget providers for the other end.
const Map<String, String> _widgetRoutes = {
  'budget': '/budget',
  'transactions': '/transactions',
  'insights': '/analytics',
};

const Map<String, String> _shortcutRoutes = {
  'add-expense': '/shortcut/add-expense',
  'add-group-expense': '/shortcut/add-group-expense',
};

const _shortcutChannel = MethodChannel(
  'com.splitpay.expensetracker/app_shortcuts',
);

String? homeWidgetRouteFor(Uri? uri) {
  if (uri == null || uri.scheme != 'dimeflow') return null;

  final key = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
  if (uri.host == 'widget') return _widgetRoutes[key];
  if (uri.host == 'shortcut') return _shortcutRoutes[key];
  return null;
}

/// Routes the app to the right screen when opened by a widget or App Shortcut,
/// on both cold start and while already running.
class HomeWidgetLaunchHandler {
  static StreamSubscription<Uri?>? _subscription;
  static GoRouter? _router;
  static final _lifecycleObserver = _ShortcutLifecycleObserver();

  static Future<void> init(GoRouter router) async {
    _router = router;
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    // Cold start — the app process was launched by the widget tap.
    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _navigate(router, initialUri);
    } catch (_) {
      // Ignore — platform bindings may be unavailable (e.g. tests).
    }

    // Warm start — the app was already running in the background.
    _subscription?.cancel();
    _subscription = HomeWidget.widgetClicked.listen(
      (uri) => _navigate(router, uri),
      onError: (_) {},
    );

    await consumePendingShortcut();
  }

  static Future<void> consumePendingShortcut() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      final shortcut = await _shortcutChannel.invokeMethod<String>(
        'takePendingShortcut',
      );
      final route = shortcut == null ? null : _shortcutRoutes[shortcut];
      if (route != null) _router?.go(route);
    } on PlatformException catch (error) {
      debugPrint('Unable to retrieve pending iOS App Shortcut: $error');
    } on MissingPluginException {
      // Native shortcut support is not available in widget/unit test hosts.
    }
  }

  static void _navigate(GoRouter router, Uri? uri) {
    final route = homeWidgetRouteFor(uri);
    if (route != null) router.go(route);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _router = null;
  }
}

class _ShortcutLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      HomeWidgetLaunchHandler.consumePendingShortcut();
    }
  }
}
