import 'dart:async';
import 'dart:developer' as dev;

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

void main() {
  // Funnel all debugPrint calls into AppLogger so they appear in the console.
  debugPrint = (String? message, {int? wrapWidth}) {
    final msg = message ?? '';
    AppLogger.instance.d(msg, tag: 'System');
    dev.log(msg, name: 'System');
  };

  runZonedGuarded(_init, (error, stack) {
    AppLogger.instance.e('Unhandled error: $error', tag: 'Zone', extra: stack.toString());
    dev.log('Unhandled error: $error\n$stack', name: 'Zone');
  });
}

Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await Hive.initFlutter();
  await HiveService.init();

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  Animate.restartOnHotReload = true;

  runApp(const ProviderScope(child: SplitPayApp()));
}
