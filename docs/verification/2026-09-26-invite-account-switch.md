# 邀請與切換帳號流程驗證（#342）

- 基準：`63c4d280938dca3945d262c8f198714954b66cd7`（`feat/342-invite-account-verification` 建立時）。
- 公開測試 seam：`InviteScreen` 搭配替身 `CollabRepository` 與兩個測試帳號；新增 320 × 568pt、文字縮放 200% 的帳號不符情境。
- 重現：以 `other@example.com` 開啟寄給 `traveler@example.com` 的邀請，捲到切換帳號；確認畫面包含兩個信箱且沒有「接受」按鈕；點切換帳號後確認登入頁仍帶原邀請 token，且沒有呼叫接受邀請 API。
- 結果：上述 widget 測試通過，沒有版面例外；原有相符帳號測試也確認接受成功後才進入行程。本票沒有修改 production code。信箱在真機上的可讀性仍待實機確認。
- 檢查：邀請畫面與 controller 焦點測試 14 個通過；`flutter analyze --no-pub` 為 `No issues found`；完整 `flutter test --no-pub` 共 2230 個測試通過（2026-09-26，執行紀錄：`/tmp/342-full.log`）。Standards 審查沒有發現測試或文件問題；Spec 的真機驗收條件仍未滿足。
- 實機界線：這是公開畫面的自動化預驗證，尚未在實機以兩個測試帳號完成邀請、登出與重新登入；不可將 widget 結果當作 #342 要求的真機驗收。實機驗收需記錄安裝版本、邀請連結來源、操作順序、接受結果與可讀性證據，且只使用測試帳號。
