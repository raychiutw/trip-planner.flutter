---
status: accepted
---

# 帳號走 sheet,不占第五個 root tab

P0 的 shell 是**五個** root branch(`1106e18`「5-tab shell/router」),第五個就是 `/account`。
`1bdf683`(finalize HIG four-tab experience)把它拿掉,#96 的 contract 階段再清掉殘留的
第五 branch dead code。現在 `StatefulShellRoute.indexedStack` 底下只有四個
`StatefulShellBranch` —— 聊天、行程、地圖、收藏(`lib/app/router.dart`)。

決定:root branch 固定四個,Account 從內容頁 Header 的 44pt `person.crop.circle` 開啟一個
**自帶 Navigation Stack 的 sheet**(`DESIGN.md:98`)。`/account`、`/settings/*` 與
`/developer/apps*` 這些 deep link 不再是獨立畫面,而是經 `legacy_aliases.dart` 的 `accountAliases` 表與 `accountSheetLocation` 轉成目前位置的
`?account=<page>` query(`lib/app/router.dart`),由 shell 在**目前
branch 上**開出對應的 sheet 頁面。

理由不是「tab 不夠放」,而是 Account 與其他四個 tab 不是同一種東西。聊天 / 行程 / 地圖 /
收藏是同一份行程資料的四個面向,使用者在它們之間**橫向切換**,各自的 Navigation Stack、Day
與捲動位置值得長期保留;Account 是低頻的、與「現在在哪個行程哪一天」完全無關的離場動作,
進去就該從根頁開始。把它塞進 tab bar 等於讓底部那條列同時承載「切換內容」與「離開內容」兩種
語意,也違反 `DESIGN.md:41`「tab bar 只負責頂層導覽」。

## Considered Options

**第五個 root branch(做過,已拿掉)** —— P0 真的實作過,不是紙上評估。實際用起來的問題是
`StatefulShellBranch` 的核心價值 —— 保留 Navigation Stack —— 對 Account **是負值**:上次停在
「已連結的應用程式」子頁,下次點頭像會直接回到那一頁,而不是帳號根頁。更關鍵的是,從任何一個
tab 進 Account 就等於**離開了那個 branch**,`navigationShell.currentIndex` 指向 Account,原本
那顆 tab 的選取態消失;要「看完帳號回到原本的位置」得額外記一份「我從哪來」的狀態,而那正是
branch 機制本來要幫忙省掉的東西。占掉四分之一的常駐 tab 寬度換來這些,不划算。

**push 到目前 branch 的 Navigation Stack** —— 拿掉第五 branch 之後最省事的替代:Header 直接
`context.push('/account')`,不占 tab、不用 sheet。被拒的原因是 Account 會變成該 branch 歷史的
一部分 —— 切到別的 tab 再切回來,回到的是 Account 而不是原本的內容頁;而同一份 Account 會在
四個 branch 各自累積一份 stack。deep link 也沒有答案:冷啟動打開 `/settings/sessions` 時,該
push 到哪一個 branch 上?

**shell 外的獨立全頁 route** —— 這其實是 `1bdf683` 當下的中間狀態(`/account` 被移到
`StatefulShellRoute` 外面當一般 `GoRoute`)。問題是 shell 外意味著整個 `indexedStack` 被蓋掉:
root tab bar 消失、四個 branch 的 element 全數卸載。捲動位置、表單輸入與未送出的聊天草稿都是
靠 branch element 常駐才活著的,離開一趟 Account 就全沒了。這正好撞上
`DESIGN.md:105`「關閉 Account sheet 後回到原頁,保留 Day、捲動位置、表單與未送出的聊天草稿」。

**每個設定子頁各自開一個 modal** —— 不共用 Navigation Stack,一頁一個 sheet。被拒是因為
Account 的 deep link 有兩層深的(`/settings/developer-apps/new`):沒有共用 stack 就沒有中間層
可以返回,使用者關掉「新增」之後會直接回到內容頁,而不是開發者應用程式清單。現行做法是把它
展開成兩層 push(`lib/features/account/account_sheet.dart:57`–`:60`)。

## Consequences

- **改回第五 tab 不是加一個 branch 而已**,要同時動 shell 結構與所有 deep link ——
  `/account`、`/settings/*`、`/developer/apps*` 十餘條 alias 全部建在
  `accountSheetLocation` → `?account=<page>` 這條轉換上(`lib/app/legacy_aliases.dart`),shell 端則靠 `accountPage` / `accountReturnLocation` 兩個參數接手
  (`lib/app/router.dart`)。

- **sheet 內只有一個 `Navigator`**(`sheetNavigatorKey`,`lib/app/adaptive.dart:763`),compact
  的近滿版 sheet 與 regular 的置中 form sheet 共用同一顆。設定子頁在同一個 stack push
  (`lib/features/account/account_sheet.dart:37`–`:45`),所以**返回只回上一層,關閉才離開整個
  Account**。系統返回手勢也照這個層級:先 `maybePop()` sheet 內的 navigator,沒得 pop 才輪到
  關閉 sheet(`lib/app/adaptive.dart:783`–`:787`)。新增設定子頁時要走這個 stack,不要另外開
  modal,否則返回層級會斷掉。

- **原 branch、Day、捲動位置、表單與聊天草稿不因開關 sheet 重建 —— 這條不變式是 sheet 方案的
  成立條件,不是附帶好處。** 實作上它由「sheet 疊在 shell 之上、不取代 shell 內容」保證:
  `navigationShell` 包在常駐的 `KeyedSubtree`(`lib/features/shell/app_shell.dart:99`–`:104`),
  deep link 觸發器 `_AccountSheetDeepLink` 只是掛在同一個 `Column` 裡的零尺寸 widget
  (`:107`–`:111`)。任何把 Account 改成蓋掉 shell 內容的實作(包含改回 branch)都會破壞它,
  改動前先確認這條還守得住。

- **同一條 `/account` 在不同 branch 開,回程位置不同。** router 的 `accountSheetOrigin()` 取
  redirect 當下的目前位置,是 shell 內容頁就用它、不是(shell 外全螢幕頁)就回 `/trips`
  (`lib/app/router.dart`;2026-09-05 #268 起不再另外記「上一個 shell 頁」),關閉時
  `router.go(_withoutAccount(uri))` 把 `account` query 拿掉回到原位
  (`lib/features/shell/app_shell.dart:303`–`:308`)。這是刻意的 —— Account 沒有自己的「首頁」,
  它永遠是某個位置上的一層覆蓋。
