# 設定子頁 設計 + 計畫

> P2。帳號設定子頁。分支 `feat/settings-subpages`。後端固定。
> MVP:外觀(主題,client-only + 持久化)+ 個人資料編輯(displayName)。Sessions/connected-apps/通知 延後。

## 後端契約
- `PATCH /api/account/profile` body `{displayName: string|null}` → 更新 `display_name` → 回 `{id,email,emailVerified,displayName,avatarUrl,createdAt}`。
- 主題為純 client(無後端);AccountScreen 現有「外觀/通知」為 ComingSoon placeholder。

## Task 1：主題(外觀)
- 新 `lib/api/settings_store.dart`:`SettingsStore`(read(key)/write(key,val))+ `SecureSettingsStore`(flutter_secure_storage)+ `InMemorySettingsStore`。`settingsStoreProvider`(api/providers.dart)。
- 新 `lib/features/account/settings/theme_mode_controller.dart`:純函式 `themeModeToString`/`parseThemeMode`(`system|light|dark`);`ThemeModeController extends Notifier<ThemeMode>`(build 回 system 並 async 載入;`setMode` 設 state + 寫 store);`themeModeProvider`。
- `lib/main.dart`:`themeMode: ref.watch(themeModeProvider)`(MaterialApp.router 變 Consumer 已是)。
- 新 `lib/features/account/settings/appearance_screen.dart`:三選一(跟隨系統/淺色/深色)`RadioListTile`,點選 → setMode。route top-level `/settings/appearance`。
- `account_screen.dart`:外觀 row 由 ComingSoon 換成可點(→ push `/settings/appearance`),顯示目前模式。
- test:parse/toString round-trip;controller(setMode 寫 store + 載入套用);appearance screen(點深色 → state=dark)。
- commit。

## Task 2：個人資料編輯
- `lib/api/trip_repository.dart`:`updateProfile({String? displayName})` → PATCH `/account/profile` body `{displayName: ?...}`(null 表清空也送 → 用明確參數;MVP 只送字串)。
- 新 `lib/features/account/settings/profile_edit_screen.dart`:`displayName` TextField(初值來自 authState user)+ 儲存鈕 → updateProfile → invalidate authStateProvider → pop。route `/settings/profile`。
- `account_screen.dart`:加「個人資料」row → push `/settings/profile`。
- test:repo updateProfile(PATCH body);screen(改名 + 儲存 → verify updateProfile + pop)。
- commit。

## 收尾
analyze 0 + test 綠;dart format;CHANGELOG/TODOS;push + PR(base master)。

## 自審
主題純 client + 持久化(SettingsStore,免新 dep,沿用 secure storage);profile 走既有 PATCH;沿用 route top-level + account row 入口;純函式先測。
