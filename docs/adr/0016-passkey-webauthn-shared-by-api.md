---
status: accepted
---

# 用 passkey（WebAuthn）做生物辨識登入，由 api 統一提供，web 與 App 共用

認證改為 PKCE 後，登出會清掉登入憑證，「用 Face ID／Touch ID 保護 refresh token」在登出後無物可解，v0.36 的「登出後按 Face ID 直接登入」因此消失；web 則從沒有生物辨識。我們決定由 api 提供 passkey（WebAuthn），web 用瀏覽器 WebAuthn、App 用 iOS／Android 原生 passkey，三邊共用同一份伺服器端憑證。需求見 web #1677。

這推翻 `GLOSSARY.md`「passkey：本 App 不做」的舊立場（當時認為它需要後端）。後端現在要做，詞彙表需隨實作更新。

## Decision

- **單一來源**：憑證存在 api。登入完成後簽發的 token 與密碼登入完全相同（含 DPoP 金鑰綁定，見 ADR-0015），後端其餘部分不分辨登入方式。
- **RP ID 用 `trip-planner-dby.pages.dev`**：現有 web 網域。`pages.dev` 在 Public Suffix List，該網域本身可當 RP ID。iOS 的 AASA 已有 `webcredentials`。Android 的 `assetlinks.json` 目前只確認有網址處理關聯，passkey 所需關聯尚未確認，實作時要驗證並補齊。
- **密碼登入保留為後備**：沒有生物辨識或沒註冊 passkey 的人不受影響；passkey 失效時仍能登入。
- **現有 App 鎖與「生物辨識保護登入憑證」不動**，與 passkey 互相獨立；passkey 負責登出後回來的路徑。

## Considered Options

- **只做 web 的 passkey，App 維持現狀**：範圍小，但 App 的「登出後登入」得另用別的方法，兩邊行為不一致。
- **只做 App 本機的金鑰，不經 api**：不必動後端，但換手機或換瀏覽器就沒有，也無法與 web 共用。
- **不做 passkey，只做裝置本機解鎖**：與「生物辨識登入」的需求不符。

## Consequences

- **搬網域會讓已註冊的 passkey 全部失效**，因為 passkey 綁 RP ID。這是此決定最難逆轉的代價，也與 PKCE 回跳網域可設定的設計相呼應：回跳網域能換，passkey 的網域不能。搬遷時的處理（評估 WebAuthn Related Origin Requests、保留密碼登入、事先通知使用者）在實際搬網域前再決定，現在不預先實作。
- api 要新增憑證儲存與註冊、登入、列出、改名、撤銷能力；OpenAPI 契約隨之擴充，web、Flutter、agent 的契約測試要更新。
- 使用者新增或移除生物特徵後，passkey 是否仍可用取決於平台（同步型 passkey 通常不受影響）；實機驗證時要確認並寫進使用者說明。
- 新增 passkey 與撤銷要寄通知信，沿用變更密碼通知的機制。
