# 導航與路由參考(`lib/app/router.dart`)

路由用 go_router 17 的 `StatefulShellRoute.indexedStack`:5 個 tab 各自保留 navigation stack(切 tab 再切回來,原本逛到哪還在哪)。router 本身是 riverpod provider(`appRouterProvider`),認證 redirect 直接讀 `authStateProvider`。

## 路由表

| 路徑 | 畫面 | 位置 |
|---|---|---|
| `/login` | `LoginScreen` | **shell 外**(無底部導航) |
| `/chat` | `PlaceholderScreen('聊天')` | tab 1(P1 待實作) |
| `/trips` | `TripsListScreen` | tab 2(**initialLocation**) |
| `/trips/:tripId` | `TripTimelineScreen` | tab 2 子路由 |
| `/trips/:tripId/map` | `TripMapScreen` | tab 2 孫路由 |
| `/trips/:tripId/notes` | `TripNotesScreen` | tab 2 孫路由 |
| `/map` | `PlaceholderScreen('全域地圖')` | tab 3(P1 待實作) |
| `/favorites` | `FavoritesScreen` | tab 4(收藏清單) |
| `/account` | `AccountScreen` | tab 5 |

shell 外殼是 `AppShell`(`lib/features/shell/app_shell.dart`):Material 3 `NavigationBar`,`onDestinationSelected` → `navigationShell.goBranch(index)`。

## 認證 redirect 規則

```dart
redirect: (context, state) {
  final authState = ref.read(authStateProvider);
  if (authState.isLoading) return null;   // 認證狀態未解析 → 不跳轉,避免閃跳

  final isLoggedIn = authState.value != null;
  final isOnLogin = state.matchedLocation == '/login';
  if (!isLoggedIn && !isOnLogin) return '/login';
  if (isLoggedIn && isOnLogin) return '/trips';
  return null;
}
```

三條規則:

1. **認證狀態 loading 時不 redirect** — app 啟動瞬間 `currentUser()` 還在查,先停在原地,避免「閃進 login 又跳走」。
2. 未登入 + 不在 `/login` → 踢去 `/login`。
3. 已登入 + 在 `/login` → 送去 `/trips`(登入成功後的跳轉就是靠這條,`LoginScreen` 自己不導航)。

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
