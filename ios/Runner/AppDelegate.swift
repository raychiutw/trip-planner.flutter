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
    let accessibilityRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "TriplineAccessibility"
    )
    ReduceTransparencyPlugin.register(with: accessibilityRegistrar)
  }
}

private final class ReduceTransparencyPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let channelName = "tripline/accessibility/reduce-transparency"

  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterEventChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(ReduceTransparencyPlugin())
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    stopObserving()
    eventSink = events
    events(UIAccessibility.isReduceTransparencyEnabled)
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.eventSink?(UIAccessibility.isReduceTransparencyEnabled)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    eventSink = nil
    return nil
  }

  deinit {
    stopObserving()
  }

  private func stopObserving() {
    guard let observer else { return }
    NotificationCenter.default.removeObserver(observer)
    self.observer = nil
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
