import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard
      let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !apiKey.isEmpty,
      !apiKey.contains("$(")
    else {
      fatalError("Missing GOOGLE_MAPS_IOS_API_KEY build setting")
    }
    GMSServices.provideAPIKey(apiKey)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "TriplineNotificationPermission"
    )
    NotificationPermissionPlugin.register(with: registrar)
  }
}

private final class NotificationPermissionPlugin: NSObject, FlutterPlugin {
  private static let channelName = "tripline/notification-permission"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(NotificationPermissionPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      resolveStatus(result)
    case "request":
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound]
      ) { _, _ in
        self.resolveStatus(result)
      }
    case "openSettings":
      DispatchQueue.main.async {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(nil)
          return
        }
        UIApplication.shared.open(url) { _ in result(nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func resolveStatus(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let value: String
      switch settings.authorizationStatus {
      case .notDetermined:
        value = "notDetermined"
      case .denied:
        value = "denied"
      case .authorized, .provisional, .ephemeral:
        value = "granted"
      @unknown default:
        value = "denied"
      }
      DispatchQueue.main.async { result(value) }
    }
  }
}
