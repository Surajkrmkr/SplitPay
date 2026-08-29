import 'dart:async';

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

/// Routes the app to the right screen when it's opened by tapping one of the
/// home-screen widgets, on both cold start and while already running.
class HomeWidgetLaunchHandler {
  static StreamSubscription<Uri?>? _subscription;

  static Future<void> init(GoRouter router) async {
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
  }

  static void _navigate(GoRouter router, Uri? uri) {
    if (uri == null || uri.scheme != 'dimeflow' || uri.host != 'widget') {
      return;
    }
    final key = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final route = _widgetRoutes[key];
    if (route != null) router.go(route);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
