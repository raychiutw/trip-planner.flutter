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
- **那兩層設定原本都不存在,2026-07-25 已補上(issue #133)。** 查證時發現
  `mobile-release` 只有 `branch_policy`、`rulesets` 數量為 0、`master` 回
  404 Branch not protected —— 也就是手動 dispatch 一次就直接上傳,而且
  「master 上的 code 已經過 CI」這個前提並不成立。現況:

  ```
  environments/mobile-release  protection_rules = [branch_policy, required_reviewers]
  rulesets                     = ["master: require CI"]（required_status_checks: Analyze and test）
  ```

  **這是 repo 設定,不在程式碼裡,測試驗不到** —— 它可以被任何有 admin
  權限的人靜靜關掉,而本 ADR 的整個安全論證都靠它。定期複查:

  ```bash
  gh api repos/raychiutw/trip-planner.flutter/environments/mobile-release \
    --jq '[.protection_rules[].type]'
  gh api repos/raychiutw/trip-planner.flutter/rules/branches/master \
    --jq '.[] | select(.type=="required_status_checks")'
  ```
- **Test Lab 失敗不再等於發版失敗,但也不再有人被迫看它。** 排程跑出來的紅燈需要有人主動追,否則外部裝置證據會靜靜地爛掉。
- 契約由 `test/platform/google_maps_configuration_test.dart` 與 `test/features/map/map_platform_config_test.dart` 守住:前者驗 store job 沒有 `needs:`、但保有 environment 與 master-only;後者驗 `mobile-e2e.yml` 保有自己的觸發來源,不會因為沒人呼叫而變成孤兒 workflow。
- **build number 的公式是 `GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT`,而且不能改用 `GITHUB_RUN_ID`。**
  解耦之後兩個 store job 沒有共同的前置 job 可以幫它們產號,只能各自從 run 身分推導,因此同一條公式在兩邊各寫一次:iOS build number 在 `.github/workflows/mobile.yml:125`,Android version code 在 `.github/workflows/mobile.yml:208`。`GITHUB_RUN_ID` 看起來是更省事的單調遞增值,但現行 GitHub run ID 的量級已經超過 Google Play version code 的上限 `2100000000`,用了會直接被 Play 退件;Android job 在 `.github/workflows/mobile.yml:209-212` 另外留一道上限檢查當保險。
- **`GITHUB_RUN_ATTEMPT < 100` 是硬性守門條件,不是防呆。**
  乘數 100 等於替每個 run 切出 100 格的 attempt 區間;attempt 一旦到 100,算出來的值就會溢位撞進下一個 `RUN_NUMBER` 的區間,跟未來某次 run 產生重號的 version code —— 而 Play 對重複的 version code 是拒收。所以兩個 job 都在建置動作之前直接 `exit 1`(`.github/workflows/mobile.yml:121-124`、`204-207`),寧可讓發版失敗也不讓它靜靜溢位。代價是同一個 run 重跑滿 99 次之後只能改開新 run,不能再 re-run 舊的。
