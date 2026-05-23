# CMUX を使った AI コーディング環境に必要なツール整理

CMUX は、複数の AI コーディングエージェントをターミナル上で並列管理するための作業台として使える。  
特に、複数タブ、分割ペイン、通知、内蔵ブラウザ、Socket API を活用することで、AI エージェント中心の開発フローを組みやすい。

## 前提

- 利用環境: macOS
- メイン端末: CMUX
- 主用途: AI を使ったコーディング、調査、修正、レビュー、テスト
- 想定エージェント: Codex, Claude Code, Gemini CLI, OpenCode, Aider など

## まず必要な最小セット

| カテゴリ | ツール | 用途 |
| --- | --- | --- |
| ターミナル | CMUX | 複数エージェント、タブ、分割ペイン、通知、ブラウザ確認 |
| AI エージェント | Codex, Claude Code | 実装、調査、レビュー、修正 |
| Git 操作 | git, GitHub CLI, lazygit | ブランチ管理、変更ファイル一覧、PR 作成、CI 確認 |
| Git diff 表示 | delta | `lazygit` や `git diff` の差分を読みやすくする |
| ファイル操作 | Yazi | ターミナル上でのファイル移動、内容確認 |
| Markdown プレビュー | mo | Markdown / Mermaid をブラウザで確認する |
| コード検索 | rg, fd | 高速なファイル検索、コード検索 |
| 表示補助 | bat, difftastic | ファイル閲覧、構造的 diff の補助 |
| JSON/YAML 処理 | jq, yq | 設定ファイルや API レスポンスの確認 |
| 絞り込み | fzf | 履歴、ファイル、ブランチ選択 |
| 実行環境管理 | mise または asdf, direnv | Node/Python/Go などのバージョン管理、環境変数管理 |
| タスク実行 | just または make | テスト、lint、dev server などのコマンド統一 |
| コンテナ | Docker Desktop または colima | DB、外部サービス、開発環境の再現 |
| セキュリティ | gitleaks または trufflehog | secret 混入チェック |

## AI コーディングフロー別の必要ツール

| フロー | 必要ツール | 目的 |
| --- | --- | --- |
| 要件整理 | GitHub Issues, Linear, Notion, Markdown | AI に渡すタスク単位を明確にする |
| 作業分岐 | git worktree, gh, CMUX タブ | 複数エージェントを別ブランチで並列稼働させる |
| 実装 | Codex, Claude Code, Aider など | コード修正、調査、リファクタリング |
| コード探索 | rg, fd, bat, jq, yq | エージェントと人間の読解速度を上げる |
| 実行確認 | just, make, npm test, pytest, cargo test など | AI の変更を即検証する |
| UI 確認 | Playwright, Storybook, CMUX 内蔵ブラウザ | 画面崩れや E2E を確認する |
| 差分レビュー | lazygit, delta, git diff, gh pr diff | AI 生成差分を確認する |
| Markdown 確認 | mo | README、設計書、Mermaid 図をライブプレビューする |
| 品質ゲート | formatter, linter, typecheck, test | 受け入れ条件を自動化する |
| PR 化 | gh pr create, gh pr checks, GitHub Actions | CI とレビューに乗せる |
| 秘密情報チェック | gitleaks, trufflehog | secret や token の混入を防ぐ |
| 規約共有 | AGENTS.md, CLAUDE.md, README | エージェントにプロジェクトルールを伝える |

## 最終構成

```text
CMUX
  + Codex / Claude Code
  + lazygit + delta
  + Yazi
  + mo
  + just
```

| 役割 | ツール |
| --- | --- |
| ターミナル作業台 | CMUX |
| AI コーディング | Codex / Claude Code |
| Git 差分ファイル一覧 | lazygit |
| Git diff 表示整形 | delta |
| ファイル移動 | Yazi |
| Markdown / Mermaid プレビュー | mo |
| 検証コマンド統一 | just |
| 検索 | rg / fd |
| JSON/YAML 確認 | jq / yq |
| secret チェック | gitleaks |

## CMUX でのおすすめペイン構成

### 基本構成

構築は手動ではなく、以下のスクリプトを使う。

```bash
./cmux-ai-formation/cmux-ai-formation.sh /path/to/project --agent codex
```

Claude Code を使う場合:

```bash
./cmux-ai-formation/cmux-ai-formation.sh /path/to/project --agent claude
```

```text
1 タブ = 1 タスク または 1 worktree
```

```text
CMUX Tab: feature/foo

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
│  AI に実装・修正を依頼 / 必要に応じて just check             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

| ペイン | 内容 |
| --- | --- |
| 左上ペイン | Yazi |
| 左中段ペイン | mo browser |
| 右上ペイン | lazygit + delta |
| 下段ペイン | Codex / Claude Code |
| 必要時 | just / dev server / test / logs |

### 推奨比率

```text
上段左 55%: Yazi
左中段 55%: mo browser
右側 45%: lazygit
下段 100%: AI エージェント
```

`mo` は一度起動するとバックグラウンドサーバーとして動く。作業開始時に `mo -wR .` を実行し、Yazi の下の独立した browser ペインで表示する。AI エージェントとは同じペイン内タブにしない。

## インストール例

```bash
brew install lazygit git-delta yazi rg fd jq yq just gitleaks
brew install k1LoW/tap/mo
```

必要に応じて追加する。

```bash
brew install bat difftastic fzf
```

## lazygit + delta の設定

`lazygit` の差分表示を `delta` に寄せる。

```yaml
# ~/.config/lazygit/config.yml
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never
```

Git 全体でも `delta` を使う場合は以下を設定する。

```bash
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global delta.line-numbers true
```

`lazygit` から選択中の Markdown を `mo` で開く場合は、custom command を追加する。

```yaml
# ~/.config/lazygit/config.yml
customCommands:
  - key: 'M'
    context: 'files'
    description: 'Open Markdown in mo'
    command: 'mo {{.SelectedFile.Name | quote}}'
    output: none
```

## mo の使い方

`mo` は Markdown をブラウザで表示する viewer。GitHub-flavored Markdown、Mermaid、KaTeX、GitHub Alerts、syntax highlighting、live reload に対応している。

単体ファイルを開く。

```bash
mo README.md
```

docs 配下を watch する。

```bash
mo -wR docs/
```

リポジトリ内の Markdown をまとめて watch する。

```bash
mo -wR .
```

デフォルトでは以下で開く。

```text
http://localhost:6275
```

## おすすめの運用パターン

### 1. タスクごとに worktree を切る

```bash
git worktree add ../project-feature-a -b feature/a
git worktree add ../project-bugfix-b -b fix/b
```

CMUX の各タブで別 worktree を開くことで、複数の AI エージェントを衝突させずに並列稼働できる。

### 2. 定型コマンドを just に集約する

```just
dev:
    npm run dev

test:
    npm test

lint:
    npm run lint

typecheck:
    npm run typecheck

check: lint typecheck test
```

AI エージェントへの指示を以下のように統一できる。

```text
実装後に `just check` を実行して、失敗したら修正してください。
```

### 3. エージェント用のプロジェクト指示を書く

リポジトリ直下に `AGENTS.md` や `CLAUDE.md` を置く。

```markdown
# Project Instructions

## Commands

- Install: `pnpm install`
- Dev: `pnpm dev`
- Test: `pnpm test`
- Typecheck: `pnpm typecheck`
- Lint: `pnpm lint`

## Rules

- 既存の設計に合わせる
- 不要なリファクタリングをしない
- 実装後は必ずテストを実行する
- secret や .env の値を出力しない
```

### 4. AI 生成コードを必ず差分レビューする

```bash
lazygit
```

変更ファイル一覧、ファイル単位の diff、stage / unstage は `lazygit` で確認する。差分表示は `delta` で読みやすくする。

補助的に以下も使う。

```bash
git diff
git diff --stat
git status
```

構造的に差分を見たい場合だけ `difftastic` を使う。

### 5. PR 前に secret チェックを入れる

```bash
gitleaks detect
```

AI が誤って token や `.env` の内容を差分に含めるリスクを下げられる。

## 優先度順インストール候補

### 優先度 A

- CMUX
- Codex
- Claude Code
- git
- gh
- lazygit
- delta
- Yazi
- mo
- just
- rg
- fd
- jq
- fzf

### 優先度 B

- mise
- direnv
- bat
- yq
- gitleaks

### 優先度 C

- Docker Desktop または colima
- difftastic
- trufflehog
- Playwright
- Storybook

### 優先度 D

- Gemini CLI
- OpenCode
- Aider
- 1Password CLI
- GitHub Actions 補助ツール

## 重要な考え方

AI メイン開発で最も重要なのは、エージェントを増やすことではなく、検証コマンドを短く固定すること。

例えば以下のように統一する。

```bash
just dev
just lint
just typecheck
just test
just check
```

これにより、Codex や Claude Code に同じ指示で作業させやすくなる。

```text
実装してください。完了後に `just check` を実行し、失敗があれば修正してください。
```

## 推奨構成まとめ

```text
CMUX
  ├─ Tab 1: feature A / worktree A
  │   ├─ Left top: Yazi
  │   ├─ Left middle: mo browser
  │   ├─ Right top: lazygit + delta
  │   └─ Bottom: Codex
  │
  ├─ Tab 2: bugfix B / worktree B
  │   ├─ Left top: Yazi
  │   ├─ Left middle: mo browser
  │   ├─ Right top: lazygit + delta
  │   └─ Bottom: Claude Code

Repository
  ├─ AGENTS.md
  ├─ CLAUDE.md
  ├─ justfile
  ├─ package.json
  └─ .github/workflows
```

この構成にすると、AI エージェントによる実装、差分確認、Markdown / Mermaid プレビュー、検証、PR 化までを CMUX 上で一貫して扱いやすくなる。
