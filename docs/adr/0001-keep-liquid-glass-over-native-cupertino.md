---
status: accepted
---

# 導覽 chrome 保留 liquid_glass_widgets,不改用原生 Cupertino 元件

App 要對齊 iOS 26 的 Liquid Glass 觀感,直覺作法是改用 Flutter 內建的 Cupertino 元件(`CupertinoNavigationBar`、`CupertinoTabBar`、`CupertinoContextMenu`)。實測後決定**不改**:整個導覽 chrome(浮動 header、固定 bar、選單、日期選擇器、root tab bar)繼續建在 `liquid_glass_widgets` 之上,只調整它的色彩與參數語意。

## Considered Options

**Flutter 內建 Cupertino 元件** —— Flutter 不是包 UIKit,所有 widget 都自己畫。`CupertinoNavigationBar` 的材質是 `BackdropFilter` + `ImageFilter.blur(sigma 10)`(`packages/flutter/lib/src/cupertino/nav_bar.dart`),平面毛玻璃,沒有折射與高光,觀感停在 iOS 7~17。Flutter 3.44.6 的 `packages/flutter/lib/src/` 對 Liquid Glass **零支援**(唯一命中 "glass" 的是 `icons.dart` 的圖示名稱)。換過去等於為了「用原生元件」而放棄玻璃。

**`native_liquid_glass`** —— 唯一能拿到真正系統 Liquid Glass 的途徑,以 `UiKitView` platform view 包真的 UIKit 元件。但 platform view 在 widget test 中不真渲染(本專案在 Google Maps 上已踩過),套件本身也載明「Flutter overlay 出現時會自動隱藏 glass view 以免穿透」;且 iOS-only、發布未滿一週、下載量約 1.5k、uploader 未驗證。拿它承載全 app 的導覽 chrome,等於讓最核心的 UI 變成不可測、又與 Flutter overlay 衝突。

**`liquid_glass_widgets`(選定)** —— GLSL shader 實作(`render.glsl` / `sdf.glsl` / `displacement_encoding.glsl`),自行計算折射位移,是 Flutter 生態中最接近 iOS 26 且**跨平台、可寫 widget test** 的方案。它另附 `GlassMenu` 與 `GlassMorphController`,已依 iOS 26 的 375ms spring 與液滴形變調校。

## Consequences

- 玻璃觀感的正確性無法靠 widget test 保證,只能真機目視 —— shader 折射與 dpr 和實際背景內容有關。涉及玻璃參數的變更要有真機證據。
- 本次的修正全部落在**與套件無關的語意層**(品牌色只當前景、表面走中性語意層、動作分組、拿掉重複導覽)。Flutter 官方預計 2026 下半年把 Cupertino 拆成獨立套件並依 Liquid Glass 規格重寫(flutter/flutter#170310),屆時可重新評估;這些語意修正在那之後依然適用,不會白做。
