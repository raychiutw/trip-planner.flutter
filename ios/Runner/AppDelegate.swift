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
      ),
      let proofKeyRegistrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "TriplineProofKey"
      )
    else { return }
    NotificationPermissionPlugin.register(with: registrar)
    ReduceTransparencyPlugin.register(with: accessibilityRegistrar)
    E2ESemanticsPlugin.register(with: e2eSemanticsRegistrar, appDelegate: self)
    ProofKeyPlugin.register(with: proofKeyRegistrar)
  }
}

// MARK: proof-key codec begin
/// DPoP 金鑰的純轉換（不碰 Keychain，可在任何 Swift 環境單獨驗證）。
enum ProofKeyCodec {
  /// SecKey 匯出的未壓縮公鑰點（0x04 ‖ x ‖ y，65 bytes）→ base64url 的 x、y。
  static func publicPoint(fromExternalRepresentation data: Data) -> [String: String]? {
    guard data.count == 65, data[data.startIndex] == 0x04 else { return nil }
    let x = data.subdata(in: (data.startIndex + 1)..<(data.startIndex + 33))
    let y = data.subdata(in: (data.startIndex + 33)..<(data.startIndex + 65))
    return ["x": base64URL(x), "y": base64URL(y)]
  }

  /// ECDSA 的 DER 簽章（SEQUENCE { INTEGER r, INTEGER s }）→ ES256 要的 r‖s 共 64 bytes。
  static func rawSignature(fromDER der: Data) -> Data? {
    let bytes = [UInt8](der)
    var index = 0
    func readLength() -> Int? {
      guard index < bytes.count else { return nil }
      let first = Int(bytes[index])
      index += 1
      if first < 0x80 { return first }
      let count = first & 0x7f
      guard count >= 1, count <= 2, index + count <= bytes.count else { return nil }
      var value = 0
      for _ in 0..<count {
        value = (value << 8) | Int(bytes[index])
        index += 1
      }
      return value
    }
    func readInteger() -> [UInt8]? {
      guard index < bytes.count, bytes[index] == 0x02 else { return nil }
      index += 1
      guard let length = readLength(), index + length <= bytes.count else { return nil }
      var value = Array(bytes[index..<(index + length)])
      index += length
      while value.first == 0, value.count > 1 { value.removeFirst() }
      guard value.count <= 32 else { return nil }
      return Array(repeating: 0, count: 32 - value.count) + value
    }
    guard index < bytes.count, bytes[index] == 0x30 else { return nil }
    index += 1
    guard readLength() != nil, let r = readInteger(), let s = readInteger() else { return nil }
    return Data(r + s)
  }

  static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
// MARK: proof-key codec end

/// DPoP 硬體金鑰（ADR-0015）：P-256 私鑰在 Secure Enclave 內產生，不可匯出、
/// 不備份、不遷移（`WhenUnlockedThisDeviceOnly`）；裝置解鎖即可簽，不要求生物辨識。
/// 模擬器與沒有 Secure Enclave 的裝置建立會失敗，一律回 `unsupported`，
/// 由 Dart 端退回軟體金鑰。
private final class ProofKeyPlugin: NSObject, FlutterPlugin {
  private static let channelName = "tripline/proof-key"
  private static let tag = Data("com.raychiu.tripline.dpop-key".utf8)

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(ProofKeyPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "create":
      create(result)
    case "load":
      load(result)
    case "sign":
      sign(call, result)
    case "delete":
      Self.deleteKey()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static var keyQuery: [String: Any] {
    [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    ]
  }

  private static func deleteKey() {
    SecItemDelete(keyQuery as CFDictionary)
  }

  /// 找不到回 `(nil, errSecItemNotFound)`；其他狀態（例如裝置鎖定的
  /// `errSecInteractionNotAllowed`）要讓呼叫端知道「暫時讀不到」，不能當成沒有金鑰。
  private static func loadKey() -> (key: SecKey?, status: OSStatus) {
    var query = keyQuery
    query[kSecReturnRef as String] = true
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let item else { return (nil, status) }
    return (item as! SecKey, status)
  }

  private static func point(of privateKey: SecKey) -> [String: String]? {
    guard let publicKey = SecKeyCopyPublicKey(privateKey),
      let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
    else { return nil }
    return ProofKeyCodec.publicPoint(fromExternalRepresentation: data)
  }

  private func create(_ result: @escaping FlutterResult) {
    Self.deleteKey()
    var error: Unmanaged<CFError>?
    guard
      let access = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .privateKeyUsage,
        &error
      )
    else {
      result(FlutterError(code: "unsupported", message: "access control", details: nil))
      return
    }
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: Self.tag,
        kSecAttrAccessControl as String: access,
      ],
    ]
    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
      let point = Self.point(of: key)
    else {
      result(FlutterError(code: "unsupported", message: "secure enclave", details: nil))
      return
    }
    result(point)
  }

  private func load(_ result: @escaping FlutterResult) {
    let loaded = Self.loadKey()
    guard let key = loaded.key else {
      if loaded.status == errSecItemNotFound {
        result(nil)
      } else {
        result(FlutterError(code: "key_unavailable", message: "status \(loaded.status)", details: nil))
      }
      return
    }
    guard let point = Self.point(of: key) else {
      result(FlutterError(code: "key_unavailable", message: "public key", details: nil))
      return
    }
    result(point)
  }

  private func sign(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let data = (arguments["data"] as? FlutterStandardTypedData)?.data,
      let key = Self.loadKey().key
    else {
      result(FlutterError(code: "no_key", message: "missing key or data", details: nil))
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      var error: Unmanaged<CFError>?
      let signature = SecKeyCreateSignature(
        key,
        .ecdsaSignatureMessageX962SHA256,
        data as CFData,
        &error
      ) as Data?
      let raw = signature.flatMap { ProofKeyCodec.rawSignature(fromDER: $0) }
      DispatchQueue.main.async {
        if let raw {
          result(FlutterStandardTypedData(bytes: raw))
        } else {
          result(FlutterError(code: "sign_failed", message: "sign", details: nil))
        }
      }
    }
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

  /// 找出承載 Flutter 的 view controller。
  ///
  /// 不能只看 `appDelegate.window?.rootViewController` —— Patrol／XCTest 環境下
  /// 實測取不到（run 30166845261 的 log 是 `no FlutterViewController`）。改成掃過
  /// 所有 scene 的 window，並遞迴進容器與 presented controller。
  private static func findFlutterViewController(
    from appDelegate: AppDelegate?
  ) -> FlutterViewController? {
    var roots: [UIViewController] = []
    if let root = appDelegate?.window?.rootViewController {
      roots.append(root)
    }
    roots += UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .compactMap(\.rootViewController)

    for root in roots {
      if let found = search(root) { return found }
    }
    return nil
  }

  private static func search(_ controller: UIViewController) -> FlutterViewController? {
    if let flutter = controller as? FlutterViewController { return flutter }
    for child in controller.children {
      if let found = search(child) { return found }
    }
    if let presented = controller.presentedViewController {
      return search(presented)
    }
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "ensureEnabled" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let controller = Self.findFlutterViewController(from: appDelegate) else {
      // 診斷用：失敗時要能和「channel 根本沒被呼叫」區分開來（見 #104）。
      NSLog("Tripline e2e semantics: no FlutterViewController")
      result(false)
      return
    }
    // `FlutterViewController.engine` 在 header 沒有 `_Nullable`，橋接到 Swift
    // 是 non-optional，不能用 optional chaining。
    controller.engine.ensureSemanticsEnabled()
    NSLog("Tripline e2e semantics: ensureSemanticsEnabled called")
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
