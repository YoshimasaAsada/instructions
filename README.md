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
### utils/（汎用）

| ファイル | 説明 |
|----------|------|
| [utils/review.md](utils/review.md) | CTO視点でのコードレビュー指示書。一貫性・可読性・スケーラビリティの観点でレビューレポートを生成する |
| [utils/create-docs.md](utils/create-docs.md) | 新機能の要件定義書・設計書・タスクリストを生成するフィーチャープランニング指示書 |
| [utils/fix-from-review.md](utils/fix-from-review.md) | レビュー指摘を分類し、要件定義書・設計書・タスクリストに反映するレビュー修正指示書 |
| [utils/clean-commits.md](utils/clean-commits.md) | 差分を保証しながらコミット履歴を整理する指示書。バックアップ・ハッシュ検証・ロールバック手順を含む |
| [utils/create-pr.md](utils/create-pr.md) | 差分とコミット履歴からPR説明文を生成する指示書 |
| [utils/review-loop.md](utils/review-loop.md) | レビュー→修正→再レビューを指摘ゼロになるまで繰り返すループ指示書 |
| [utils/scaffold-from-spec.md](utils/scaffold-from-spec.md) | 設計書（spec.md）からスキャフォールドコードを生成する指示書 |
| [utils/refactor.md](utils/refactor.md) | 責務分離・重複排除・可読性改善のリファクタリング分析・提案指示書 |
| [utils/generate-tests.md](utils/generate-tests.md) | 正常系・境界値・異常系を網羅したテストケース設計・テストコード生成指示書 |
| [utils/type-review.md](utils/type-review.md) | any/unknown等の不適切な型を検出し改善案を提示する型定義レビュー指示書 |
| [utils/debug.md](utils/debug.md) | エラーログから仮説立案・原因特定・修正案提示を行うデバッグ指示書 |
| [utils/impact-analysis.md](utils/impact-analysis.md) | 変更対象の直接・間接の影響範囲を特定し対応方針を提案する依存関係分析指示書 |
| [utils/migration-safety.md](utils/migration-safety.md) | DBマイグレーションのリスク評価・実行計画・ロールバックSQL生成指示書 |
| [utils/create-adr.md](utils/create-adr.md) | 技術選定・設計方針をADR（Architecture Decision Record）として構造化・記録する指示書 |
| [utils/create-onboarding.md](utils/create-onboarding.md) | コードベースから新メンバー向けオンボーディングガイドを生成する指示書 |

### claude/（Claude Code 固有）

| ファイル | 説明 |
|----------|------|
| [claude/create-docs.md](claude/create-docs.md) | 新機能の要件定義・設計書・タスクリストを自動生成するフィーチャープランニング指示書 |
| [claude/fix-from-review.md](claude/fix-from-review.md) | レビューレポートの指摘を分類し、要件定義書・設計書・タスクリストに反映するレビュー修正指示書 |
<!-- INDEX_END -->
