---
name: clean-commits
description: フィーチャーブランチのコミット履歴を整理する。他ブランチのマージコミットが混入している場合にリベースで除去し、残ったコミットを論理的なグループに squash してforce push する。「コミットを整理して」「コミット履歴をきれいにして」などと言ったときに使う。
allowed-tools: [Bash, Read, Glob, Grep]
---

# Clean Commits

フィーチャーブランチのコミット履歴を整理し、レビューしやすい最小限のコミット群に squash する。

> **棲み分け:** このスキルは**既に散らかった履歴を作り直す**ためのもの。実装済みの差分から**新規に**コミットとPRを作る場合は `commit-and-pr` を使う。

---

## 実行フロー

### Step 1: 現状確認

```bash
git branch           # 現在のブランチを確認
git log --oneline develop..HEAD   # featureブランチ固有のコミット一覧
git diff develop...HEAD --name-only | sort  # developとの差分ファイル一覧
```

差分ファイルの中に **今回のフィーチャーと無関係なファイル** が含まれていないか確認する。
無関係ファイルが含まれている場合は Step 2（リベース）で除去を試みる。

---

### Step 2: バックアップ作成

**必ずバックアップブランチを作成してから作業する。**

```bash
git branch backup/<現在のブランチ名>
```

---

### Step 3: origin/develop の最新を取得してリベース

```bash
git fetch origin develop
git rebase origin/develop
```

リベース後、再度 `git log --oneline develop..HEAD` と `git diff develop...HEAD --name-only` を確認する。
他ブランチのコミットが develop にマージ済みであれば、リベースで自動的に除去される。

コンフリクトが発生した場合:
- 内容を確認して手動解消
- `git rebase --continue` で再開
- 解消不能な場合は `git rebase --abort` で中断してユーザーに報告

---

### Step 4: コミットグループの計画

`git diff develop...HEAD --name-only` の結果をもとに、ファイルを論理的なグループに分類する。

**原則: 「レイヤー × 機能領域」で細かめに分割する。** 1機能を巨大な数コミットに丸めず、レビュアーが差分を追いやすい粒度にする。`feat`/`fix`/`refactor`/`chore` の type 分類だけでまとめると粗くなりがちなので、まず以下の2軸でマトリクス分割し、各セルを1コミットにすることを基本とする。

- **レイヤー軸**: `schema/db`（schema/* + prisma migration）/ `backend` / `frontend`
- **機能領域軸（例。プロジェクトのディレクトリ構造に合わせる）**:
  - backend: `共通ロジック・ヘルパー`（services/helpers, services/common）/ `admin・system_admin 設定`（services/system_admin ほか）/ `受講者向け`（services/trainee）/ `manager 表示・集計`（services/manager）
  - frontend: `admin 画面`（app/admin）/ `受講者画面`（app/trainee + 共通 _components/util）/ `manager 画面`（app/manager）

**目安: 中規模機能で 6〜10 コミット程度**（schema/db 1 + backend を領域ごとに 3〜4 + frontend を画面ごとに 3）。テストは対応する実装と同じコミットに含める。

ディレクトリ単位で `git diff develop...HEAD --name-only` を集計し、各ファイルがどのグループに入るか **漏れなく重複なく** 割り当てる（下記 awk 例のように機械的に確認すると安全）。

```bash
# ディレクトリ別にファイル数を集計し、グループ割り当ての抜け漏れを確認する例
git diff develop...HEAD --name-only | sort | sed -E 's#(^[^/]+/[^/]+/[^/]+)/.*#\1#' | uniq -c
```

**コミットメッセージの `type` / `scope` は、独自に考えず「このリポジトリの既存コミット」に合わせる。** 計画を提示する前に、直近の実コミットで使われている `type(scope)` を集計して支配的な慣習を把握し、それに揃える。機能名を勝手に scope にしない（例: `content-progress` のような独自 scope を作らず、リポジトリが使う `backend` / `frontend` / `manager` 等に合わせる）。

```bash
# 既存コミットの type(scope) を集計して慣習（レイヤー別 backend/frontend か、ロール別 manager/admin/trainee か 等）を把握する
git log origin/develop --no-merges --format='%s' -200 | grep -oE '^[a-z]+\([^)]+\)' | sort | uniq -c | sort -rn | head -30
```

- 集計で多い `scope` を採用する。レイヤーで分けたなら `feat(backend)` / `feat(frontend)` / `feat(schema)`、ロール軸が主流なら `feat(manager)` などに合わせる。
- `type`（`feat`/`fix`/`refactor`/`docs`/`chore` 等）も既存の使われ方に倣う。
- 迷ったら、集計結果を添えて「この scope で揃える」提案をユーザーに出す。

**計画を必ずユーザーに提示し、グループ構成（コミット数・各コミットのメッセージ〈既存慣習に沿った type(scope)〉・対象パス）に合意を得てから Step 5 へ進む。** 粒度が粗い/細かいの希望があれば調整する。

---

### Step 5: コミットの squash

```bash
# 全コミットをステージングエリアに展開（リベース済みなら origin/develop を基点にする）
git reset --soft origin/develop

# 全ファイルをアンステージ
git reset HEAD
```

グループごとに `git add <パス>` → `git commit` を繰り返す。

- **パス（ディレクトリ）単位で `git add` する**と、変更ファイルだけでなく **新規追加（untracked）ファイルもまとめて取り込める**（個別列挙より漏れにくい）。`dev-harness-output/` 等の gitignore 対象は add されない。
- 後のグループが前のグループの一部を含むパス指定でも、前グループで commit 済みのファイルは差分なしのため再 add されない（例: 先に `services/manager/certification` を commit → 後で `services/manager` を add しても certification 配下は対象外）。

**コミットメッセージのフォーマット（Conventional Commits・日本語）:**
```
<type>(<scope>): <要約（日本語）>

<詳細（任意）>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

---

### Step 6: 最終確認

```bash
git log --oneline develop..HEAD    # コミット数・メッセージを確認
git diff develop...HEAD --name-only | sort  # 差分ファイルが期待通りか確認
git status                         # 未コミットのファイルがないか確認 (gitignore 対象を除き空)

# 内容欠落がないことの検証: backup と HEAD のツリーが完全一致なら空になる
git diff backup/<ブランチ名> HEAD --stat
```

`git diff backup/... HEAD --stat` が**空であれば、squash 前後でツリーが一致**しており内容の欠落・混入がないことが保証される（必ず確認する）。

---

### Step 7: Force Push

```bash
git push --force-with-lease origin <ブランチ名>
```

`--force-with-lease` を使うことで、リモートに自分以外の新しいコミットがある場合は安全にエラーになる。

**force push 前にユーザーの確認を取ること。**

---

## 注意事項

- **バックアップは必ず作成する**（Step 2 を省略しない）。Step 6 で `git diff backup/... HEAD` が空であることを必ず確認する
- **粒度は「レイヤー × 機能領域」で細かめに**（Step 4）。1機能を 2〜3 の巨大コミットに丸めない
- **`type(scope)` は既存コミットの慣習に合わせる**（Step 4）。`git log` で実際に使われている scope を集計し、独自の機能名 scope を作らない
- ブランチ内で **追加→撤去された変更は net zero** となり diff・squash 後コミットに現れない（例: 途中で足して後で消したインフラ）。コミットメッセージにその撤去を書かない（差分が無いため）
- `chore(docs)` のコミットが net zero（developと差分なし）の場合は squash 時に自然に消えるので個別対応不要
- リベース後に差分ファイルがまだ無関係なものを含む場合は、ユーザーに報告して判断を仰ぐ
- **既にレビュー中の PR で実行すると、force push により全レビュースレッドが outdated 化し bot 再レビューが走る**点を、force push 前にユーザーへ伝える
- force push は `main`/`master` ブランチには絶対に行わない
