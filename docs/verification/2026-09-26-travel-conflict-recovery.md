# 移動段失敗與衝突恢復驗證（#368）

- 基準：總整合分支 `fc84f9c`；修正來源 `f44df12`。公開 seam 為 `TravelEditSheet`，使用 `tripRepositoryProvider` 替身重現後端回應。
- 500：開啟移動段 sheet，修改交通方式、名稱與分鐘後送出；回傳 500 時，sheet 內持續顯示「更新失敗，請稍後再試」，輸入不消失，再送出成功後才關閉。單檔測試「移動段保存遇到 500 時錯誤在 sheet 內持續可讀，草稿可再次儲存」通過。
- 409：以 `expectedVersion: 1` 送出後模擬 `STALE_ENTRY`，重讀同一移動段取得 version 2；草稿保持 25 分鐘，不自動覆寫。再次送出先顯示「保留你的版本？」確認，選「保留我的版本」才以 `expectedVersion: 2` 儲存。若重讀失敗或沒有新版，保留草稿與重試入口，不帶舊版重送。
- 自動計算模式的分鐘欄提示「自動計算；選填 1–1440 分鐘可手動覆寫」，手動模式提示「必填 1–1440 分鐘」；填入自動模式分鐘後有「恢復自動計算」出口。移動段更新仍走線上 repository，不宣稱已加入離線佇列。
- 確認入口依編碼規範改用 `showAppDestructiveConfirm(source: direct)`。移除確認條件時，公開衝突測試失敗；恢復後單檔 8 項、完整測試 2234 項與 `flutter analyze --no-pub` 通過。
- **待實機**：在可操作裝置上確認 500／409 橫幅於實際 sheet 的可見位置、VoiceOver／TalkBack 朗讀、auto／manual 分鐘提示的理解與焦點。Widget semantics 與程式碼文案不足以替代這些驗收；#368 保持開啟。
