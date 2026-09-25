## 正式隱私頁瀏覽證據（2026-09-25）

正式網址：https://trip-planner-dby.pages.dev/privacy

使用 macOS Chrome 實際載入 hydrated 正文，再將 viewport 設為 390×844。頁面版本為 2026-07-20，正文包含資料收集、用途、接收方類別、保留期間、刪除申請與聯絡方式。documentElement clientWidth 與 scrollWidth 均為 390，此寬度沒有頁面水平溢出。

直接開啟 /privacy#delete-account 後，刪除帳號區塊 bounding rect top=-0.1875、bottom=654.3125，viewport height=844；錨點確實跳到可見區域。刪除申請入口為 mailto:lean.lean@gmail.com，預填主旨「刪除帳號申請」；另有同地址的聯絡入口。未點擊 mailto、未寄信、未登入、未刪除任何帳號。驗證後已還原 viewport。

頁面文字寫明從註冊電子郵件寄出申請與 7 個工作天處理；這只證實對外文案，不證明實際郵件處理、核身安全或 SLA。公開接收方類別未明列 Claude/Anthropic AI 揭露，AI 同意契約仍由 #382／#390 處理。

先前工具取得 403 並不能證明頁面不存在，本次 Chrome 已證實正式正文可讀。仍缺真實行動瀏覽器驗證與正式部署 commit 對應；桌面窄 viewport 不等同真機。因此 #386 保持開啟，不修改 production，不宣稱完整驗收通過。
