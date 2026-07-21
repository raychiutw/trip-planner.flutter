# How to 新增畫面

把一個新畫面掛進 5-tab shell：建立 screen widget、掛路由、寫 widget test。五個 root branch 是聊天、行程、地圖、收藏與帳號，各自保留 navigation stack。以下以「把收藏 tab 從 placeholder 換成真畫面」為例。

## 前置條件

- 資料來源已就緒(repository 方法 + provider,沒有的話先走 [How to 新增 API endpoint](howto-add-endpoint.md))
- 了解[路由表](reference-navigation.md#路由表)現況

## 步驟

1. **先寫 widget test(紅)** — `test/features/favorites/favorites_screen_test.dart`,用 `ProviderScope` override 注入假資料(寫法詳見 [How to 用 provider override 寫測試](howto-test-with-providers.md)):

   ```dart
   testWidgets('顯示收藏清單', (tester) async {
     await tester.pumpWidget(
       ProviderScope(
         overrides: [
           tripRepositoryProvider.overrideWithValue(fakeTripRepository),
         ],
         child: const MaterialApp(home: FavoritesScreen()),
       ),
     );
     await tester.pumpAndSettle();
     expect(find.text('清水寺'), findsOneWidget);
   });
   ```

2. **建 screen(綠)** — `lib/features/favorites/favorites_screen.dart`。慣例:

   - `ConsumerWidget`(無本地 state)或 `ConsumerStatefulWidget`(有表單/控制器)
   - async 資料用 `ref.watch(xxxProvider).when(data:..., error:..., loading:...)` 三態都要處理(參考 `trips_list_screen.dart` 的 `_ErrorState` + retry 模式)
   - 取色守則見 [Theme 參考](reference-theme.md#取色守則):語意色走 `colorScheme`、tone 走 `TpTones`、間距用 `TpSpacing`
   - 依內容角色用 `AppAdaptiveContent` 限寬：表單 `720`、對話/搜尋 `860`、feed `920`；手機自然維持全寬
   - 確認、action sheet、搜尋與短暫通知優先重用 `lib/app/adaptive.dart`，不要在 feature 內重寫平台判斷
   - 頁級載入用 `AppListLoadingSkeleton` 或 `AppMapLoadingSkeleton` 保留版型；不要只留空白或在中央放單一 spinner
   - 成功/低風險狀態用 `showAppNotice`；錯誤用 `showAppError`，可恢復時必須傳 `onRetry`
   - 不指定自訂 font family；沿用系統字、Theme 的 HIG 字階與 Dynamic Type。互動目標不得小於 `TpSpacing.tapMin` (`44`)
   - 檔頭加 `///` library doc 說明畫面職責(本 repo 慣例)

3. **掛路由** — `lib/app/router.dart`:

   - **換掉 placeholder tab**:把該 branch 的 `PlaceholderScreen` builder 換成新 screen
   - **加子頁**(如 `/favorites/:poiId`):在該 branch 的 `GoRoute` 下加 `routes: [...]`,path 參數從 `state.pathParameters` 取(參考 `/trips/:tripId` 的寫法)
   - **shell 外整頁**(如 login 這種無底部導航的頁):加在 `routes` 頂層、`StatefulShellRoute` 外面

4. **(若新頁需要登入保護)確認 redirect** — shell 內的頁自動受 [redirect 規則](reference-navigation.md#認證-redirect-規則)保護,不用額外寫;shell 外的新頁若也要擋未登入,redirect 條件要跟著調。

5. **補測試** — `test/app/router_test.dart` 加導航斷言(新路徑可達、未登入被踢去 `/login`)。若畫面有平台或寬度分支，至少驗證 `390×844` Android、`390×844` iOS 與 `1024×768` 寬版；有 icon-only action 時驗證 tooltip/semantics。

6. **重構 + 全綠**。

## 驗證

```bash
flutter analyze && flutter test
flutter run    # 實機/模擬器確認視覺(注意:連 prod API,用測試帳號)
```

## 疑難排解

| 症狀 | 原因與解法 |
|---|---|
| 新 tab 點了沒反應 | `AppShell` 的 `NavigationBar` destinations 與 branches 是按 index 對應的 — 兩邊順序要一致 |
| iOS 顯示 Android 樣式的確認框/搜尋列 | feature 自己建了 Material 元件 — 改用 `showAppConfirm` / `showAppActionSheet` / `AppSearchField` |
| 寬螢幕內容撐滿、難以閱讀 | 畫面沒包 `AppAdaptiveContent`，依內容角色選 `AppContentWidth` |
| 錯誤一閃就消失 | 用了 `showAppNotice` 或 SnackBar — 真錯誤改用 `showAppError`，並提供 retry |
| 畫面一進來就被踢去 `/login` | widget test 沒 override `authStateProvider`,啟動時 `currentUser()` 走真 `SecureSessionStore` 失敗 → 視同未登入 |
| `No ProviderScope found` | 測試的 `pumpWidget` 最外層忘了包 `ProviderScope` |
| tone 色在 dark mode 不對 | 直接引用了 `TpColorsLight` 常數 — 改走 `Theme.of(context).extension<TpTones>()!` |

## 相關文件

- [導航參考](reference-navigation.md) — 路由表與 redirect 細節
- [設計系統參考](reference-theme.md) — token、自適應元件與固定規格
- [自適應 UI 設計理由](explanation-adaptive-ui.md) — Apple Music/HIG 對標與取捨
- [How to 用 provider override 寫測試](howto-test-with-providers.md)
