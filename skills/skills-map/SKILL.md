---
name: skills-map
description: 要件定義〜実装スキル群の工程図と使い分けを表示するルーター。どのスキルから始めるべきか迷ったときに /skills-map で呼び出す。
disable-model-invocation: true
---

# Skills Map

ユーザーの状況を聞き（既に会話に文脈があればそれを使い）、以下の工程図から該当するスキルと必要な入力を1〜3行で案内する。案内だけを行い、スキルの実行はユーザーの指示を待つ。

## メインチェーン

```
雑な依頼・Slack・メモ
  → requirements-definition-draft   壁打ち・整理（requirements-notes.md）
  → requirements-definition         正式な要件定義書（requirement.md）
  → design-doc                      技術設計書（spec.md）
  → task-breakdown                  実装タスクリスト（task.md）
  → test-case-doc                   テストケース一覧（testcase.md）
  → implement                       実装・CIループ・2軸レビュー（＋followup.md）
  → test-prep                       動作確認の準備（環境・データ・URL / testdata.md）
  → commit-and-pr                   コミット分割・ドラフトPR（大きい変更はスタックPR）
  → design-review-doc               社内レビュー用文書（review.md）
```

各文書は次工程の入力になる。前工程の文書がなくても、各スキルは会話・コードから入力を補える。

## オンランプ（途中から入る）

- バグ・単発の修正依頼（タスクリスト不要） → `implement` の修正モード
- 対話で要件を詰めたい → `requirements-definition-draft` の壁打ちモード
- 作成済みテストケースの監査 → `test-case-review`
- 手で動作確認したいので環境・データ・URLを用意する → `test-prep`
- 文書のセルフレビューだけ回したい → `doc-review-cycle`
- 実装済みの差分をコミットしてPRを出す → `commit-and-pr`
- スタックPRの積み直し・レビュー指摘反映後の更新 → `commit-and-pr` の restack モード
- 既に散らかったコミット履歴の整理・squash → `clean-commits`
- ローカルDBの復元・reindex → `restore-local-db`
- メモ・調査ログの記事化とPR → `article-draft-pr`
