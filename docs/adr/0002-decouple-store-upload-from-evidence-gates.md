---
status: accepted
---

# 商店上傳與外部裝置、人工證據解耦

原本 `mobile.yml` 的 `testflight` 與 `android_internal` 兩個 job 都寫 `needs: [ci, external_device_gate, manual_evidence_gate]`:一次發版要先跑完整 CI、再跑 Firebase Test Lab 的實體裝置矩陣、再由 `manual_evidence_gate` 以 `curl` + `jq` 驗證一份 HTTPS 上的人工輔助使用 JSON 報告,三關全綠才會上傳。`3380893 ci: shorten mobile release path` 把這條串接拆開,store job 改為手動 dispatch 直接執行。**維持解耦**是本 ADR 記錄的決定。

## Considered Options

**維持三閘門串接** —— 上傳當下有機器強制的完整證據,但發版的成敗綁在自己控制不了的東西上:Firebase Test Lab 的 quota 與基礎設施、實體 iOS 裝置的 Apple Development 簽章、以及一份要人去產、還得掛在 HTTPS 上的 JSON 報告。Test Lab 的 infra flake 會直接變成「發不出版」,而它跟 app 本身的品質無關。三關串接也讓 TestFlight 與 Google Play 無法平行,wall clock 被拉長。

**只解耦人工證據,保留 Test Lab 閘門** —— 拿掉最麻煩的一關,但 Test Lab 的 infra flake 仍會擋住發版,而那正是主要痛點。留下的機器閘門也還是會讓兩個 store job 序列化。折衷的結果是兩邊的缺點各留一半。

**完全解耦(選定)** —— store job 不依賴任何前置 job,TestFlight(`macos-26`)與 Google Play(Ubuntu)平行啟動並共用同一組 `GITHUB_RUN_NUMBER`／`GITHUB_RUN_ATTEMPT`,因此拿到相同 build number。證據不是不做,而是改成獨立軌道:`mobile-e2e.yml` 保留自己的 `schedule`(平日 02:30 Asia/Taipei 跑 Android matrix)與 `workflow_dispatch`;人工報告改用保留下來的 `tool/validate_manual_evidence.sh` 驗證,結果連回對應 issue 或 release record。

## Consequences

- **把關從 workflow 層移到 GitHub 設定層。** 剩下的前置條件只有兩個:`environment: mobile-release` 的環境審核,以及 `github.ref == 'refs/heads/master'` 加 `workflow_dispatch` 的觸發限制。這兩層是現在唯一擋在上傳前面的東西。
- **`mobile-release` 這個 Environment 若沒有設 required reviewers,發版就真的沒有任何前置把關。** 這是 repo 設定,不在程式碼裡,測試驗不到 —— 是本決定最主要的殘留風險,發版負責人必須自行確認該設定存在。同理,`master` ruleset 要把 PR 的 `Analyze and test` 設為 required status check,否則「master 上的 code 已經過 CI」這個前提不成立。
- **Test Lab 失敗不再等於發版失敗,但也不再有人被迫看它。** 排程跑出來的紅燈需要有人主動追,否則外部裝置證據會靜靜地爛掉。
- 契約由 `test/platform/google_maps_configuration_test.dart` 與 `test/features/map/map_platform_config_test.dart` 守住:前者驗 store job 沒有 `needs:`、但保有 environment 與 master-only;後者驗 `mobile-e2e.yml` 保有自己的觸發來源,不會因為沒人呼叫而變成孤兒 workflow。
