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
└── utils/            # 汎用ユーティリティ系指示書
```

## Index

<!-- INDEX_START -->
| ファイル | 説明 |
|----------|------|
| [utils/review.md](utils/review.md) | CTO視点でのコードレビュー指示書。一貫性・可読性・スケーラビリティの観点でレビューし、指摘と称賛を含むレポートを生成する |
| [utils/create-docs.md](utils/create-docs.md) | 新機能の要件定義・設計書・タスクリストを自動生成するフィーチャープランニング指示書 |
| [utils/fix-from-review.md](utils/fix-from-review.md) | レビューレポートの指摘を分類し、要件定義書・設計書・タスクリストに反映するレビュー修正指示書 |
<!-- INDEX_END -->
