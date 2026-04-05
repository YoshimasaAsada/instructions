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
<!-- INDEX_END -->
