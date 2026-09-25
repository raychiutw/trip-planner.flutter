# 收藏分頁與刪除焦點驗證（#347）

- 基準：`f257febd0075ad58137a450bebd9cda8b3e32d48`；公開 seam 為 `FavoritesScreen`，測試資料 200 筆，會進入每頁 24 筆的分頁路徑。
- 重現：在搜尋框輸入「收藏地點 200」，畫面結果縮成 1 筆，顯示「1 個地點」。該結果數的 semantics `isLiveRegion` 為 false；`/tmp/trip-347-red.log` 記錄公開 widget 測試預期 true、實際 false。修正票為 #406。
- 測試只觀察結果數的讀屏宣告語意，尚未驗證實際 VoiceOver 發聲，也未驗證刪除後焦點是否落在相鄰卡。後兩者需要解鎖且可操作的 iPhone 畫面；本票保持開啟。
- ADR-0008 禁止 Undo；本次沒有修改收藏刪除行為或 production code。紅燈測試分支不併入總整合，待 #406 修成綠燈後再整合。
