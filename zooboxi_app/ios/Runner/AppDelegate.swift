import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized
              || settings.authorizationStatus == .provisional else { return }
      DispatchQueue.main.async { application.registerForRemoteNotifications() }
    }
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
            DispatchQueue.main.async {
              // The permission is only half of push: without this the device
              // never gets an APNs token, Firebase never mints an FCM one, and
              // the store registers a customer it can never reach. Local
              // reminders worked without it, which is exactly why its absence
              // would have gone unnoticed.
              if granted {
                UIApplication.shared.registerForRemoteNotifications()
              }
              result(granted)
            }
          }
      case "sync":
        // Replace every scheduled program reminder («عدّاد الأكل», the
        // subscription date, a pet's birthday) with the list the store just
        // computed. These stay *local* even now that push exists: the dates
        // are known days ahead, and a reminder the phone can carry itself
        // should never depend on a server being reachable that morning.
        let center = UNUserNotificationCenter.current()
        let args = call.arguments as? [String: Any]
        let items = args?["items"] as? [[String: Any]] ?? []
        center.getPendingNotificationRequests { pending in
          let ours = pending.map { $0.identifier }.filter { $0.hasPrefix("zb-") }
          center.removePendingNotificationRequests(withIdentifiers: ours)
          for item in items {
            guard let id = item["id"] as? String,
                  let title = item["title"] as? String,
                  let body = item["body"] as? String,
                  let at = item["at"] as? Int else { continue }
            let fire = Date(timeIntervalSince1970: TimeInterval(at))
            if fire.timeIntervalSinceNow < 60 { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let route = item["route"] as? String { content.userInfo = ["route": route] }
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: "zb-" + id, content: content, trigger: trigger))
          }
          DispatchQueue.main.async { result(nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
