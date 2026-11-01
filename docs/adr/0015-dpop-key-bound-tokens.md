---
status: accepted
---

# 以 DPoP 把 token 綁定到 App 持有的金鑰

新 api 把 access token 與 refresh token 綁定到 client 金鑰（DPoP，RFC 9449），並逐 client 強制（`DPOP_REQUIRED_CLIENTS`）。強制後沒帶 proof 的 token 請求回 400 `invalid_dpop_proof`，沒有這個決定 App 就登不進去。同時它讓 token 外洩（log、資料庫、網路）後無法被別人直接使用。本決定補充 ADR-0014，不取代它。

決定：App 每次登入產生一把 ES256（P-256）金鑰，token 請求附 proof；伺服器回 `token_type: DPoP` 才改用 `Authorization: DPoP` 加每請求 proof，回 `Bearer` 維持原流程。

- **金鑰優先序**：硬體優先（iOS Secure Enclave、Android Keystore，私鑰不離開硬體、不備份、不遷移）；拿不到時退回純 Dart 軟體金鑰（`pointycastle`，私鑰以 JWK 存 Keychain／Keystore，可匯出）。兩者 proof 格式相同，伺服器分辨不出。內部記錄金鑰類型。
- **使用條件**：裝置解鎖即可簽，不要求生物辨識，因為每個請求都要簽，每次問 Face ID 不可行。
- **生命週期**：每次登入新金鑰，登出、refresh 被拒、生物辨識失效、帳號刪除時與登入憑證一併刪除。refresh 必須用同一把金鑰，金鑰遺失時 refresh 回 `invalid_grant`，處置是清憑證回登入頁。
- **介面**：`ProofKey` 只露出「公鑰 JWK、簽字串（ES256 r‖s 64 bytes）」，產生與還原由各實作負責。上層完全不知道是硬體還是軟體。
- **不用開關**：依 `token_type` 自動決定，伺服器逐 client 強制時 App 自然跟上。
- **時鐘偏差**：proof 的 `iat` 只容許 ±60 秒；收到 400 `invalid_dpop_proof` 時用回應的 `Date` 標頭校正並只重試一次。
- **SSE**：沿用標頭直連，帶 DPoP 與 proof，每次連線含重連都重簽；處理 `event: reconnect`，不使用一次性 ticket。
- **不在本輪**：授權端的 `dpop_jkt`、`DPoP-Nonce`、userinfo 與 revoke 的細節（新 api 尚未定案）。

## Considered Options

**只做 Bearer，等被強制再說** —— 零成本。拒絕：強制時間點由伺服器決定，晚做會讓舊版 App 登不進去。

**一律用軟體金鑰** —— 一種實作、測試容易。拒絕：私鑰可被匯出，擋不住裝置被取得後的 token 竊用；硬體金鑰的原生成本值得。

**一律要求硬體，沒有就不給用** —— 最簡單的安全論述。拒絕：模擬器、CI 與部分舊 Android 都無法登入，開發與自動測試會很痛苦。

**每次簽章要生物辨識** —— 保護最強。拒絕：一個畫面常同時送多個請求，會一直彈 Face ID，實際上不可用。

**一台裝置一把金鑰長期沿用** —— 省掉每次登入產生的時間。拒絕：登出後金鑰仍留在裝置上，帳號切換不乾淨，外洩的金鑰壽命也長。

## Consequences

- 新增依賴 `pointycastle`（純 Dart、無平台程式碼），僅用於軟體後備金鑰與簽章；`api/` 層的「不得 import Flutter」規則不受影響。
- 新舊入口共用 token 表，綁定的實際保護要等舊入口下線才完全生效（api 端的說明）。
- 硬體金鑰的原生行為無法在自動測試驗證，需要真機驗證票。
