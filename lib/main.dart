import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/services/app_logger.dart';
import 'data/services/hive_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/reminder_service.dart';

void main() {
  // Funnel all debugPrint calls into AppLogger so they appear in the console.
  debugPrint = (String? message, {int? wrapWidth}) {
    final msg = message ?? '';
    AppLogger.instance.d(msg, tag: 'System');
    dev.log(msg, name: 'System');
  };

  // Flutter framework errors: widget build failures, rendering errors, etc.
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.instance.e(
      details.exceptionAsString(),
      tag: 'Flutter',
      extra: details.stack?.toString(),
    );
    // Still dump to console in debug mode.
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  };

  // Errors that escape the zone (platform channel errors, isolate errors, etc.)
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.e('$error', tag: 'Platform', extra: stack.toString());
    dev.log('$error\n$stack', name: 'Platform');
    return true;
  };

  runZonedGuarded(_init, (error, stack) {
    AppLogger.instance.e('$error', tag: 'Zone', extra: stack.toString());
    dev.log('$error\n$stack', name: 'Zone');
  });
}

Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.instance.i('App initializing', tag: 'Init');

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    AppLogger.instance.i('Firebase ready', tag: 'Init');
  } catch (e) {
    AppLogger.instance.e('Firebase init failed: $e', tag: 'Init');
  }

  await Hive.initFlutter();
  await HiveService.init();
  AppLogger.instance.i('Hive ready', tag: 'Init');

  try {
    await NotificationService.instance.initialize();
    await ReminderService.instance.init();
    AppLogger.instance.i('NotificationService ready', tag: 'Init');
  } catch (e) {
    AppLogger.instance.e('NotificationService init failed: $e', tag: 'Init');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  Animate.restartOnHotReload = true;

  runApp(const ProviderScope(child: SplitPayApp()));
}
