# How to 新增 API endpoint

把一個後端 endpoint 接進 app:新增(或沿用)model、在 repository 加方法、用 TDD 流程驗證。完成後畫面層就能透過 provider 取用。

## 前置條件

- 已能跑 `flutter test`(見[新手教學](tutorial-getting-started.md))
- 知道目標 endpoint 的回應 shape — 先查 [`discovery/models.md`](discovery/models.md) 或 web repo `functions/api/` 原始碼,**不要用猜的**

## 步驟(以假想的 `GET /trips/:id/budget` 為例)

1. **先寫 model 測試(紅)** — `test/models/budget_test.dart`,fixture 用後端實際輸出:

   ```dart
   test('fromJson 解析完整欄位', () {
     final budget = TripBudget.fromJson({
       'id': 1, 'currency': 'JPY', 'amount': 120000, 'version': 2,
     });
     expect(budget.currency, 'JPY');
     expect(budget.amount, 120000);
   });
   ```

   跑 `flutter test test/models/budget_test.dart`,確認因「class 不存在」而紅。

2. **寫 model(綠)** — `lib/models/budget.dart`,遵守[通用解析規則](reference-models.md#通用解析規則):`const` 建構子、camelCase key、`(json['x'] as num?)?.toInt()`、bool 用 0/1 判斷、list 預設 `[]`。

3. **寫 repository 測試(紅)** — 在 `test/api/trip_repository_test.dart` 加一條,用 `http_mock_adapter` 鋪假回應:

   ```dart
   test('fetchBudget 打 GET /trips/:id/budget', () async {
     dioAdapter.onGet('/trips/abc/budget', (server) => server.reply(200, budgetFixture));
     final budget = await repository.fetchBudget('abc');
     expect(budget.currency, 'JPY');
   });
   ```

4. **加 repository 方法(綠)** — `lib/api/trip_repository.dart`:

   ```dart
   /// GET /trips/:id/budget。
   Future<TripBudget> fetchBudget(String id) async {
     final responseBody =
         await _client.get('/trips/${Uri.encodeComponent(id)}/budget');
     return TripBudget.fromJson(responseBody as Map<String, dynamic>);
   }
   ```

   注意:路徑參數一律 `Uri.encodeComponent`;mutation(POST/PATCH/DELETE)不需要自己帶 Origin header,`ApiClient` 會處理(見 [API 層參考](reference-api.md#行為規則每條都有對應測試見-testapiapi_client_testdart))。

5. **(若畫面要用)加 provider** — 行程詳情範圍的資料放 `lib/features/trip_detail/trip_providers.dart` 的 family;單一畫面專屬的放該畫面檔案頂部(如 `trips_list_screen.dart` 的 `myTripsProvider`):

   ```dart
   final tripBudgetProvider = FutureProvider.family<TripBudget, String>(
     (ref, tripId) => ref.watch(tripRepositoryProvider).fetchBudget(tripId),
   );
   ```

6. **重構** — 測試保護下整理命名與重複碼,重跑測試確認綠。

## 驗證

```bash
flutter analyze   # 零 error/warning
flutter test      # 全綠
```

## 疑難排解

| 症狀 | 原因與解法 |
|---|---|
| 後端回 403 | mutating request 缺 `Origin` header — 確認你走的是 `ApiClient` 的方法而不是 raw dio |
| 解析丟 `type 'int' is not a subtype of type 'double'` | 數字欄位沒走 `(json['x'] as num?)?.toDouble()` 規則 |
| bool 欄位永遠 false | server 回 `0`/`1`,要用 `json['x'] == 1 \|\| json['x'] == true` |
| 測試裡 404 | `http_mock_adapter` 的 path 要含完整路徑(不含 base);query 參數要用 `queryParameters:` 對齊 |
| 回應是 204 卻去 parse JSON | `ApiClient` 對 204/空 body 回 `null`,呼叫端回傳型別用 `Future<void>` 或自行判 null |

## 相關文件

- [API 層參考](reference-api.md) · [Models 參考](reference-models.md)
- [How to 用 provider override 寫測試](howto-test-with-providers.md)
- [How to 新增畫面](howto-add-screen.md) — 接好資料後把畫面掛上路由
