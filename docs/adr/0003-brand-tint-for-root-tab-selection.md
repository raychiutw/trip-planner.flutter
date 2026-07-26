---
status: accepted
---

# root tab bar 的選取膠囊改用品牌柔褐,日期選擇器維持中性

#118 把 root tab bar 的選取膠囊從品牌柔褐改成中性語意層,#117 對日期選擇器做了同樣的事,
驗收條件寫「與日期選擇器的選取態看起來是同一套」。本 ADR **反轉 root tab 那一半**,
並明文記下兩處從此刻意不同。

## 為什麼反轉

#118 的理由是「品牌柔褐鋪成膠囊底是 Material 的 indicator pill 配色,iOS 26 的作法是
中性玻璃膠囊 + tint 前景」。**這個前提不成立。** iOS 26「電話」app 的 tab bar 選取態是
強調色實心底 + 反白字符 + 強調色標籤 —— Apple 自己就拿強調色當選取背景。

需要說清楚的是:**HIG 沒有規定選取指示的形狀或配色**。`Tab bars` 一頁裡
`capsule`／`pill`／`circle`／`indicator` 出現次數都是 0,官方只承諾
「prefer a monochromatic appearance for tab bars, or choose an accent color with
sufficient visual differentiation」。所以「中性」與「強調色」兩種做法 HIG 都允許,
#118 錯的不是選擇本身,而是把「Apple 不這樣做」當成事實。

## 為什麼兩處刻意不同

- **root tab bar** 是全 app 唯一的主導覽,選取指示要能一眼看出「我在哪」,需要最強的
  視覺分量 → 品牌柔褐鋪底、字符反白。
- **日期選擇器**(`TpHorizontalSelector`)是在既有內容裡**篩選**,不是切換功能。語意上
  本來就該比 tab 弱 → 維持中性語意層。截圖裡 Apple 的分段控制「全部/未接來電」用的也是
  比容器更淺的中性灰,不是強調色。

## Consequences

- `CONTEXT.md` 的「品牌柔褐不鋪成底色」多了一條明文例外,只限 root tab 選取膠囊。
- **無障礙 fallback 不跟著改**:提高對比／降低透明度時仍收斂為中性不透明
  (`surfaceContainerHigh` α1),避免大面積品牌色在高對比下失控。
- **形式仍是整格膠囊,不是 Apple 那種只包字符的圓。** `GlassTabBar` 的 indicator 幾何
  寫死為 `FractionallySizedBox(widthFactor: 1/itemCount)`,尺寸恆為整格 tab 寬,
  形狀只有 `borderRadius` 一個旋鈕,調到底只會得到 stadium。要做真正的圓必須把圓畫進
  icon widget 並停用套件 indicator,成本與風險都高得多 —— 若日後真機看下來覺得必要,
  再另開一張票。
- 這個決定**依賴 `surfaceContainerHighest` 那個 bug 已修好**(PR #149)。在那之前
  中性膠囊根本沒顯示過(token 未定義而回退成 `surface`),所以「中性看起來不夠」這個
  觀察在修復前是無效的 —— 本 ADR 是在修復後的前提上做的決定。
