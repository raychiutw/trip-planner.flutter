# 開發者應用清單讀屏驗證

- 來源：#378；基底 `0b28e83634e3d5006ea2e3b4383fa19672625d53`。
- 結論：320×568、2× 字級的公開 widget seam 可找到長名稱應用列，且列有 tap action；但朗讀 label／hint 沒有說明它會進入「編輯」。缺陷另立 #405，#378 的實際 VoiceOver 驗證尚未完成。

## 重現

在 `DeveloperAppsScreen` 的 `tripRepositoryProvider` 替身回傳名稱「跨地區行程整合與資料同步測試應用程式」、五個 scope 的應用。測試取得 `developer-app-row-tp_long_app` 的 semantics：

```text
label: 跨地區行程整合與資料同步測試應用程式
       tp_long_app
       Confidential · https://example.com/oauth/callback
       待審核
hint:  （空字串）
tap action: true
```

暫時加入的公開 widget 測試命令：

```text
flutter test --no-pub test/features/account/developer_apps_screen_test.dart --plain-name '長應用名稱與多個 scopes 在窄螢幕大字級仍可辨識編輯入口'
Expected: contains '編輯'
Actual hint: ''
```

此 red 測試不併入驗證提交，供 #405 的 red→green 修正。程式碼的 `_DeveloperAppTile` 在 `onTap` 開啟 `DeveloperAppEditScreen`，目前只讓 `ListTile` 自動合併文字與 tap 語意，未提供動作 hint；測試沒有發現版面 overflow。`DeveloperAppsScreen` 仍在 Account 的既有路徑下，沒有新增 root tab。

## 尚待驗收

待 #405 修正後，用實際 VoiceOver 驗證長名稱與多 scopes 的朗讀順序、編輯動作名稱及進入／返回焦點。此文件只記錄 widget semantics，不宣稱已完成真機讀屏。
