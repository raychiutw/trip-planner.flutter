# 地圖可讀性測試字型

Roboto Regular／Bold 用於 `tp_map_controls_legibility_test.dart` 的實際文字渲染，避免 Ahem 方塊字造成誤判。這些檔案僅供測試，不加入 App assets。

來源為 Flutter 3.44.7 SDK 的 `bin/cache/artifacts/material_fonts/`，檔案未修改。隨附同目錄的 Apache 2.0 授權原文 `LICENSE.txt`。將字型固定於此，讓 Windows 與 Linux CI 不依賴 SDK 是否曾下載可選字型快取。
