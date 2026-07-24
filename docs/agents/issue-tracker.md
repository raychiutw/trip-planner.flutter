# Issue tracker：GitHub

本 repo 的 issues 與 PRD 存放於 GitHub Issues。所有操作使用 `gh` CLI。

## 慣例

- 建立 issue：`gh issue create --title "..." --body "..."`。多行內容使用 heredoc。
- 讀取 issue：`gh issue view <number> --comments`，並取得 labels、以 `jq` 篩選 comments。
- 列出 issues：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，依需求加上 `--label` 與 `--state`。
- 留言：`gh issue comment <number> --body "..."`
- 新增或移除 label：`gh issue edit <number> --add-label "..."`／`--remove-label "..."`
- 關閉：`gh issue close <number> --comment "..."`

Repo 由 `git remote -v` 判定；在 clone 內執行時，`gh` 會自動辨識。

## 是否將 PR 視為 triage 入口

**PRs as a request surface：no。**

若日後改為 `yes`，外部 PR 才會使用與 issues 相同的 labels 與狀態：

- 讀取 PR：`gh pr view <number> --comments`；diff 使用 `gh pr diff <number>`。
- 列出外部 PR：`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`，只保留 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR` 或 `NONE`。
- 留言、標記、關閉：使用對應的 `gh pr comment`、`gh pr edit`、`gh pr close`。

GitHub Issues 與 PR 共用編號。遇到 `#42` 時，先執行 `gh pr view 42`，失敗再執行 `gh issue view 42`。

## Skill 要求「publish to the issue tracker」時

建立 GitHub issue。

## Skill 要求「fetch the relevant ticket」時

執行 `gh issue view <number> --comments`。

## Wayfinding 操作

`/wayfinder` 使用一個 map issue 與多個 child issues：

- Map：建立標記為 `wayfinder:map` 的 issue，保存 Notes、Decisions-so-far 與 Fog。
- Child ticket：優先使用 GitHub sub-issue；若 repo 未啟用，改用 task list，並在 child 開頭加入 `Part of #<map>`。
- Child labels：使用 `wayfinder:research`、`wayfinder:prototype`、`wayfinder:grilling` 或 `wayfinder:task`。
- Blocking：優先使用 GitHub native issue dependencies；不支援時，在 child 開頭加入 `Blocked by: #<n>`。
- Frontier：依 map 順序選出沒有未關閉 blocker、且尚未指派的第一個 child。
- Claim：`gh issue edit <n> --add-assignee @me`
- Resolve：留言回答、關閉 child，並在 map 的 Decisions-so-far 加入 context pointer。
