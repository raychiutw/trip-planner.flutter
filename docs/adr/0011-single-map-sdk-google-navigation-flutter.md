---
status: accepted
---

# 地圖採用 google_navigation_flutter 的 map-only 視圖，不保留第二套 Google Maps SDK

行程地圖與總覽地圖原本建在 `google_maps_flutter` 上。要讓原生 Google POI 可點（點路上那家店，把它帶進底部 accessory），以及往後要能走導航語意，路徑落在 `google_navigation_flutter` 這一側 —— `onPoiClicked` 是該套件的 API，現在就用在 `lib/features/map/map_canvas_mobile.dart:115`。

決定是**只留一套地圖 SDK**：`google_navigation_flutter ^0.10.0`（`pubspec.yaml:60`），用它的 map-only 視圖 `GoogleMapsMapView`（`map_canvas_mobile.dart:101`）畫一般地圖，不初始化任何導航 session，也不再併存 `google_maps_flutter`。套件型別被關在 `map_canvas_mobile.dart` 一個檔案裡，畫面層只看得到 `map_adapter.dart` 的 `TripMapPoint` / `TripMapMarker` / `GoogleMapPoiSelection` 這類 app 自有型別。

關鍵推論是這句：**只要 navigation SDK 進到 app 裡，平台底線就已經被抬高了**（Android minSdk 24、iOS 16）。這條線是原生 SDK 強制的，不會因為我們額外再留一套舊套件而降回去。所以「保留第二套」買不到任何相容性，只買到第二份要維護的橋接程式碼。既然代價已經付了，就付一次。

## Considered Options

**保留 `google_maps_flutter` 做一般地圖、只在導航時切到 navigation SDK** —— 直覺上這是最保守的做法：常用路徑不動，只有需要導航時才換引擎。但它換不到它看起來該換到的東西。平台底線由 app 裡「存在」navigation SDK 決定，不是由「正在用」決定 —— 一旦 podspec 與 Gradle 依賴進來，minSdk 24 / iOS 16 就已經生效，舊套件留著也救不回 API 23 或 iOS 15 的裝置。付出的則是兩套實作：marker 圖示註冊、route 樣式、cluster、相機與 padding、POI 事件語意，全都要在兩條路徑上各寫一次、各測一次；而且切換引擎等於重建 platform view，玻璃疊層的手勢與 zoom 13 的初始狀態要在切換點再對一次。用一份不會兌現的相容性，換一份確定要付的維護成本。

**兩套永久併存（一般地圖走舊套件、導航走新套件，不設移除期限）** —— 同一個問題再加上時間。這個專案的地圖行為有一批必須逐項守住的細節：編號 marker（時間軸上的停留點）、route 樣式、12 個以上 marker 要 cluster、預設與 Day/POI 切換一律 zoom 13、地圖明暗跟隨 App 外觀。兩套併存代表每一項都有兩個實作可能各自漂移，回歸測試要跑兩遍，而任何一次套件升級都要對兩邊做相容性判斷。更實際的問題是所有權會糊掉：出問題時第一個要回答的是「這畫面現在跑在哪一套上」，而這正是我們花了一個檔案界線去消滅的問題。原生層的兩套 Google Maps SDK 是否能在同一個 build 裡穩定共存，本身也還是未驗證的假設 —— 不驗證就併存，等於把風險留到發版當天。

## Consequences

- **平台底線被抬高，而且很難降回去。** Android `minSdk = 24`（`android/app/build.gradle.kts:60`）、iOS 16（`ios/Podfile:1`，以及 `ios/Runner.xcodeproj/project.pbxproj` 六處 `IPHONEOS_DEPLOYMENT_TARGET = 16.0`）。連帶被綁上的還有 AGP 8.13.2 與 Kotlin 2.3.0（`android/settings.gradle.kts:22-23`）、以及 core library desugaring（`build.gradle.kts:50` 與 `:124` 的 `desugar_jdk_libs_nio:2.1.5`）。這些值有守門測試盯著（`test/features/map/map_platform_config_test.dart:17-28`），不會被誰順手改掉。要降回去不是改個數字，是整個換掉地圖引擎，連 cluster、overlay、POI 三個自寫檔案一起重寫。**評估任何新裝置支援需求時，這條線是既成事實，不是可議的參數。**

- **web 沒有內嵌地圖。** 條件匯入把 web 導到 `map_canvas_web.dart`（`map_adapter.dart:5-7`），那裡不 import 任何 Google 地圖套件，只給一段「請使用 Google 地圖查看完整地圖」與一顆「在 Google 地圖開啟」（`map_canvas_web.dart:64-69`）。這是刻意的取捨，不是還沒做完 —— 為了 web 再拉一套 SDK 進來，就回到上面被拒的那條路。

- **套件只能從一個檔案 import，且由測試強制。** `test/ui/shared_ui_usage_test.dart:92` 直接斷言 owner list **恰好等於** `['lib/features/map/map_canvas_mobile.dart']`；同一個測試（`:85-91`）也把 `pubspec.yaml` 重新出現 `google_maps_flutter:` 當成違規，`:131-141` 再擋 `GoogleTripMapController` 這類舊符號復活。所以「在別的檔案 import 一下比較快」不是走捷徑，是紅燈。要在 map 之外用到套件能力，正確作法是把它翻譯成 `map_adapter.dart` 的 app 自有型別。

- **clustering 變成我們自己的程式碼。** 插件的 `ClusterManager` 沒有對應品，改由 `lib/features/map/trip_map_cluster_projector.dart` 以純 Dart 的 Web Mercator 網格實作。好處是不外洩插件型別、可寫純 VM 測試；代價是 cluster 的正確性從此由我們負責，套件升級不會順便修它。

- **權限維持 when-in-use，沒有背景導航。** `ios/Runner/Info.plist:35-38` 只有前景用途字串，沒有 `UIBackgroundModes`。這是 map-only 設計的必然結果 —— 若日後真的要 turn-by-turn，權限與背景模式是另一個獨立決定，不會因為 SDK 已經在專案裡就自動成立。
