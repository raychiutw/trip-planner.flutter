# 五區行程筆記表單驗證：線上 409 缺陷

- 來源：#369；驗證基底 `6cab0c0bc1a103761bbd27d2108b9a9448cb01c3`。
- 結論：預訂區的公開 sheet seam 已重現 409 後再次儲存失敗，修正範圍另立 #404。#369 的五區實機、鍵盤與錯誤可見性尚未完成，不標記通過。

## 可重現步驟與證據

以 `showNoteEditSheet` 開啟預訂筆記 `id=5, version=3`，輸入「我的草稿」。測試替身讓第一個 `PATCH` 回 `409 STALE_ENTRY`，並在 `tripNotesProvider('t1')` 提供同筆 `version=4` 的 fresh 資料。草稿保留；再次按「儲存」後，表單仍顯示「編輯預訂」，兩次呼叫都使用 `expectedVersion=3`，沒有使用 `version=4`。

在基底上暫時加入單一 widget 重現測試後執行：

```text
flutter test --no-pub test/features/trip_detail/notes/note_edit_sheet_test.dart --plain-name '409 後保留草稿並以最新版本再次儲存'
00:00 +0 -1: 409 後保留草稿並以最新版本再次儲存 [E]
Expected: no matching candidates
Actual: Found 1 widget with text "編輯預訂"
```

測試在最後一個「成功後 sheet 關閉」斷言失敗；在此之前，mock 驗證兩次更新都傳 `expectedVersion=3`，且沒有一次傳 `4`。重現測試的未完成 red 狀態不併入本驗證提交，留給 #404 的 red→green 修正。

原始碼也顯示五區都經過同一個 `NoteEditSheet._save`：409 時只 invalidate `tripNotesProvider`，而後續更新仍使用不可變的 `widget.version`。這能解釋預訂區的失敗，但**不是**其他四區已逐一實測的證據。線上 409 會直接上拋給 sheet；離線佇列 flush 的三方 rebase 是另一條路，不能拿來宣稱此流程已恢復。

## 尚待驗收

待 #404 修正後，使用測試帳號於真機逐一驗證航班、住宿、預訂、行前須知、緊急聯絡的失敗、409、草稿保留及恢復儲存。另驗證 persistent 錯誤在 sheet 上可見且可朗讀、鍵盤不遮住最後一欄，並區分「已存到離線佇列」與「server 已同步」。這些項目目前都沒有實機證據。
