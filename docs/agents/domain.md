# Domain docs

本文件定義 engineering skills 探索 codebase 時，應如何使用此 repo 的 domain 文件。

## 探索前讀取

- 根目錄的 `CONTEXT.md`；或
- 若存在 `CONTEXT-MAP.md`，依其指向讀取與工作相關的 `CONTEXT.md`。
- `docs/adr/` 中與目前工作相關的 ADR。

檔案不存在時直接繼續，不需警告，也不要預先建議建立。`/domain-modeling` 會在領域詞彙或決策真正需要記錄時按需建立。

## 檔案結構

此 repo 採 single-context：

```text
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-example-decision.md
│   └── 0002-example-decision.md
└── lib/
```

`CONTEXT.md` 與 `docs/adr/` 尚未存在時不需建立空檔。

## 使用 glossary 的詞彙

Issue title、重構提案、hypothesis 與測試名稱應使用 `CONTEXT.md` 定義的 domain 詞彙，避免改用 glossary 明確排除的同義詞。

若需要的概念尚未出現在 glossary，先確認是否正在創造專案沒有使用的名稱；若確實是領域缺口，再交由 `/domain-modeling` 補充。

## 標示 ADR 衝突

輸出若與既有 ADR 衝突，必須明確指出，不可默默覆蓋：

> 與 ADR-0007 衝突；但因為……，值得重新檢討。
