# AI Instructions Repository

AIへの指示書（プロンプト・ガイドライン）を一元管理するリポジトリです。

## 運用ルール

- 指示書は用途別にディレクトリを分けて管理する
- ファイル名は用途がわかる英語名（例: `review.md`, `refactor.md`）
- 「コミットして」と依頼すると、Claude が変更内容を解析し、このREADMEのインデックスを更新した上でコミットを作成する

## ディレクトリ構成

```
instructions/
├── README.md         # このファイル（インデックス）
├── CLAUDE.md         # Claude Code 向け運用ルール
├── utils/            # 汎用指示書（どのAIツールでも利用可能）
├── claude/           # Claude Code 固有の指示書
└── copilot/          # GitHub Copilot 固有の指示書
```

## Index

<!-- INDEX_START -->
### ルート/（共通）

| ファイル | 説明 |
|----------|------|
| [base-CLAUDE.md](base-CLAUDE.md) | 各プロジェクトへ `CLAUDE.md` を導入するためのベーステンプレートと運用ルール集 |

### utils/（汎用）

| ファイル | 説明 |
|----------|------|
| [utils/clean-commits.md](utils/clean-commits.md) | 差分同一性を保証しながらコミット履歴を安全に整理する指示書 |
| [utils/create-adr.md](utils/create-adr.md) | 技術的意思決定をADR形式で背景・選択肢・理由とともに記録する指示書 |
| [utils/create-docs.md](utils/create-docs.md) | 未確定事項確認と根拠明記を徹底し、要件定義書・設計書・タスクリストを生成する指示書 |
| [utils/create-onboarding.md](utils/create-onboarding.md) | コードベース調査をもとに新メンバー向けオンボーディングガイドを作成する指示書 |
| [utils/create-pr.md](utils/create-pr.md) | 差分とコミット履歴からPR説明文を構造化して生成する指示書 |
| [utils/create-test-code.md](utils/create-test-code.md) | 仕様ベースでテスト観点を抽出し壊れにくいテストコードを作成する指示書 |
| [utils/debug.md](utils/debug.md) | エラーログと再現手順から原因分析・修正案・再発防止策を提示する指示書 |
| [utils/fix-from-review.md](utils/fix-from-review.md) | レビュー指摘を分類して要件定義書・設計書・タスクリストへ反映する指示書 |
| [utils/generate-tests.md](utils/generate-tests.md) | 正常系・境界値・異常系を網羅したテストケースとテストコードを生成する指示書 |
| [utils/impact-analysis.md](utils/impact-analysis.md) | 変更対象の直接・間接依存を追跡して影響マップを作成する指示書 |
| [utils/migration-safety.md](utils/migration-safety.md) | DBマイグレーションのリスク評価と実行計画・ロールバック計画を作成する指示書 |
| [utils/refactor.md](utils/refactor.md) | 振る舞いを変えずに責務分離・重複排除・可読性改善を進める指示書 |
| [utils/review.md](utils/review.md) | 根拠コードを添えて優先度別に指摘するCTO視点のコードレビュー指示書 |
| [utils/review-loop.md](utils/review-loop.md) | レビュー→修正→再レビューを指摘ゼロまで反復するワンストップ指示書 |
| [utils/scaffold-from-spec.md](utils/scaffold-from-spec.md) | 設計書（spec.md）に沿って実装順序どおりに雛形コードを生成する指示書 |
| [utils/type-review.md](utils/type-review.md) | any/unknownなど型安全性の問題を検出し改善案を提示する型レビュー指示書 |

### claude/（Claude Code 固有）

| ファイル | 説明 |
|----------|------|
| [claude/create-docs.md](claude/create-docs.md) | Exploreエージェントを活用して要件定義・設計書・タスクリストを作成する指示書 |
| [claude/fix-from-review.md](claude/fix-from-review.md) | review結果を3文書に反映するClaude Code向けレビュー修正ワークフロー指示書 |
<!-- INDEX_END -->
