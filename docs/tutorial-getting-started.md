# 新手教學:從 clone 到改出第一個畫面變更

跟著做完,你會有一個在模擬器上跑起來的 Tripline app、全綠的完整測試套件,並且親手改一行 UI、用測試驗證它 — 走完一輪本專案的 TDD 開發循環。

## 你需要

- Flutter 3.41+ / Dart 3.11.3+(`pubspec.yaml` 要求 `sdk: ^3.11.3`;`flutter --version` 確認;安裝見 [flutter.dev](https://docs.flutter.dev/get-started/install))
- iOS Simulator(macOS + Xcode)或 Android Emulator 其一
- 一組 trip-planner 的**測試帳號**(app 連的是 prod API,不要拿正式資料操作)

## Step 1:取得專案並安裝依賴

```bash
git clone https://github.com/raychiutw/trip-planner.flutter.git
cd trip-planner.flutter
flutter pub get
```

看到 `Got dependencies!` 就成功了。

## Step 2:跑測試 — 第一個看得見的結果

```bash
flutter test
```

預期輸出結尾(`+N` 為當前測試總數,會隨開發增加):

```
00:0x +N: All tests passed!
```

這些測試覆蓋三層:models 的 JSON 解析、API client 的行為規則、每個畫面的 widget test。**全程不打網路** — 假資料怎麼注入的,之後可看 [How to 用 provider override 寫測試](howto-test-with-providers.md)。

## Step 3:在模擬器跑起來

```bash
flutter run
```

app 啟動後停在登入頁(沒有 session 時 router 自動導向 `/login`)。用測試帳號登入,逛一圈:

- **行程** tab:卡片清單(下拉更新、長按刪除)
- 點一張卡 → **時間軸**(上方 day pills 換日)→ 右上角進**地圖**與**筆記**
- **帳號** tab:統計與登出

> ⚠️ **本 app 連的是正式 API,沒有 staging。** 教學階段請只做唯讀操作 —
> **不要試「長按刪除」**,它會打真的 `DELETE /trips/:id` 刪掉後端資料(且無法復原)。
> 等之後 `--dart-define=TRIPLINE_API_URL` 覆寫實作後才有安全的本機後端可玩。

聊天/全域地圖/收藏三個 tab 目前是「即將推出」佔位(P1 範圍)。

## Step 4:改一行 UI(先讓測試告訴你改壞了)

登入頁空值送出時會提示「請輸入 Email」。我們把提示改得更明確 — 但這專案是 TDD,先動測試:

1. 打開 `test/features/auth/login_screen_test.dart`,找到「空值 submit」測試,把期望文字 `'請輸入 Email'` 改成 `'請輸入 Email 帳號'`。
2. 跑 `flutter test test/features/auth/login_screen_test.dart` — **紅**(實作還是舊文案,正確的失敗)。
3. 打開 `lib/features/auth/login_screen.dart`,把 email 欄位 validator 的提示文字改成一樣的新文案。
4. 再跑一次 — **綠**。

```
00:0x +x: All tests passed!
```

`flutter run` 還開著的話按 `r` hot reload,模擬器上立刻看到新標語。

(確認完可以 `git checkout -- .` 還原,這只是練習。)

## Step 5:收尾檢查

提交前的完成定義(全專案一致):

```bash
flutter analyze   # 零 error / warning
flutter test      # 全綠
```

## 你完成了什麼

- 跑起 Tripline 的開發環境與完整測試套件
- 在模擬器上體驗了 P0 全部畫面
- 走完一次紅 → 綠的 TDD 循環,知道「先改測試、再改實作」是這裡的規矩

## 下一步

- 想懂整體設計:[架構說明](explanation-architecture.md)
- 想接新資料:[How to 新增 API endpoint](howto-add-endpoint.md)
- 想加新畫面:[How to 新增畫面](howto-add-screen.md)
- 查 API/模型/主題細節:[reference-api](reference-api.md) · [reference-models](reference-models.md) · [reference-theme](reference-theme.md) · [reference-navigation](reference-navigation.md)
