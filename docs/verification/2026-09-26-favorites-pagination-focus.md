# 收藏分頁與刪除焦點驗證（#347）

- 基準：`f257febd0075ad58137a450bebd9cda8b3e32d48`；公開 seam 為 `FavoritesScreen`，測試資料 200 筆，會進入每頁 24 筆的分頁路徑。
- 重現：在搜尋框輸入「收藏地點 200」，畫面結果縮成 1 筆，顯示「1 個地點」。該結果數的 semantics `isLiveRegion` 為 false；`/tmp/trip-347-red.log` 記錄公開 widget 測試預期 true、實際 false。修正票為 #406。
- #406 以單一結果摘要宣告篩選後筆數，分頁控制只宣告頁碼與範圍；零筆時清除篩選仍可操作。Widget 測試已轉綠，`flutter analyze` 零問題；實際 VoiceOver 發聲仍待實機確認。
- 尚未驗證刪除後焦點是否落在相鄰卡。這需要解鎖且可操作的 iPhone 畫面；本票保持開啟。
- ADR-0008 禁止 Undo；本次沒有修改收藏刪除行為。#347 的紅燈測試隨 #406 修正轉綠後一起併入總整合。
