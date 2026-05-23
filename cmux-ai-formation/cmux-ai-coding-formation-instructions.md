# CMUX AI Coding Formation Instructions

この指示書は、CMUX 上で AI コーディング用の作業フォーメーションを構築するためのもの。  
対象ツールは `Codex / Claude Code`, `lazygit + delta`, `Yazi`, `mo`, `just`。

## 目的

対象リポジトリで、以下の作業画面を素早く構築する。

```text
CMUX Tab: current task

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
│  実装・修正・調査 / 必要に応じて just check                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

重要: `mo` は AI エージェントと同じペイン内の別タブにしない。  
CMUX CLI で作る場合は、browser を `new-surface` で追加するのではなく、独立した browser ペインとして作る。

重要: AI エージェントは最下段に置く。Yazi は左上、`mo` は Yazi の下に置く。

## 前提ツール

以下が利用できること。

```bash
codex
claude
lazygit
delta
yazi
mo
just
rg
fd
jq
yq
gitleaks
```

## 作業開始時の基本手順

通常は手動でペインを作らず、以下のシェルを使う。

```bash
cd cmux-ai-formation
./cmux-ai-formation.sh
```

親ディレクトリから実行する場合:

```bash
./cmux-ai-formation/cmux-ai-formation.sh /path/to/project
```

別リポジトリを開く場合:

```bash
./cmux-ai-formation.sh /path/to/project
```

Claude Code を使う場合:

```bash
./cmux-ai-formation.sh /path/to/project --agent claude
```

workspace 名を指定する場合:

```bash
./cmux-ai-formation.sh . --title "feature-login"
```

以降の手順は、シェルがうまく動かない場合や手動調整したい場合の復旧・確認用。

### 1. 対象リポジトリに移動

```bash
cd /path/to/project
```

### 2. Markdown / Mermaid preview を起動

```bash
mo -wR . --no-open
```

起動後、CMUX Browser で以下を開く。

```text
http://localhost:6275
```

### 3. CMUX ペインを構成

以下の比率で分割する。

```text
上段左 55%: Yazi
左中段 55%: mo browser
右側 45%: lazygit
下段 100%: AI エージェント
```

### 4. 各ペインで起動するコマンド

左上ペイン:

```bash
yazi
```

右上ペイン:

```bash
lazygit
```

左中段ペイン:

```text
http://localhost:6275
```

下段ペイン:

```bash
codex
```

または:

```bash
claude
```

検証が必要な場合は、AI エージェントの下段ペインまたは別タブで実行する。

```bash
just check
```

プロジェクトに `justfile` がない場合は、利用可能な検証コマンドを確認して実行する。

```bash
ls
```

Node.js プロジェクトなら例:

```bash
npm test
npm run lint
npm run typecheck
npm run dev
```

## lazygit での Markdown preview

`lazygit` の files パネルで Markdown ファイルを選択し、`M` を押す。  
選択中ファイルが `mo` に追加される。

`mo` の表示先は、AI エージェントのペイン内タブではなく、独立した CMUX browser ペインにする。

```yaml
customCommands:
  - key: 'M'
    context: 'files'
    description: 'Open Markdown in mo'
    command: 'mo {{.SelectedFile.Name | quote}}'
    output: none
```

## AI への標準指示

AI エージェントには、作業開始時に以下を伝える。

```text
このリポジトリで作業してください。

方針:
- 既存の設計とコードスタイルに合わせる
- 不要なリファクタリングをしない
- 変更前に関連ファイルを確認する
- 実装後は差分を確認する
- 実装後に `just check` を実行する
- `just check` がない場合は、このリポジトリで定義されている lint / typecheck / test を確認して実行する
- Markdown / Mermaid の確認が必要な場合は `mo` の preview を使う
- secret や `.env` の値を出力しない
```

## 作業中の確認フロー

```text
1. AI が実装する
2. lazygit で変更ファイル一覧を確認する
3. delta 表示の diff を読む
4. Markdown / Mermaid 変更があれば mo で確認する
5. Yazi で関連ファイルを移動・確認する
6. just check または該当テストを実行する
7. gitleaks detect で secret 混入を確認する
8. gh pr create で PR 化する
```

## よく使うコマンド

```bash
# Git 差分確認
lazygit
git diff
git diff --stat
git status

# Markdown / Mermaid preview
mo README.md
mo -wR docs/
mo -wR . --no-open
mo --status
mo --shutdown

# ファイル操作
yazi

# 検証
just check
just test
just lint
just typecheck

# secret チェック
gitleaks detect
```

## 復旧手順

### mo が AI エージェントと同じタブに出ている場合

CMUX CLI で browser surface を独立ペインに移動する。

```bash
cmux tree --workspace <workspace>
cmux --id-format both tree --workspace <workspace>
cmux drag-surface-to-split down --surface <mo-browser-surface-uuid>
```

`surface:42` のような短い ref で見つからない場合があるため、その場合は `--id-format both` で表示される UUID を使う。

### mo が起動しているか確認

```bash
mo --status
```

### mo を再起動

```bash
mo --shutdown
mo -wR . --no-open
```

### lazygit 設定確認

```bash
sed -n '1,120p' ~/.config/lazygit/config.yml
```

期待する設定:

```yaml
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never

customCommands:
  - key: 'M'
    context: 'files'
    description: 'Open Markdown in mo'
    command: 'mo {{.SelectedFile.Name | quote}}'
    output: none
```

### Yazi Git 表示設定確認

```bash
sed -n '1,80p' ~/.config/yazi/init.lua
sed -n '1,120p' ~/.config/yazi/yazi.toml
ya pkg list
```

## 完了条件

以下を満たしていればフォーメーション構築完了。

- CMUX 下段ペインで `codex` または `claude` が起動している
- 左上ペインで `yazi` が起動している
- 右上ペインで `lazygit` が起動している
- 右下ペインで `mo` browser が開いている
- `mo --status` で server が確認できる
- CMUX Browser で `http://localhost:6275` が表示できる
