# How-to:本機開發指向本機後端

預設連正式站 `https://trip-planner-dby.pages.dev`。本機跑後端時，用 `--dart-define`
覆寫 origin（值為 origin，**不含** `/api`；app 會自動補 `/api`，並用同一 origin 當
CSRF `Origin` header）：

```bash
flutter run --dart-define=TRIPLINE_API_ORIGIN=http://localhost:8787
```

多個 define 可重複加旗標，或用 `--dart-define-from-file`。

## 驗證覆寫生效

```bash
flutter test --dart-define=TRIPLINE_API_ORIGIN=https://example.test \
  test/api/api_client_test.dart
```

`dart-define TRIPLINE_API_ORIGIN` group 的「帶 --dart-define 時 origin 被覆寫」測試
會在帶旗標時真正斷言 `kTriplineOrigin` 已變為注入值（未帶旗標時為 no-op）。

## 注意

- 連 prod 時 mutating 操作（刪除等）會真的打到正式資料，請改指本機後端再測破壞性流程。
- 後端 CSRF 採 Origin allowlist；本機後端需允許你傳入的 origin。
