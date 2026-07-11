# WS-C / C1:Google Maps SDK 底座 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development 或 superpowers:executing-plans 逐任務實作。Steps 用 checkbox。

**Goal:** 把地圖底層從 `flutter_map`(OSM)換成 `google_maps_flutter`,保留現有兩個地圖畫面的功能不退化;彩色序號 pin 改用 runtime bitmap。C2 才加 polyline/marker 狀態/`/map` 行程總覽等 parity。

**Architecture:** `map_adapter.dart` 維持套件無關抽象(`TripMapPoint`/`TripMapMarker`/`TripMapRoute`/controller),底層由 flutter_map 換成 `GoogleMap` widget。Google `Marker` 只吃 `BitmapDescriptor` → 新增 `marker_bitmap.dart`(Canvas→PNG,可單元測、不需 API key)。camera fit/move 改 async ready gate(map 未 layout 前呼叫會 throw)。

**Tech Stack:** `google_maps_flutter ^2.12.1`、`dart:ui` Canvas、既有 riverpod/測試框架。

## Global Constraints

- 文件/註解/commit 繁體中文(台灣),技術名詞英文。
- TDD 紅綠重構;完成定義:`flutter analyze` 零 error/warning + `flutter test` 全綠。
- 不 commit 到 master;分支 `feature/google-maps-migration`。
- **iOS 最低版本 13 → 15**(GoogleMaps pod 硬需求,D3)。
- **API key 不進版控**:iOS `Secrets.xcconfig`、Android `local.properties`,`.gitignore` 排除,附 `*.example` 範本。iOS/Android 兩把分開(bundle id `com.raychiu.tripline` / debug SHA-1)。
- 設計禁忌:無 emoji、無 rainbow(地圖 pin palette 是唯一例外)。
- google_maps_flutter 在 widget test 無法真渲染 → 測 adapter 產出的 `Set<Marker>`/純邏輯,不找 GoogleMap widget tree。

## 前置說明:API key 阻塞

C1 程式與原生設定用 **placeholder** 完成;**真機/模擬器看到地圖圖磚需使用者提供 Maps SDK key**(填進 gitignored 本機檔)。C1 的**單元測試不需 key**(bitmap/adapter 純邏輯)。

## File Structure

- **Create** `lib/features/map/marker_bitmap.dart` — Canvas 畫彩色序號 pin → PNG bytes → `BitmapDescriptor`,以 `(argb, number, focused)` cache。
- **Rewrite** `lib/features/map/map_adapter.dart` — `FlutterMapCanvas`→`GoogleMapCanvas`(GoogleMap widget)、controller 包 `GoogleMapController` async gate、`TripMapMarker` 改持 `BitmapDescriptor`。
- **Modify** `lib/features/trip_detail/trip_map_screen.dart` — `_buildMap`/`_buildMarker` 用新 adapter + bitmap。
- **Modify** `lib/features/map/global_map_screen.dart` — 遷移到新 adapter(暫保留收藏顯示,C2 改行程總覽)。
- **Modify** `pubspec.yaml`、`ios/Runner/AppDelegate.swift`、`ios/Runner/Info.plist`、`ios/Podfile`、`ios/Runner.xcodeproj/project.pbxproj`(部署目標)、`android/app/src/main/AndroidManifest.xml`、`android/app/build.gradle.kts`、`.gitignore`。
- **Create** `ios/Flutter/Secrets.xcconfig.example`、更新 Android `local.properties` 說明。
- **Test** `test/features/map/marker_bitmap_test.dart`(新)、改寫 `test/features/map/map_adapter_test.dart`、`test/features/trip_detail/trip_map_screen_test.dart`、`test/features/map/global_map_screen_test.dart`。

---

### Task 1: 彩色序號 pin bitmap(key-independent,先做)

**Files:**
- Create: `lib/features/map/marker_bitmap.dart`
- Test: `test/features/map/marker_bitmap_test.dart`

**Interfaces:**
- Produces:
  - `Future<Uint8List> paintNumberedPinPng({required Color color, required int number, required double devicePixelRatio, bool focused = false, Color borderColor = Colors.white})` — 回傳 PNG bytes。
  - `class PinBitmapCache { Future<BitmapDescriptor> resolve({required Color color, required int number, required double devicePixelRatio, bool focused}); }` — 以 `(color.toARGB32(), number, focused)` 為 key 快取 `BitmapDescriptor`。

- [ ] **Step 1: 寫失敗測試**

```dart
// test/features/map/marker_bitmap_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/marker_bitmap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paintNumberedPinPng 產出非空 PNG(含 PNG 檔頭)', () async {
    final bytes = await paintNumberedPinPng(
      color: const Color(0xFFEF4444),
      number: 3,
      devicePixelRatio: 2,
    );
    expect(bytes, isNotEmpty);
    // PNG magic number 89 50 4E 47
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('focused pin 尺寸較大(bytes 不同)', () async {
    final idle = await paintNumberedPinPng(
      color: const Color(0xFF0EA5E9),
      number: 1,
      devicePixelRatio: 2,
    );
    final focused = await paintNumberedPinPng(
      color: const Color(0xFF0EA5E9),
      number: 1,
      devicePixelRatio: 2,
      focused: true,
    );
    expect(idle, isNot(equals(focused)));
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/features/map/marker_bitmap_test.dart`
Expected: FAIL(`marker_bitmap.dart` 不存在)

- [ ] **Step 3: 實作**

```dart
// lib/features/map/marker_bitmap.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 畫「彩色實心圓 + 白邊 + 置中白數字」pin,回傳 PNG bytes。
///
/// Google [Marker] 只吃 [BitmapDescriptor],不能放任意 Widget → 用 Canvas 畫成點陣圖。
/// 依 [devicePixelRatio] 放大繪製尺寸,避免 retina 上糊。
Future<Uint8List> paintNumberedPinPng({
  required Color color,
  required int number,
  required double devicePixelRatio,
  bool focused = false,
  Color borderColor = Colors.white,
}) async {
  final logical = focused ? 40.0 : 32.0;
  final size = logical * devicePixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  final border = 2.0 * devicePixelRatio;
  final radius = size / 2 - border / 2;

  canvas.drawCircle(center, radius, Paint()..color = color);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = border,
  );

  final painter = TextPainter(
    text: TextSpan(
      text: '$number',
      style: TextStyle(
        color: borderColor,
        fontSize: 13 * devicePixelRatio,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );

  final image = await recorder.endRecording().toImage(
    size.ceil(),
    size.ceil(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// 以 (color, number, focused) 快取 [BitmapDescriptor],避免每 frame 重繪。
class PinBitmapCache {
  final Map<String, BitmapDescriptor> _cache = {};

  Future<BitmapDescriptor> resolve({
    required Color color,
    required int number,
    required double devicePixelRatio,
    bool focused = false,
  }) async {
    final key = '${color.toARGB32()}-$number-$focused';
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = await paintNumberedPinPng(
      color: color,
      number: number,
      devicePixelRatio: devicePixelRatio,
      focused: focused,
    );
    final descriptor = BitmapDescriptor.bytes(bytes);
    _cache[key] = descriptor;
    return descriptor;
  }
}
```

**驗證點**:`BitmapDescriptor.bytes` 為 2.x 新 API;若版本較舊改 `BitmapDescriptor.fromBytes(bytes)`。`Color.toARGB32()` 為新 API;舊版用 `color.value`。

- [ ] **Step 4-6: 綠 → analyze → commit**

Run: `flutter test test/features/map/marker_bitmap_test.dart` → PASS
Run: `flutter analyze lib/features/map/marker_bitmap.dart` → 零問題
（此 task 需先完成 Task 4 的 `google_maps_flutter` 依賴才能 import;若先做本 task,暫時只 import `dart:ui`、把 `PinBitmapCache`/`BitmapDescriptor` 部分留到 Task 4 後補。**建議順序:Task 4 pubspec 先加依賴 → 回來完成本 task**。）

```bash
git add lib/features/map/marker_bitmap.dart test/features/map/marker_bitmap_test.dart
git commit -m "feat(map): 彩色序號 pin bitmap 產生器(Canvas→PNG→BitmapDescriptor + cache)"
```

---

### Task 2: pubspec 依賴切換

**Files:** Modify `pubspec.yaml`

- [ ] 加 `google_maps_flutter: ^2.12.1`;移除 `flutter_map: ^8.3.0`、`latlong2: ^0.9.1`(僅 map_adapter 用)。
- [ ] `flutter pub get`。
- [ ] 此時 `map_adapter.dart` 及 3 個 map 測試會編譯失敗(flutter_map 消失)—— 屬預期,由 Task 3/5/6/7 修復。先確認 `flutter pub get` 成功、依賴樹無衝突。
- [ ] commit:`chore(map): 依賴改用 google_maps_flutter`(此 commit 後暫時 build 破,連同 Task 3 一起綠)。

---

### Task 3: 原生設定 + API key plumbing(placeholder)

**Files:** `ios/Podfile`、`ios/Runner.xcodeproj/project.pbxproj`、`ios/Runner/AppDelegate.swift`、`ios/Flutter/Secrets.xcconfig`(gitignored)+`.example`、`android/app/src/main/AndroidManifest.xml`、`android/app/build.gradle.kts`、`android/local.properties`、`.gitignore`。

- [ ] **iOS 部署目標 13→15**:`ios/Podfile` 解註 `platform :ios, '15.0'`;`project.pbxproj` 三處 `IPHONEOS_DEPLOYMENT_TARGET = 13.0` → `15.0`。
- [ ] **iOS key**:建 `ios/Flutter/Secrets.xcconfig`(內容 `MAPS_API_KEY=` 空值)+ `Secrets.xcconfig.example`(說明);`ios/Flutter/Debug.xcconfig`/`Release.xcconfig` 頂部 `#include "Secrets.xcconfig"`;`Info.plist` 加 `<key>MAPS_API_KEY</key><string>$(MAPS_API_KEY)</string>`。
- [ ] **AppDelegate**:`import GoogleMaps`;`didFinishLaunchingWithOptions` 內、`super` 前:
  ```swift
  if let key = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String, !key.isEmpty {
    GMSServices.provideAPIKey(key)
  }
  ```
- [ ] **Android key**:`local.properties` 加 `MAPS_API_KEY=`(gitignored 已含);`build.gradle.kts` 讀 `local.properties` 的 `MAPS_API_KEY` → `manifestPlaceholders["MAPS_API_KEY"] = ...`;`AndroidManifest.xml` `<application>` 內加 `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}"/>`。
- [ ] `.gitignore` 確認排除 `ios/Flutter/Secrets.xcconfig`(`local.properties` 已排除)。
- [ ] commit:`chore(map): iOS 15 + Google Maps 原生設定 + API key plumbing(placeholder)`。

**驗證點**:CocoaPods 需 `cd ios && pod install`(GoogleMaps pod);Android 需 `flutter.minSdkVersion >= 21`(讀 build.gradle.kts 確認)。無 key 時地圖顯示空白/灰,不崩。

---

### Task 4: `map_adapter.dart` 重寫 → GoogleMap

**Files:** Rewrite `lib/features/map/map_adapter.dart`;Test 改寫 `test/features/map/map_adapter_test.dart`

**Interfaces:**
- Produces(保留名稱以減少呼叫端改動):
  - `class TripMapPoint`(不變,`toLatLng()` 回 google `LatLng`)
  - `class TripMapMarker { final TripMapPoint point; final BitmapDescriptor icon; final String markerId; final VoidCallback? onTap; }`(child Widget → BitmapDescriptor)
  - `class TripMapRoute { final List<TripMapPoint> points; final Color color; final double width; final bool dashed; }`(保留給 C2)
  - `class GoogleTripMapController { Future<void> fitPoints(...); Future<void> move(...); 內含 ready gate; }`
  - `class GoogleMapCanvas extends StatefulWidget`(取代 `FlutterMapCanvas`):`GoogleMap` + `onMapCreated` 取 controller、`markers`/`polylines`/`onTap`/`mapType`。

- [ ] 依 adapter 契約寫測試(斷言值物件與 marker/polyline 集合組法,不渲染 GoogleMap):
  - `TripMapMarker` 建構、`toLatLng` 回 LatLng、controller ready gate(未 ready 時 fit/move 不 throw)。
- [ ] 重寫實作(對照原檔行為;`initialCameraPosition` + `onMapCreated` 後 `animateCamera(newLatLngBounds)`,單點用 `newLatLngZoom`;tile preset → `mapType`)。移除 flutter_map/latlong2 import。
- [ ] analyze + test 綠 → commit。

---

### Task 5: 遷移 trip_map_screen

**Files:** Modify `lib/features/trip_detail/trip_map_screen.dart`;Test 改寫 `test/features/trip_detail/trip_map_screen_test.dart`

- [ ] `_buildMap` 用 `GoogleMapCanvas`;`_buildMarker` 改用 `PinBitmapCache.resolve`(async → markers 於 bitmap 備妥後 `setState`;initial 空集合)。移除 `tileProvider` 測試注入點(Google 原生出圖,無 TileProvider)。
- [ ] fit/focus 改走新 controller async gate。
- [ ] 測試改斷 pin 萃取邏輯(`_extractDayPins`/pinNumber/色盤)+ day tab / entry card / 空狀態(普通 widget),不找 GoogleMap。
- [ ] analyze + test 綠 → commit。

---

### Task 6: 遷移 global_map_screen(暫保留收藏)

**Files:** Modify `lib/features/map/global_map_screen.dart`;Test 改寫 `test/features/map/global_map_screen_test.dart`

- [ ] 讀現況(收藏 POI marker + `_SelectedCard`),把 `FlutterMapCanvas`→`GoogleMapCanvas`、marker Widget→bitmap、Widget 手勢→`Marker.onTap`。**功能暫不變**(C2 才改行程總覽)。
- [ ] 測試改斷 marker 集合/`_SelectedCard`/空狀態。
- [ ] analyze + test 綠 → commit。

---

### Task 7: 全案回歸

- [ ] `flutter analyze`(全)零問題;`flutter test`(全)綠。
- [ ] 記錄「地圖圖磚渲染待 API key + 真機/模擬器 build 驗證」為 C1 已知未驗點(非 bug)。

## Self-Review

**Spec coverage(對 spec §7 C1):** SDK 依賴切換 T2、iOS15+原生+key plumbing T3、adapter 重寫 T4、bitmap marker T1、兩畫面遷移 T5/T6、測試改寫 T4-6。polyline/marker 狀態/色盤/`/map` 行程總覽 = C2(不在本計畫)✅。

**Placeholder scan:** 無 vague placeholder;「驗證點」為對 SDK 版本 API / CocoaPods / minSdk 的具體執行時檢查。

**Type consistency:** `paintNumberedPinPng(...)`、`PinBitmapCache.resolve(...)`、`TripMapMarker{point,icon,markerId,onTap}`、`GoogleMapCanvas`、`GoogleTripMapController` 於各 task 一致。

**執行順序建議:** Task 2(pubspec)→ Task 1(bitmap,需 google_maps_flutter import)→ Task 3(原生)→ Task 4(adapter)→ Task 5/6(畫面)→ Task 7(回歸)。
