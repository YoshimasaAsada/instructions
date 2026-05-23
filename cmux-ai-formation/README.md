# CMUX AI Formation

CMUX 上に AI コーディング用の作業フォーメーションを 1 コマンドで構築するためのセット。

## 構成

```text
cmux-ai-formation/
  ├─ cmux-ai-formation.sh
  ├─ cmux-ai-coding-formation-instructions.md
  ├─ cmux-ai-coding-tools.md
  └─ README.md
```

## 作成される画面

```text
┌──────────────────────────────┬──────────────────────────────┐
│                              │                              │
│  Yazi                         │  lazygit + delta              │
│                              │  変更ファイル一覧 / diff       │
│  ファイル移動 / 内容確認       │                              │
│                              │                              │
├──────────────────────────────┤                              │
│                              │                              │
│  mo browser                   │                              │
│  Markdown / Mermaid preview   │                              │
│                              │                              │
├──────────────────────────────┴──────────────────────────────┤
│                                                             │
│  Codex / Claude Code                                         │
│  AI エージェントのチャットスペース                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 前提ツール

未インストールの必須ツールがある場合、スクリプトは自動インストールせず、不足ツールと導入方法を表示して終了する。

```bash
cmux
codex
claude
lazygit
delta
yazi
mo
jq
```

Homebrew で入れられるものは、以下のような案内を表示する。

```bash
brew install jq lazygit yazi k1LoW/tap/mo
```

`cmux`, `codex`, `claude` は手動インストールと認証が必要。

推奨:

```bash
just
rg
fd
yq
gitleaks
bat
fzf
```

## 使い方

このディレクトリに移動する。

```bash
cd cmux-ai-formation
```

現在のリポジトリを開く。

```bash
./cmux-ai-formation.sh
```

親ディレクトリから実行する場合:

```bash
./cmux-ai-formation/cmux-ai-formation.sh /path/to/project
```

別リポジトリを指定する。

```bash
./cmux-ai-formation.sh /path/to/project
```

Claude Code を使う。

```bash
./cmux-ai-formation.sh /path/to/project --agent claude
```

workspace 名を指定する。

```bash
./cmux-ai-formation.sh /path/to/project --title "feature-login"
```

## 動作

スクリプトは以下を自動実行する。

- CMUX アプリを起動する
- 対象リポジトリで `mo -wR <project> --no-open` を起動する
- 新しい CMUX workspace を作る
- Yazi、lazygit、mo browser、Codex / Claude Code のペインを作る
- AI エージェントのペインにフォーカスする

## 補足

`mo` は `http://localhost:6275` で起動する。  
Markdown / Mermaid のプレビューは Yazi の下にある独立した browser ペインで見る。

詳細な運用手順は以下を参照。

- [cmux-ai-coding-formation-instructions.md](./cmux-ai-coding-formation-instructions.md)
- [cmux-ai-coding-tools.md](./cmux-ai-coding-tools.md)
