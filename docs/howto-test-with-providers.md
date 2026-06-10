# How to 用 provider override 寫測試

不打真 API、不碰 secure storage,把假資料注入 riverpod provider 來測 model 以外的所有東西。本 repo 三層測試(models / api / screens)中,這篇涵蓋 api 與 screens 層的注入手法,範例全部取自 `test/` 現有寫法。

## 前置條件

- dev dependencies 已含 `mocktail`、`http_mock_adapter`(見 `pubspec.yaml`)
- 了解 [provider 依賴圖](explanation-architecture.md#provider-依賴圖) — override 哪個節點,下游就全部換掉

## 手法 1:override 資料 provider(最常用,widget test)

直接把 `FutureProvider` 換成回假資料的版本:

```dart
await tester.pumpWidget(ProviderScope(
  overrides: [
    myTripsProvider.overrideWith((ref) async => fakeTrips),
  ],
  child: buildRouterApp(),
));
await tester.pump();   // FutureProvider 解析需要一個 pump
```

要測 error 狀態就丟例外:

```dart
myTripsProvider.overrideWith((ref) async => throw const ApiError(
  status: 500, code: 'HTTP_500', message: 'HTTP 500',
)),
```

> 注意:flutter_riverpod 3.x 未匯出 `Override` 型別,overrides 直接在 `ProviderScope` 建構處以 list literal 傳入,不要宣告 `List<Override>` 變數。

## 手法 2:override repository(mocktail)

畫面會呼叫 repository 的 mutation(如刪除行程)時,mock 整個 repository:

```dart
class MockTripRepository extends Mock implements TripRepository {}

final mockTripRepository = MockTripRepository();
when(() => mockTripRepository.fetchMyTrips()).thenAnswer((_) async => fakeTrips);
when(() => mockTripRepository.deleteTrip(any())).thenAnswer((_) async {});

ProviderScope(
  overrides: [
    tripRepositoryProvider.overrideWithValue(mockTripRepository),
  ],
  child: ...,
)
```

之後可驗證互動:`verify(() => mockTripRepository.deleteTrip('okinawa-trip-2026')).called(1);`

## 手法 3:導航探針(假 GoRouter)

測「點卡片會導去詳情」不需要真路由表,鋪一個探針路由:

```dart
final fakeRouter = GoRouter(
  initialLocation: '/trips',
  routes: [
    GoRoute(path: '/trips', builder: (_, __) => const TripsListScreen()),
    GoRoute(
      path: '/trips/:tripId',
      builder: (_, state) => Scaffold(
        body: Text('detail:${state.pathParameters['tripId']}'),
      ),
    ),
  ],
);
// 點擊後:expect(find.text('detail:okinawa-trip-2026'), findsOneWidget);
```

## 手法 4:api 層測試(http_mock_adapter + InMemorySessionStore)

測 `ApiClient`/repository 本身時不 mock repository,改 mock HTTP 層:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://trip-planner-dby.pages.dev/api'));
final dioAdapter = DioAdapter(dio: dio);
final client = ApiClient(
  sessionStore: InMemorySessionStore()..write('token-123'),
  dio: dio,
);

dioAdapter.onGet('/my-trips', (server) => server.reply(200, fixtureJson));
```

`InMemorySessionStore`(`lib/api/session_store.dart`)是正式碼提供的測試替身 — 不要在測試裡碰 `SecureSessionStore`,它需要平台 channel。

## 手法 5:override 認證狀態

測需要登入狀態的畫面/路由時,override `authStateProvider` 的 build:

```dart
authStateProvider.overrideWith(() => FakeAuthNotifier(loggedInUser)),
```

其中 `FakeAuthNotifier extends AuthNotifier`,`build()` 直接回固定 `UserInfo?`(null = 未登入)。router redirect 測試(`test/app/router_test.dart`)就是用這招驗「未登入踢 `/login`、已登入離開 `/login`」。

## 驗證

```bash
flutter test               # 全綠
flutter test test/features/trips/trips_list_screen_test.dart   # 跑單檔
```

## 疑難排解

| 症狀 | 原因與解法 |
|---|---|
| `MissingPluginException`(secure storage) | 沒 override `sessionStoreProvider`/資料 provider,測試走到了 `SecureSessionStore` — override 鏈上任一節點即可 |
| `pumpAndSettle` timeout | 畫面有無限動畫(如 `CircularProgressIndicator`)— 改用固定次數 `pump()` |
| mocktail 丟 `Null is not a subtype` | mutation 方法忘了 `thenAnswer((_) async {})`,或參數 matcher 該用 `any()` |
| override 沒生效 | override 的 provider 與畫面 watch 的不是同一個實例(family 要連 key 一起 override:`tripDaysProvider(tripId)` 用 `.overrideWith` 處理 family 整體) |

## 相關文件

- [API 層參考](reference-api.md) — `InMemorySessionStore` 與 client 行為規則
- [架構說明 — provider 依賴圖](explanation-architecture.md#provider-依賴圖)
- [How to 新增畫面](howto-add-screen.md) · [How to 新增 API endpoint](howto-add-endpoint.md)
