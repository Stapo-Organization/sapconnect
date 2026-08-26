import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // `zb/notify` — the notification permission, without a plugin for it.
    // Registered from the engine bridge rather than from
    // didFinishLaunchingWithOptions: this target runs the UIScene lifecycle
    // (see UIApplicationSceneManifest), so the app delegate holds no window —
    // and therefore no FlutterViewController — at launch.
    let channel = FlutterMethodChannel(
      name: "zb/notify",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "status":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .authorized, .provisional, .ephemeral:
            status = "granted"
          case .denied:
            status = "denied"
          default:
            status = "undetermined"
          }
          // That callback arrives on an arbitrary queue; a channel is only
          // ever answered on the platform thread.
          DispatchQueue.main.async { result(status) }
        }
      case "request":
        UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { result(granted) }
          }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
