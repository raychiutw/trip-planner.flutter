# 導航與路由參考(`lib/app/router.dart`)

路由用 go_router 17 的 `StatefulShellRoute.indexedStack`:5 個 tab 各自保留 navigation stack(切 tab 再切回來,原本逛到哪還在哪)。router 本身是 riverpod provider(`appRouterProvider`),認證 redirect 直接讀 `authStateProvider`。

## 路由表

| 路徑 | 畫面 | 位置 |
|---|---|---|
| `/login` | `LoginScreen` | **shell 外**(無底部導航) |
| `/signup` | `SignupScreen` | shell 外公開 route |
| `/signup/check-email` | `EmailVerifyPendingScreen` | shell 外公開 route |
| `/login/forgot` | `ForgotPasswordScreen` | shell 外公開 route |
| `/auth/password/reset` | `ResetPasswordScreen` | shell 外公開 route |
| `/auth/verify-email` | `VerifyEmailScreen` | shell 外公開 route |
| `/chat` | `ChatScreen` | tab 1 |
| `/trips` | `TripsListScreen` | tab 2(**initialLocation**) |
| `/trips/:tripId` | `TripTimelineScreen` | tab 2 子路由 |
| `/trips/:tripId/map` | `TripMapScreen` | tab 2 孫路由 |
| `/trips/:tripId/notes` | `TripNotesScreen` | tab 2 孫路由 |
| `/trips/:tripId/print` | `TripPrintScreen` | tab 2 孫路由 |
| `/trips/:tripId/health` | `TripHealthScreen` | tab 2 孫路由 |
| `/trips/:tripId/entries/new?day=N&mode=search|favorites|custom&region=沖繩` | `EntryAddRouteScreen` | tab 2 孫路由(搜尋 POI / 收藏景點 / 自訂停留點；搜尋模式可帶 region,加入前 resolve Place Details 產生營業/消費/地址備註,選取後可覆寫單筆 POI 分類；自訂模式可設定分類與座標；搜尋/收藏可分類篩選與多選批次加入) |
| `/trips/:tripId/entries/:eid/edit` | `EntryEditRouteScreen` | tab 2 孫路由 |
| `/trips/:tripId/entries/:eid/copy` | `EntryActionRouteScreen` | tab 2 孫路由 |
| `/trips/:tripId/entries/:eid/move` | `EntryActionRouteScreen` | tab 2 孫路由 |
| `/trips/:tripId/entries/:eid/pois` | `EntryPoiScreen` | tab 2 孫路由(搜尋置換正選 POI、加入/移除/設為正選備選、編輯 per-POI 備註/分類/訂位) |
| `/map` | `GlobalMapScreen` | tab 3 |
| `/favorites` | `FavoritesScreen` | tab 4(收藏清單) |
| `/favorites/explore` | `ExploreScreen` | tab 4 子路由(探索) |
| `/favorites/add-to-trip` | `AddToTripScreen` | tab 4 子路由(加入行程,extra `AddToTripArgs`) |
| `/account` | `AccountScreen` | tab 5 |
| `/settings/profile` | `ProfileEditScreen` | shell 外設定頁 |
| `/settings/appearance` | `AppearanceScreen` | shell 外設定頁 |
| `/settings/notifications` | `NotificationsScreen` | shell 外設定頁 |
| `/account/notifications` | `NotificationsScreen` | shell 外 web 相容 alias |
| `/settings/sessions` | `AccountSessionsScreen` | shell 外設定頁 |
| `/settings/connected-apps` | `ConnectedAppsScreen` | shell 外設定頁 |
| `/settings/developer-apps` | `DeveloperAppsScreen` | shell 外設定頁 |
| `/settings/developer-apps/new` | `DeveloperAppNewScreen` | shell 外設定頁 |
| `/developer/apps` | `DeveloperAppsScreen` | shell 外 web 相容 alias |
| `/developer/apps/new` | `DeveloperAppNewScreen` | shell 外 web 相容 alias |
| `/oauth/consent` | `OAuthConsentScreen` | shell 外公開 route |
| `/s/:token` | `PublicShareScreen` | shell 外公開 route |

Web 相容 alias：`/trips?selected=:tripId&focus=:entryId` 會導到 `/trips/:tripId?entry=:entryId`；`/trip/:tripId/notes|print|health|map` 會導到 `/trips/:tripId/*`；`/trip/:tripId/add-entry|add-stop?day=N` 會導到搜尋 POI 新增模式,搜尋模式會保留 `region` query 作為初始地區,`/trip/:tripId/add-stop?tab=favorites&day=N` 會導到收藏景點新增模式,`/trip/:tripId/add-custom-stop?day=N` 會導到自訂停留點新增模式；`/trip/:tripId/stop/:entryId` 會導到 `/trips/:tripId?entry=:entryId`,並初始捲動與標示該停留點；`/trip/:tripId/stop/:entryId/map` 會導到 `/trips/:tripId/map?entry=:entryId`,並初始顯示該停留點所在日；`/trip/:tripId/stop/:entryId/edit|copy|move` 會導到停留點操作頁,`/trip/:tripId/stop/:entryId/change-poi` 會導到可搜尋置換正選 POI 的地點管理頁。

Legacy redirect：`/admin`、`/admin/` 會導到 `/trips`，`/manage`、`/manage/` 會導到 `/chat`。

shell 外殼是 `AppShell`(`lib/features/shell/app_shell.dart`):Material 3 `NavigationBar`,`onDestinationSelected` → `navigationShell.goBranch(index)`。

## 認證 redirect 規則

```dart
redirect: (context, state) {
  final authState = ref.read(authStateProvider);
  if (authState.isLoading) return null;   // 認證狀態未解析 → 不跳轉,避免閃跳

  final isLoggedIn = authState.value != null;
  final isOnLogin = state.matchedLocation == '/login';
  final isPublicRoute = _isPublicShellOutsideRoute(state);
  if (!isLoggedIn && !isOnLogin && !isPublicRoute) {
    return _loginLocationWithRedirect(state);
  }
  if (isLoggedIn && isOnLogin) return _redirectAfterLogin(state);
  return null;
}
```

三條規則:

1. **認證狀態 loading 時不 redirect** — app 啟動瞬間 `currentUser()` 還在查,先停在原地,避免「閃進 login 又跳走」。
2. 未登入 + 不在 `/login` 或公開 route → 踢去 `/login`,並用安全站內 `redirect_after` 保留原路徑。
3. 未登入可進公開 route:`/s/:token`、`/oauth/consent`、`/invite`、signup / forgot password / email verify 系列 route。
4. 已登入 + 在 `/login` → 優先回到安全站內 `redirect_after`,否則送去 `/trips`(登入成功後的跳轉就是靠這條,`LoginScreen` 自己不導航)。

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
