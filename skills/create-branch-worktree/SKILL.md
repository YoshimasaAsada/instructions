---
name: create-branch-worktree
description: Gitの既存ブランチからworktreeを安全に作成または再利用し、作成先をVisual Studio Codeで開く。ブランチ名を省略した場合は現在のブランチを対象にする。「worktreeを作って」「今のブランチをworktreeにして」「このブランチを別worktreeで開いて」「worktreeを作ってVS Codeを起動して」など、既存ブランチの作業環境を用意するときに使う。新規ブランチの作成やworktreeの削除には使わない。
---

# Create Branch Worktree

既存ブランチのworktreeを作成し、Visual Studio Codeで開く。Git操作は同梱スクリプトへ集約し、同じブランチの重複checkoutや既存ディレクトリの上書きを防ぐ。

## 原則

- ブランチ名が指定されていなければ、現在のブランチを確認せず対象にする。
- 完全なブランチ名が指定されていれば確認せず実行する。
- ブランチ名が曖昧でも候補が1件なら自動選択する。複数候補が同等、または候補がない場合だけ質問する。
- ローカルまたはremote-tracking refに存在するブランチだけを扱う。存在しないブランチを新規作成しない。
- 同じブランチが別のworktreeにあれば新規作成せず、そのworktreeをVS Codeで開く。
- 対象が現在のブランチなら、未コミット変更を自動でstashし、現在のworktreeを既定ブランチへ切り替えてから、対象ブランチとstashした変更を新しいworktreeへ移す。切り替え可能な既定ブランチがなければ現在のworktreeをdetached HEADにする。
- 既存ディレクトリの削除、worktreeの強制解除、未コミット変更の移動は行わない。
- worktree作成後も現在のセッションの作業ディレクトリは変更しない。

## ブランチの決定

1. ブランチ名が指定されていない場合は、`git branch --show-current` で現在のブランチを取得する。detached HEADならブランチ名を確認する。
2. ユーザーが完全なブランチ名を指定した場合はそのまま使う。
3. PR URLまたはPR番号が指定された場合は、`gh pr view <PR> --json headRefName -q .headRefName` で取得する。
4. 省略名やキーワードだけの場合は、次を使って候補を探す。

```bash
git branch --all --format='%(refname:short)'
gh pr list --state all --limit 50 --search '<keyword>' --json headRefName
```

5. `origin/feature/foo` のようなremote名つきの入力は、対応するローカルブランチ名 `feature/foo` に正規化する。
6. remoteがある場合は `git fetch --all --prune` を試みる。ネットワークエラーでもローカルに対象refがあれば継続する。

## 作成先

ユーザーが作成先を指定していなければ、同梱スクリプトの既定値を使う。

```text
<メインworktreeの親>/<リポジトリ名>-worktrees/<ブランチ名の「/」を「-」へ変換>
```

例: `/work/app` の `feature/user-search` → `/work/app-worktrees/feature-user-search`

## 実行

このスキルのディレクトリを基準に、同梱スクリプトを実行する。

```bash
bash scripts/create-worktree.sh '<branch-name>' ['<destination>']
```

スクリプトは次を一括で行う。

1. Gitリポジトリとブランチ名を検証する。
2. 同じブランチが別のworktreeでチェックアウト済みなら、そのworktreeを再利用する。
3. 対象が現在のブランチで未コミット変更があれば、`git stash push --include-untracked` でステージ済み・未ステージ・未追跡ファイルを一時退避する。
4. 現在のworktreeを `origin/HEAD`、`main`、`develop`、`master` の優先順で利用可能なローカルブランチへ切り替える。候補がなければdetached HEADにする。
5. ローカルブランチ、または一意なremote-tracking branchからworktreeを作成する。
6. 新しいworktreeへstashを `--index` つきで適用し、成功した場合だけstashを削除する。
7. `code <worktree-path>` でVS Codeを開く。
8. `code` がPATHにないmacOSでは `open -a "Visual Studio Code" <worktree-path>` を使う。

スクリプトを使わず、直接 `git worktree add` を組み立てない。

## エラー時

- ブランチ候補が複数: 候補を列挙し、1回だけ選択を求める。
- ブランチが存在しない: 新規作成せず、見つからなかったことを報告する。
- 作成先が既に存在し未登録: 上書きや削除をせず停止する。
- worktree作成前に失敗: 元ブランチとstashを元のworktreeへ復元する。
- stashの適用が競合: 新しいworktreeとstashを保持し、競合解消が必要なことを報告する。stashは削除しない。
- worktree作成後にVS Codeの起動だけ失敗: worktreeは保持し、パスと手動コマンドを報告する。

## 完了報告

次だけを簡潔に報告する。

- 対象ブランチ
- worktreeの絶対パス
- 新規作成か既存再利用か
- 元のworktreeを切り替えた場合は、その切り替え先
- 未コミット変更の移行結果
- VS Codeの起動結果
