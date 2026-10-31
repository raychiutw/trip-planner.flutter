---
status: accepted
---

# 認證只走 PKCE 與 Bearer，取代 cookie 與原生密碼登入

後端拆成獨立的 api 專案（trip-planner spec #1462、ADR-0011），web 與 api 在不同網域，認證從 cookie 改成 bearer token。ADR-0005 的前提「後端不動、app 扮演瀏覽器走 cookie」因此失效，本決定取代它。

決定：Flutter 只走 OAuth public client 加 PKCE（系統瀏覽器登入），移除原生 Email／密碼表單與 cookie 流程，不留編譯期開關。

- **登入憑證**：access token 只放記憶體（15 分鐘）；refresh token 每次使用即輪替，落地時放需要生物辨識才能讀的 Keychain／Keystore 項目。沒有生物辨識的裝置退回裝置密碼保護，連裝置密碼都沒有就不落地、每次開 app 重新登入。
- **生物辨識登入**：改成解鎖 refresh token，不再把密碼存進鑰匙圈。v0.36 的「綁定帳密」流程整個重寫。
- **授權回跳**：改用 https callback（Universal Link／App Link），網域是可設定值，後端搬網域時只改設定。
- **SSE**：繼續用 `Authorization: Bearer` 標頭，不換一次性 ticket。ticket 是為了瀏覽器 `EventSource` 不能帶標頭，Dio 沒有這個限制。前提是新 api 的 SSE 端點接受標頭認證，已請後端確認。
- **落地方式**：直接合進 master，不另開長壽 branch，也不加開關，只是不 bump `VERSION`。切換前的 master 不可以發版。
- **實作備註**：回跳用 `flutter_web_auth_2`（iOS ASWebAuthenticationSession https callback、Android Auth Tab）；受保護儲存用 `flutter_secure_storage` 的 `accessControlFlags: biometryCurrentSet`／`AndroidOptions.biometric`。iOS 需在 Apple Developer 為 App ID 開啟 Associated Domains，provisioning profile 才含該 entitlement，否則簽章失敗。

## Considered Options

**保留原生密碼表單，等後端提供帳密換 token 端點** —— 登入手感不變、Face ID 不必重寫。拒絕：spec 沒有這種端點，ADR-0005 也因「mobile 專用認證面同時是 web 的攻擊面」拒絕過；而且 App 繼續保管明文密碼是目前最大的弱點。

**維持 loopback 回跳** —— 不碰原生層。拒絕：ADR-0005 記錄的 iOS 斷點仍在，後端遲早移除 loopback 登記，之後還是得改。

**用編譯期開關關閉新流程** —— 不影響 production、可隨時發版。拒絕：使用者決定不要開關。

**長壽 branch 開 PR 不合併** —— 這是我們建議的方案，能讓 master 隨時可發版。使用者選擇直接合進 master。

## Consequences

- **master 在切換前不可發版。** 新認證碰不到舊入口，一旦因別的修正發版就會把登入帶壞。auto-release 只看 `VERSION`，擋不住這件事，只能靠「不 bump `VERSION`」的紀律；任何急用的 hotfix 要先評估怎麼處理。
- 切換當天所有使用者重新登入一次；Flutter app 尚未上架，影響最小。
- 使用者新增或移除生物特徵後，受保護的 refresh token 會失效，要重新登入一次。
- 切換前必須實機驗證 Universal Link／App Link 能回到 app，以及 assetlinks 指紋與 Play Console 簽章指紋核對。
- 新 api 的契約（OpenAPI）還不存在，實際路徑與回應格式要等它產出後再對一次。
