import Foundation
import XCTest
import patrol

/// Patrol server extension：提供原生多指手勢給 Dart 端直接呼叫。
///
/// **為什麼不能用 accessibility label 傳訊號**（issue #104）：iOS 實機上
/// XCUI 的 accessibility tree 裡完全沒有 Flutter 的 `Semantics` 節點 ——
/// run 30175947137 dump 出來只有 `Application` / `Window` / 五層無 label 的
/// `Other` / `platform_view[0].overlay[*]`。Dart 側
/// `PlatformDispatcher.setSemanticsTreeEnabled()` 與 native 側
/// `FlutterEngine.ensureSemanticsEnabled()` 都試過，都無法讓 Flutter 的
/// semantics 進到那棵樹。
///
/// 所以改走 Patrol 4.8.0 的 server extension：automation server 跑在 XCTest
/// runner 行程內，Dart 端以 HTTP POST 直接請求手勢，完全繞開 a11y tree。
///
/// Patrol 本身到 4.8.0 仍**沒有** pinch／rotate 的原生 API，這裡用的是
/// `XCUIElement` 的公開多指介面。
@objc(TriplineGestureExtension)
public class TriplineGestureExtension: NSObject, PatrolServerExtension {
  public override required init() {
    super.init()
  }

  public var name: String { "tripline-native-gestures" }

  public func register(on registrar: PatrolRouteRegistrar) {
    registrar.post("tripline/gesture") { body in
      let kind = try Self.decodeKind(from: body)
      let app = XCUIApplication()

      switch kind {
      case "pinch":
        app.pinch(withScale: 2.0, velocity: 1.0)
      case "rotate":
        app.rotate(.pi / 2, withVelocity: 1.0)
      case "doubleTap":
        app.doubleTap()
      default:
        throw TriplineGestureError.unsupported(kind)
      }

      NSLog("Tripline gesture extension: performed \(kind)")
      return try JSONSerialization.data(withJSONObject: ["ok": true])
    }
  }

  private static func decodeKind(from body: Data) throws -> String {
    guard
      let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
      let kind = json["kind"] as? String
    else {
      throw TriplineGestureError.malformedRequest
    }
    return kind
  }
}

enum TriplineGestureError: Error {
  case malformedRequest
  case unsupported(String)
}
