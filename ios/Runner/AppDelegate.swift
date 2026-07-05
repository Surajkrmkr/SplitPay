import Flutter
import FirebaseMessaging
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FirebaseMessaging normally does this itself in response to
    // UIApplicationDidFinishLaunchingNotification, but with the
    // implicit-engine template its observer isn't registered until the
    // storyboard's FlutterViewController loads — after that notification has
    // already fired and gone unheard. Trigger registration ourselves here so
    // the device token flow (and FirebaseMessaging.getToken()) isn't dead on
    // arrival.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // With the implicit-engine template, GeneratedPluginRegistrant (and thus
  // FirebaseMessaging's app-delegate observer) may not be registered yet by
  // the time UIKit delivers this one-shot callback, silently dropping the
  // APNS token and leaving FirebaseMessaging.getToken() permanently failing
  // with apns-token-not-set. Setting it directly here bypasses that race.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // FirebaseMessaging's own setup (including making itself the
    // UNUserNotificationCenter.delegate, which foreground onMessage delivery
    // depends on) normally runs in response to
    // UIApplicationDidFinishLaunchingNotification. With the implicit-engine
    // template that notification already fired before plugins were
    // registered, so the plugin's observer never saw it and never ran its
    // setup. Re-posting it now — after registration — lets that observer
    // (which is listening at this point) catch it and complete setup
    // properly, fixing foreground push delivery.
    NotificationCenter.default.post(
      name: UIApplication.didFinishLaunchingNotification,
      object: UIApplication.shared
    )

    let timezoneChannel = FlutterMethodChannel(
      name: "com.splitpay.expensetracker/timezone",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    timezoneChannel.setMethodCallHandler { call, result in
      if call.method == "getLocalTimezone" {
        result(TimeZone.current.identifier)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
