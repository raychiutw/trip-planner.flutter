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
    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "TriplineNotificationPermission"
      ),
      let accessibilityRegistrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "TriplineAccessibility"
      ),
      let e2eSemanticsRegistrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "TriplineE2ESemantics"
      )
    else { return }
    NotificationPermissionPlugin.register(with: registrar)
    ReduceTransparencyPlugin.register(with: accessibilityRegistrar)
    E2ESemanticsPlugin.register(with: e2eSemanticsRegistrar, appDelegate: self)
  }
}

/// e2e 專用:讓 XCTest 的 accessibility tree 看得到 Flutter 的 `Semantics`。
///
/// iOS 實機只在 VoiceOver／Switch Control／Speak Screen 開啟時才建 accessibility
/// bridge(simulator 是無條件建,所以模擬器過、Test Lab 不過)。Dart 側本來可以用
/// `PlatformDispatcher.setSemanticsTreeEnabled()` 打開,但測試環境拿到的是
/// `TestPlatformDispatcher`,它沒有轉發該方法、被自己的 `noSuchMethod` 靜默吞掉
/// —— 繞不過去。詳見 issue #104 與 `docs/discovery/native-map-gestures.md`。
///
/// **gating:** production 程式碼沒有任何呼叫點,只有 `patrol_test/` 會呼叫。
/// handler 存在但永遠不會被觸發,不改變 app 的正常行為。
private final class E2ESemanticsPlugin: NSObject, FlutterPlugin {
  private static let channelName = "tripline/e2e/semantics"
  private weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate?) {
    self.appDelegate = appDelegate
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    register(with: registrar, appDelegate: nil)
  }

  static func register(with registrar: FlutterPluginRegistrar, appDelegate: AppDelegate?) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(
      E2ESemanticsPlugin(appDelegate: appDelegate),
      channel: channel
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "ensureEnabled" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let controller = appDelegate?.window?.rootViewController as? FlutterViewController
    else {
      result(false)
      return
    }
    controller.engine?.ensureSemanticsEnabled()
    result(true)
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
