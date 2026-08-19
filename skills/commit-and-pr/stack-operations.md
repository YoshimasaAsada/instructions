# スタック操作手順

`commit-and-pr` スキルがスタックPRの構築・維持で使う具体手順。素の `git` と `gh` だけで完結させる（Graphite 等の外部ツールに依存しない）。

## 前提と用語

- **段（stack entry）**: スタックを構成する1つのブランチとそのPR。1段 = 原則1タスク
- **base 鎖**: 1段目の base はベースブランチ、2段目以降の base は前段のブランチ
- **真実源**: スタックの構成は **PR本文のスタックナビ ＋ ブランチ命名規則**から復元する。状態ファイルを別に作らない

## ブランチ命名

```
claude/<topic>-01-<slug>
claude/<topic>-02-<slug>
claude/<topic>-03-<slug>
```

- prefix はリポジトリの既存ブランチ・PRの慣習から検出する。無ければ `claude/`
- **階層を使わない。** `claude/<topic>/01-x` は `claude/<topic>` と git ref が衝突し、両方を同時に持てない
- 連番はゼロ埋め2桁。`git branch --list 'claude/<topic>-*'` でソート順に並ぶ

## 1. スタックの構築

差分を1ブランチ上で線形にコミットしてから、コミット境界へブランチを打つ。線形履歴なので各ブランチは「その時点まで」を含む。

```bash
# 0. バックアップ
git branch backup/$(git branch --show-current)

# 1. 段の境界となるコミットハッシュを確認
git log --oneline <base>..HEAD

# 2. 古い段（下）から順にブランチを打つ
git branch claude/<topic>-01-schema   <sha1>
git branch claude/<topic>-02-backend  <sha2>
git branch claude/<topic>-03-frontend <sha3>

# 3. 同一性の検証（空であること）
git diff backup/<元のブランチ名> claude/<topic>-03-frontend --stat
```

### 各段のチェック

各段へ `git switch` して軽量チェックを実行する。すべてコミット済みなので stash は不要。

```bash
for b in claude/<topic>-01-schema claude/<topic>-02-backend; do
  git switch "$b" && <軽量チェックコマンド> || echo "FAILED: $b"
done
git switch claude/<topic>-03-frontend && <フルチェックコマンド>
```

失敗した段があれば、その段と前段の境界が不正。分割点を見直して Phase 2 の合意からやり直す。

## 2. push と PR 作成（2パス）

### パス1: PRを作る

下から順に作る。base を前段へ向ける。**必ず `--draft`。**

```bash
git push -u origin claude/<topic>-01-schema
gh pr create --draft --base <base> --head claude/<topic>-01-schema \
  --title "..." --body-file /tmp/pr-01.md

git push -u origin claude/<topic>-02-backend
gh pr create --draft --base claude/<topic>-01-schema --head claude/<topic>-02-backend \
  --title "..." --body-file /tmp/pr-02.md
```

`gh pr create --base <前段>` にすることで、PRの差分がその段の増分だけになる。

### パス2: スタックナビを差し戻す

PR番号は作成後にしか分からないため、全PR作成後に全本文を更新する。

```bash
gh pr list --author @me --state open --json number,headRefName,baseRefName --jq '.[] | "\(.number) \(.headRefName) -> \(.baseRefName)"'
```

各PRの本文末尾（またはテンプレートの指定位置）へナビを追記し、`gh pr edit <番号> --body-file <更新後の本文>` で反映する。

```markdown
## Stack

- #101 (1/3) schema: マイグレーションと Prisma スキーマ  ← このPR
- #102 (2/3) backend: 集計サービスとAPI
- #103 (3/3) frontend: 管理画面の一覧表示

> 下から順にマージしてください。
```

`← このPR` の位置は各PRごとに変える。マージ済みの段には `(merged)` を付ける。

## 3. restack: 下位に修正を積んだ場合

レビュー指摘対応などで下位の段にコミットを足すと、上位はその修正を含まない古い base の上に乗ったままになる。**下から順に** rebase を伝播させる。

```bash
# 1. 下位に修正を積む
git switch claude/<topic>-01-schema
# ... 修正・コミット ...
git push --force-with-lease   # amend/rebase した場合。追加コミットなら通常の push

# 2. 上位を順に載せ替える（必ず下から順に）
git switch claude/<topic>-02-backend
git rebase claude/<topic>-01-schema
git push --force-with-lease

git switch claude/<topic>-03-frontend
git rebase claude/<topic>-02-backend
git push --force-with-lease
```

- 順番を飛ばすと重複コミットが生まれる。必ず下から順に行う
- rebase 後は各段の軽量チェックを再実行する
- **force push 前にユーザー確認を取り、レビュー中のPRではレビュースレッドが outdated 化して bot の再レビューが走ることを伝える**

## 4. restack: 下位がマージされた場合

下位PRがマージされると、上位PRの差分に「マージ済みの内容」が混ざったままになる。ベースブランチの上へ載せ替える。

```bash
git fetch origin
git switch claude/<topic>-02-backend

# 旧 base（マージ済みブランチの元の先端）から現在までを、新しい base の上へ移す
git rebase --onto origin/<base> claude/<topic>-01-schema claude/<topic>-02-backend
git push --force-with-lease

# PR の base を付け替える
gh pr edit <02のPR番号> --base <base>

# さらに上位があれば下から順に
git switch claude/<topic>-03-frontend
git rebase claude/<topic>-02-backend
git push --force-with-lease
```

- `git rebase --onto <新base> <旧base> <対象ブランチ>` の `<旧base>` には**マージ前の下位ブランチの先端**を指定する。ローカルにブランチが残っていればブランチ名でよい
- GitHub は base ブランチが削除されると自動でPRの base を付け替えることがあるが、**履歴の載せ替えは行われない**。上記の rebase を必ず自分で行う
- 載せ替え後、マージ済みのローカルブランチを削除する前に、上位すべての rebase が完了していることを確認する

## 5. コンフリクト対応

**自動解消しない。** 次を行って中断し、ユーザーへ報告する。

```bash
git rebase --abort
```

報告に含めるもの:

- どの段からどの段への rebase で発生したか
- コンフリクトしたファイルと該当箇所
- 想定される原因（下位の修正と上位の変更が同じ箇所に当たっている等）
- 選択肢（下位の修正内容を変える / 段の分割点を変える / 手動で解消する）

## 6. 状態の復元（中断からの再開）

```bash
# ローカルのスタックブランチ一覧
git branch --list 'claude/<topic>-*' | sort

# 各PRの base 鎖と状態
gh pr list --author @me --state all --json number,headRefName,baseRefName,state,isDraft \
  --jq '.[] | select(.headRefName | startswith("claude/<topic>-")) | "\(.number) \(.state) \(.headRefName) -> \(.baseRefName)"'

# 各段が最新の下位の上に乗っているか（空なら最新）
git log --oneline claude/<topic>-02-backend..claude/<topic>-01-schema
```

最後のコマンドが**空でない段は載せ替えが必要**（下位に、その段が含んでいないコミットがある）。

## 7. 後片付け

全段がマージされたら、ユーザー確認のうえで削除する。

```bash
git branch -d claude/<topic>-01-schema
git push origin --delete claude/<topic>-01-schema
git branch -D backup/<元のブランチ名>
```

バックアップブランチは**全段のマージが完了するまで削除しない**。
