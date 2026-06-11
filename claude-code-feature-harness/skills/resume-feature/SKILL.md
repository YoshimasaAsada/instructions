---
name: resume-feature
description: 保存された状態と成果物から機能開発ハーネスを再開する
disable-model-invocation: true
allowed-tools: Agent, AskUserQuestion, Read, Write, Edit, Grep, Glob, Bash, TodoWrite
---

# 機能開発の再開

次の機能開発ハーネスを再開してください。

```text
$ARGUMENTS
```

引数にはfeature slugまたは `docs/features/` 配下のパスを指定できます。空の場合は
未完了の機能ディレクトリを一覧化し、どれを再開するかユーザーに確認してください。
候補が複数ある場合は推測で選択しないでください。

以下を読み込んでください。

- 対象の `status.md`
- 現在の全成果物
- 開始済み各工程の最新レビュー
- `${CLAUDE_SKILL_DIR}/../develop-feature/workflow.md`.

完全なワークフローに従い、保存された工程から再開してください。反復番号とレビュー
履歴は維持します。工程が `awaiting_implementation_approval` の場合は承認済み計画を
要約し、実装の明示承認を求めてください。`blocked` の場合はブロッカーを説明し、
再開に必要な情報または承認だけを質問してください。

The gate checker is located at:

`${CLAUDE_SKILL_DIR}/../../scripts/check-document-gates.sh`
