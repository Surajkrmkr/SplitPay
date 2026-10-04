import Flutter
import FirebaseMessaging
import ImageIO
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  FlutterStreamHandler
{
  private let sharedImagesGroup = "group.com.splitpay.expensetracker"
  private let pendingSharedImagesKey = "pendingSharedImageNames"
  private var sharedImagesEventSink: FlutterEventSink?

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
    // Required for flutter_local_notifications to deliver scheduled reminders
    // (Firebase later chains to this delegate for non-FCM notifications).
    UNUserNotificationCenter.current().delegate = self
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

    let sharedImagesChannel = FlutterMethodChannel(
      name: "com.splitpay.expensetracker/shared_images",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    sharedImagesChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(
          code: "share_unavailable",
          message: "Shared images are unavailable.",
          details: nil
        ))
        return
      }
      switch call.method {
      case "takePendingImages":
        guard let directory = self.sharedImagesDirectory(),
              let defaults = UserDefaults(suiteName: self.sharedImagesGroup)
        else {
          result(FlutterError(
            code: "share_storage_unavailable",
            message: "Shared image storage is unavailable.",
            details: nil
          ))
          return
        }
        let names = defaults.stringArray(forKey: self.pendingSharedImagesKey) ?? []
        let paths = names.compactMap { name -> String? in
          guard URL(fileURLWithPath: name).lastPathComponent == name else {
            return nil
          }
          let file = directory.appendingPathComponent(name).standardizedFileURL
          guard file.deletingLastPathComponent() == directory.standardizedFileURL,
                FileManager.default.fileExists(atPath: file.path)
          else {
            return nil
          }
          return file.path
        }
        let remainingNames = paths.map { URL(fileURLWithPath: $0).lastPathComponent }
        if remainingNames.isEmpty {
          defaults.removeObject(forKey: self.pendingSharedImagesKey)
        } else {
          defaults.set(remainingNames, forKey: self.pendingSharedImagesKey)
        }
        result(["paths": paths, "omittedCount": 0])
      case "prepareImageForOcr":
        guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
          result(FlutterError(
            code: "image_path_missing",
            message: "Shared image path is missing.",
            details: nil
          ))
          return
        }
        do {
          result(try self.prepareImageForOcr(path: path))
        } catch let error as SharedImagePreparationError {
          NSLog("[UPI Import] Image preparation failed at stage: %@.", error.code)
          result(FlutterError(
            code: error.code,
            message: "Shared image could not be prepared for OCR.",
            details: nil
          ))
        } catch {
          NSLog("[UPI Import] Image preparation failed unexpectedly.")
          result(FlutterError(
            code: "image_prepare_failed",
            message: "Shared image could not be prepared for OCR.",
            details: nil
          ))
        }
      case "deleteImages":
        guard let directory = self.sharedImagesDirectory(),
              let arguments = call.arguments as? [String: Any],
              let paths = arguments["paths"] as? [String]
        else {
          result(FlutterError(
            code: "share_delete_invalid",
            message: "Shared image cleanup request was invalid.",
            details: nil
          ))
          return
        }
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        var deletedNames = Set<String>()
        for path in paths {
          let file = URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
          guard file.deletingLastPathComponent() == root else {
            result(FlutterError(
              code: "share_delete_invalid",
              message: "Shared image cleanup request was invalid.",
              details: nil
            ))
            return
          }
          do {
            if FileManager.default.fileExists(atPath: file.path) {
              try FileManager.default.removeItem(at: file)
            }
            deletedNames.insert(file.lastPathComponent)
          } catch {
            result(FlutterError(
              code: "share_delete_failed",
              message: "Shared image cleanup failed.",
              details: nil
            ))
            return
          }
        }
        if let defaults = UserDefaults(suiteName: self.sharedImagesGroup) {
          let remaining = (defaults.stringArray(forKey: self.pendingSharedImagesKey) ?? [])
            .filter { !deletedNames.contains($0) }
          if remaining.isEmpty {
            defaults.removeObject(forKey: self.pendingSharedImagesKey)
          } else {
            defaults.set(remaining, forKey: self.pendingSharedImagesKey)
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(
      name: "com.splitpay.expensetracker/shared_images/events",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sharedImagesEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sharedImagesEventSink = nil
    return nil
  }

  private func sharedImagesDirectory() -> URL? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: sharedImagesGroup
    ) else {
      return nil
    }
    let directory = container
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Caches", isDirectory: true)
      .appendingPathComponent("SplitPaySharedImages", isDirectory: true)
    let expiry = Date().addingTimeInterval(-24 * 60 * 60)
    if let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey]
    ) {
      for file in files {
        if let modified = try? file.resourceValues(
          forKeys: [.contentModificationDateKey]
        ).contentModificationDate,
           modified < expiry
        {
          try? FileManager.default.removeItem(at: file)
        }
      }
    }
    return directory
  }

  private func prepareImageForOcr(path: String) throws -> String {
    guard let directory = sharedImagesDirectory() else {
      throw SharedImagePreparationError.cacheUnavailable
    }
    let sourceURL = URL(fileURLWithPath: path)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let root = directory.standardizedFileURL.resolvingSymlinksInPath()
    guard sourceURL.deletingLastPathComponent() == root,
          let attributes = try? FileManager.default.attributesOfItem(
            atPath: sourceURL.path
          ),
          let fileSize = attributes[.size] as? NSNumber,
          fileSize.intValue > 0,
          fileSize.intValue <= 25 * 1024 * 1024
    else {
      throw SharedImagePreparationError.invalidPathOrSize
    }

    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
      throw SharedImagePreparationError.sourceUndecodable
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 2600,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(
      source,
      0,
      options as CFDictionary
    ) else {
      throw SharedImagePreparationError.thumbnailUnavailable
    }

    let destinationURL = directory
      .appendingPathComponent("\(UUID().uuidString).jpg")
    guard let jpegData = UIImage(cgImage: image).jpegData(compressionQuality: 0.92) else {
      throw SharedImagePreparationError.jpegEncodingFailed
    }
    do {
      try jpegData.write(to: destinationURL, options: .atomic)
    } catch {
      throw SharedImagePreparationError.jpegWriteFailed
    }
    guard let decodedOutput = UIImage(contentsOfFile: destinationURL.path),
          decodedOutput.cgImage != nil
    else {
      try? FileManager.default.removeItem(at: destinationURL)
      throw SharedImagePreparationError.outputUndecodable
    }
    return destinationURL.path
  }
}

private enum SharedImagePreparationError: Error {
  case cacheUnavailable
  case invalidPathOrSize
  case sourceUndecodable
  case thumbnailUnavailable
  case jpegEncodingFailed
  case jpegWriteFailed
  case outputUndecodable

  var code: String {
    switch self {
    case .cacheUnavailable:
      return "image_cache_unavailable"
    case .invalidPathOrSize:
      return "image_path_or_size_invalid"
    case .sourceUndecodable:
      return "image_source_undecodable"
    case .thumbnailUnavailable:
      return "image_thumbnail_unavailable"
    case .jpegEncodingFailed:
      return "image_jpeg_encoding_failed"
    case .jpegWriteFailed:
      return "image_jpeg_write_failed"
    case .outputUndecodable:
      return "image_output_undecodable"
    }
  }
}
