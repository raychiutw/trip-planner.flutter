# 導航與路由參考(`lib/app/router.dart`)

路由用 go_router 17 的 `StatefulShellRoute.indexedStack`:5 個 tab 各自保留 navigation stack(切 tab 再切回來,原本逛到哪還在哪)。router 本身是 riverpod provider(`appRouterProvider`),認證 redirect 直接讀 `authStateProvider`。

## 路由表

| 路徑 | 畫面 | 位置 |
|---|---|---|
| `/login` | `LoginScreen` | **shell 外**(無底部導航) |
| `/signup?invitation=...` | `SignupScreen` | **shell 外**；公開註冊,可帶共編 invitation token |
| `/signup/check-email?email=...` | `EmailVerifyPendingScreen` | **shell 外**；查看信箱與重寄驗證信 |
| `/login/forgot` | `ForgotPasswordScreen` | **shell 外**；忘記密碼 generic reset request |
| `/auth/password/reset?token=...` | `ResetPasswordScreen` | **shell 外**；重設密碼 |
| `/auth/verify-email?token=...` | `VerifyEmailScreen` | **shell 外**；按鈕觸發 email verification POST |
| `/invite?token=...` | `InviteScreen` | **shell 外**；公開邀請預覽,未登入可進入 |
| `/chat` | `ChatScreen` | tab 1；AI request queue 第一波 |
| `/trips` | `TripsListScreen` | tab 2(**initialLocation**)；行程清單分類/搜尋/排序、JSON 匯入/匯出、分享連結管理與卡片 action menu |
| `/trips/new` | `TripFormScreen.create` | tab 2 子路由；建立行程基本資料 |
| `/trips/:tripId?focus=<entryId>` | `TripTimelineScreen` | tab 2 子路由；timeline + travel segments edit + AppBar 行程切換與 overflow 編輯/AI 健檢/共編/分享；`focus` query 會初載捲到指定 entry |
| `/trips/:tripId/edit` | `TripFormScreen.edit` | tab 2 孫路由；編輯行程基本資料與行程天數管理 |
| `/trips/:tripId/map` | `TripMapScreen` | tab 2 孫路由 |
| `/trips/:tripId/stop/:entryId/map` | `TripMapScreen` | tab 2 孫路由；初載切到 entry 所在 day 並聚焦 pin |
| `/trips/:tripId/notes` | `TripNotesScreen` | tab 2 孫路由；5 區 notes CRUD + 行前須知/緊急聯絡 AI generate |
| `/trips/:tripId/health` | `TripHealthScreen` | tab 2 孫路由；AI health-check report、severity 分組與 pending polling |
| `/trips/:tripId/collab` | `CollabScreen` | tab 2 孫路由；成員/待邀請、新增/撤回 pending invitation、非 owner 成員 role update/remove |
| `/trips/:tripId/add-entry?day=N&tab=custom` | `AddEntryScreen` | tab 2 孫路由；新增景點 search/favorites/custom slice |
| `/trips/:tripId/add-stop?day=N&tab=custom` | `AddEntryScreen` | tab 2 孫路由；相容入口 |
| `/trips/:tripId/add-custom-stop?day=N` | `AddEntryScreen` | tab 2 孫路由；自訂地圖座標入口 |
| `/trips/:tripId/stop/:entryId/edit` | `EditEntryScreen` | tab 2 孫路由；時間/描述/刪除 slice |
| `/trips/:tripId/stop/:entryId/change-poi?mode=alternate` | `ChangePoiScreen` | tab 2 孫路由；預設置換主景點,`mode=alternate` 加備選 |
| `/trips/:tripId/stop/:entryId/copy` | `EntryActionScreen` | tab 2 孫路由；跨日複製 entry |
| `/trips/:tripId/stop/:entryId/move` | `EntryActionScreen` | tab 2 孫路由；跨日移動 entry |
| `/map` | `GlobalMapScreen` | tab 3；行程地圖 resolver 第一波 |
| `/favorites` | `FavoritesScreen` | tab 4 |
| `/favorites/:favoriteId/add-to-trip` | `AddPoiFavoriteToTripScreen` | tab 4 子路由 |
| `/explore` | `ExploreScreen` | tab 4 secondary route |
| `/add-to-trip?place_id=...` | `AddPoiFavoriteToTripScreen` | tab 4 secondary route；Explore direct-mode |
| `/account` | `AccountScreen` | tab 5；profile、displayName inline 編輯、統計與登出 |
| `/account/appearance` | `AppearanceSettingsScreen` | tab 5 子路由；切換 ThemeMode |
| `/account/notifications` | `NotificationSettingsScreen` | tab 5 子路由；本機通知偏好 |
| `/account/sessions` | `AccountSessionsScreen` | tab 5 子路由；登入裝置清單、單一登出與登出其他裝置 |
| `/settings/appearance` | `AppearanceSettingsScreen` | tab 5 alias |
| `/settings/notifications` | `NotificationSettingsScreen` | tab 5 alias |
| `/settings/sessions` | `AccountSessionsScreen` | tab 5 alias |

shell 外殼是 `AppShell`(`lib/features/shell/app_shell.dart`):Material 3 `NavigationBar`,`onDestinationSelected` → `navigationShell.goBranch(index)`。

## 認證 redirect 規則

```dart
redirect: (context, state) {
  final authState = ref.read(authStateProvider);
  if (authState.isLoading) return null;   // 認證狀態未解析 → 不跳轉,避免閃跳

  final isLoggedIn = authState.value != null;
  final isOnLogin = state.matchedLocation == '/login';
  final isPublicRoute = _publicShellOutsideRoutes.contains(state.matchedLocation);
  if (!isLoggedIn && !isPublicRoute) return '/login';
  if (isLoggedIn && isOnLogin) return '/trips';
  return null;
}
```

四條規則:

1. **認證狀態 loading 時不 redirect** — app 啟動瞬間 `currentUser()` 還在查,先停在原地,避免「閃進 login 又跳走」。
2. 未登入 + 不在公開 shell 外 route → 踢去 `/login`。
3. 未登入可留在 `/invite` 看公開邀請預覽,也可走 signup/forgot/reset/verify auth 補齊流程；真正接受邀請仍需登入且 email 相符。
4. 已登入 + 在 `/login` → 送去 `/trips`(登入成功後的跳轉就是靠這條,`LoginScreen` 自己不導航)。

公開 shell 外 routes 目前是:`/login`、`/invite`、`/signup`、`/signup/check-email`、`/login/forgot`、`/auth/password/reset`、`/auth/verify-email`。

## auth 變化 → redirect 重算的橋接

go_router 的 redirect 只在導航事件時執行;登入/登出改變的是 riverpod state,不會自動觸發。橋接做法:

```dart
final authChangeNotifier = ValueNotifier<int>(0);
ref.listen(authStateProvider, (previous, next) {
  authChangeNotifier.value++;            // 任何 auth 變化 → 計數 +1
});
// GoRouter(refreshListenable: authChangeNotifier, ...)
```

`refreshListenable` 一收到通知就重跑 redirect。所以登入成功(`AsyncData(user)`)自動離開 `/login`;登出(`AsyncData(null)`)自動踢回 `/login`。

## 生命週期

provider 內建立的 `ValueNotifier` 與 `GoRouter` 都掛 `ref.onDispose` 釋放,測試裡反覆建立 container 不會洩漏。

## 相關文件

- [API 層參考 — authStateProvider](reference-api.md#riverpod-providersprovidersdart) — redirect 依賴的認證狀態
- [架構說明](explanation-architecture.md) — 為什麼選 StatefulShellRoute
- [How to 新增畫面](howto-add-screen.md) — 在路由表掛新頁的步驟
