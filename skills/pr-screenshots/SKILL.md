---
name: pr-screenshots
description: 画面の見た目が変わる PR に、変更前・変更後のキャプチャを並べて変更箇所を赤枠で囲んだ画像を作り、PR 本文の「動作確認」に貼る。「PR にキャプチャを貼って」「変更前後のスクショを PR に載せて」「どこを直したか赤枠で囲んで貼って」と言われたとき、および見た目が変わる PR を作成・更新したときに使う。PR の作成そのものには create-pr / commit-and-pr、動作確認用のデータ準備には test-prep を使う。
---

# PR Screenshots

見た目が変わる PR ごとに「変更前・変更後を並べ、変更したブロックを赤枠で囲んだ画像」を1枚作り、PR 本文に貼る。レビュアーがコードを読む前に、どこが変わったかを一目で分かるようにするため。

- **入力:** 対象の PR（番号またはブランチ）と、その PR で変わる画面・ブロック
- **出力:** PR ごとの画像（PNG）と、画像を「# 動作確認」に足した PR 本文
- **責務外:** PR の作成、コードの修正、検証データの投入（test-prep）

## 画像の形

- PR ごとに1枚。見出しは「#<PR番号> <ブロック名>」、その下に撮影元の注記（例: 「赤枠がこの PR で変わる箇所。変更前は本番 example.com、変更後はローカル環境（本番のダンプのデータ）で撮影」）。
- PC（1366px）と SP（375px）の両方を載せる。SP のレイアウトを持たない社内向けの画面（管理画面など）は PC だけでよい。
- 既存のブロックを変えた PR は、変更前と変更後を左右に並べる。新規のブロックは変更後だけ。ブロックを外した PR は、変更前の外すブロックを赤枠で囲み、見出しに「（TOP から外す）」のように書く。
- 対象のブロックを赤枠（`#e11d48`、6px）で囲み、前後のブロックが少し見える範囲（上下 48px）で切り出す。
- 見た目が変わらない PR（リファクタ・データ取得だけなど）には貼らない。

## 手順

### 1. 撮る対象と撮影元を決める

- PR ごとに、変わるブロックと「変更前があるか（既存の改修か新規か）」を一覧にする。
- 変更前は本番（または develop をデプロイした環境）、変更後はローカルの dev サーバーで撮る。
- 変更後がデータに依存するブロックを含むなら、ローカルの API と DB が動いている必要がある。未適用のマイグレーションがあって API が動かない場合、共有の開発 DB にマイグレーションを流すかどうかは他のワークツリーに影響するため、ユーザーに確認してから行う。データの準備が要るなら test-prep を使う。
- Vercel のプレビューは SSO が必要で、Playwright からは開けない。
- **ログインが要る画面（管理画面など）は capture.js では撮れない。** 手順 2b に従う。ログインが要ることを理由に撮影を省かず、「今回は省く」を選択肢としてユーザーに出さない。頼むのはログインだけにして、それ以外の準備（dev サーバーの起動、未実行マイグレーションの確認）は先に進める。
  - 過去事例: ログインが要る管理画面の PR で、PR 作成後に Google ログインで止まり、撮らずに「撮る／省く」の二択で返した。準備を進めてログインだけを頼めば撮れた。

### 2. ブロックを撮る（`scripts/capture.js`。ログインが要らない画面）

撮影元ごとに設定 JSON を書いて実行する。出力は `<outDir>/<label>-<pc|sp>-<key>.png`。

```json
{
  "url": "http://<branch>.<app>.localhost:8080/",
  "label": "after",
  "outDir": "<scratchpad>/shots",
  "container": { "markers": ["About", "Event"] },
  "targets": [
    { "key": "fv", "index": 0 },
    { "key": "about", "text": "About" },
    { "key": "header", "selector": "header", "exact": true }
  ]
}
```

- `container`: ブロックを並べている親要素。`markers`（その中にある見出しなどの文言2つ。共通の祖先を親とみなす）か `selector` で指定する。
- `targets`: 撮るブロック。`index`（親の何番目の子か）、`text`（ブロック内の文言と完全一致する要素。その要素を含む親の直下の子をブロックとみなす）、`selector` のどれかで指定する。`exact: true` なら見つけた要素そのものを囲む。
- 文言が `?` などを含むときは、zsh のグロブで壊れないよう引用符で囲む。
- 任意: `viewports`（既定 `["pc","sp"]`）、`margin`（既定 48）、`hideSelectors`（既定 `["nextjs-portal"]`。dev サーバーの Next.js のインジケーターを隠す）、`waitMs`。

```bash
node ~/.claude/skills/pr-screenshots/scripts/capture.js <config.json>
```

- Playwright はリポジトリの `node_modules/.pnpm/playwright@*/node_modules/playwright` を自動で探す（作業ディレクトリから親へ辿り、各階層とその2階層下までのディレクトリを見る）。見つからなければ `PW=<パス>` を渡す。ブラウザは `~/Library/Caches/ms-playwright` にある前提。Node はリポジトリの mise 環境で動かす（`mise exec -C <worktree> -- node ...`）。
- 撮れたら、何枚かを `Read` で開いて、赤枠の位置・データが出ているか・遅延読み込みの画像が抜けていないかを確かめる。赤枠が見出しなどに重なっていたら、`targets` の指定を見直す。

### 2b. ログインが要る画面を撮る（Chrome）

ログイン済みの Chrome（`mcp__claude-in-chrome__*`）で撮る。内蔵ブラウザ（`mcp__Claude_Browser__*`）にはログインのセッションが無く、「ロード中」やログイン画面で止まる。

1. **dev サーバーを起動する。** worktree で `just up-main-app <アプリ名>`（非対話シェルでは `mise exec -- just up-main-app <アプリ名>`）をバックグラウンドで起動し、フロントの URL（`just hosts` のプレフィックス付き）が 200 を返すまで待つ。
   - Rails が 500 を返したら、レスポンス本文で `PendingMigrationError` か確かめる。共有の開発 DB に流すかはユーザーに確認してから `just rails db:migrate` する。流したあと `schema.rb` や annotate の注釈で書き換わった無関係なファイルは `git checkout --` で戻す。
2. **ログインをユーザーに頼む。** Google ログインなどは代行できない。「Chrome で <フルパスの URL> にログインしてください」と頼み、返事を待つ。
3. **撮る。** パターンごとに次を行う。
   - `navigate` → `wait`（初回はコンパイルで 10 秒以上かかることがある）→ `hover` でカーソルを撮影範囲の外へ逃がす。
   - `javascript_tool` で、対象のブロックに `outline: 6px solid #e11d48; outline-offset: 4px` を付け、切り出す範囲を `getBoundingClientRect` で取る（タブなどの外枠の上端から、ブロックを並べている親の下端 +24px まで。左右は外枠 ±12px）。対象が画面外なら `scrollIntoView({ block: 'center' })` してから測り直す。
   - `computer` の `zoom` に `region`・`save_to_disk: true`・`scale: 1` を渡して保存する。`region` はスクリーンショットの座標系なので、CSS px に「スクリーンショットの幅 / `innerWidth`」を掛けて換算する。`scale` を下げると保存される画像も小さくなる。
   - 保存された画像は結果の `[Image: source: ...]` のパスにあるので、`<outDir>/<before|after>-pc-<key>.png` へコピーする。
4. **変更前を撮る。** 変更したファイルを `git show "<base>:<path>" > <path>` で一時的に変更前の内容へ置き換え（dev サーバーのホットリロードで反映される）、同じ手順で撮る。撮り終えたら `git checkout -- <path>` で戻し、`git status --short` で差分が無いことを確かめる。`git stash` は他の worktree と共有なので使わない。
   - 変更前と変更後で同じ範囲を撮るとブロックが画面外になる場合（並び順の入れ替えなど）は、スクロールした位置で撮り、合成画像の注記にそう書く。
5. **データのパターン。** 表示が分岐する条件（例: 回答あり／なし × 別セクションあり／なし）ごとに、開発 DB から実在する ID を `just rails runner` で引き、パターンごとに撮る。

### 3. PR ごとに1枚にまとめる（`scripts/compose.js`）

```json
{
  "out": "<scratchpad>/shots/<repo>-pr1234.png",
  "title": "#1234 ブロック名",
  "note": "赤枠がこの PR で変わる箇所。変更前は本番 example.com、変更後はローカル環境（本番のダンプのデータ）で撮影",
  "dir": "<scratchpad>/shots",
  "keys": ["block"],
  "before": true
}
```

- `keys` に複数を渡すと、各列の中で縦に並べる（例: FV とロゴの帯を1枚に入れる）。
- `before: true` で、新規のブロック（`before-<pc|sp>-<key>.png` が無いもの）が混ざっていると、変更前の列のその位置に「新規（変更前なし）」の札を出す。既存の改修と新規が混ざった PR も1枚にまとめられる。
- `before: false` なら変更後の PC と SP を左右に並べる（新規のブロック用）。注記も「赤枠がこの PR で追加する箇所」にする。
- `beforeLabel` / `afterLabel` で列の見出しを変えられる。
- `viewports: ["pc"]` で PC だけにできる。実際に撮った幅が既定（PC 1366px）と違うときは、`viewportLabels: { "pc": "PC（約1350px）" }` で見出しを実際の幅にする（2b で撮った場合は `innerWidth` を見る）。
- 変更前と変更後で画像の高さが違うパターンを `keys` で複数まとめると、列ごとに縦に積むため行がずれる。その場合はパターンごとに別の画像にする（`keys` は1つずつ）。

```bash
node ~/.claude/skills/pr-screenshots/scripts/compose.js <spec.json>
```

できた画像は `Read` で開いて確認し、`SendUserFile` でユーザーにも見せる。

### 4. GitHub にアップロードして URL を取る

GitHub の API では画像を上げられないので、ログイン済みの Chrome（`mcp__claude-in-chrome__*`）で PR のコメント欄からアップロードする。**コメントは送信しない。**

1. 画像を作業ディレクトリの下に一時的にコピーする（`file_upload` が読めるのは作業ディレクトリなどに限られ、scratchpad は不可）。
2. 対象リポジトリのどれか1つの PR を開き、`find` で新規コメント欄の file input（`fc-new_comment_field`）の ref を取る。
   - ref は開いた直後に取ると切れやすい（`Element ref not found`）。切れたら `find` からやり直す。
   - **`find` は、別のコメント（github-actions のプレビューのコメントなど）の非表示の編集欄の file input を返すことがある。** 返ってきた ref を鵜呑みにせず、アップロード後に必ず手順4で入った先を確かめる。
   - `find` が「Add files」ボタン（file input ではない）を返すことがある。`javascript_tool` で `input[type=file]` の `id` が `fc-new_comment_field` であることを確かめ、`find` に「type=file の input」と問い直して、その ref を使う。
3. `file_upload` で全画像をまとめて渡す（1回 10MB 未満）。
4. `javascript_tool` で、ページ内の全 `textarea` の `id` と値を読み、`user-attachments` の img タグがどこに入ったかを確かめる。
   - `#new_comment_field` に入っていれば、そこから `alt="<ファイル名>" src="https://github.com/user-attachments/assets/..."` の組を取る。
   - 別のコメントの編集欄（`issuecomment-<id>-body` など）に入っていたら、URL を控えたうえでその欄から img タグだけを取り除いて元に戻す。保存はされていないので、`gh api repos/<repo>/issues/comments/<id>` でサーバー上のコメントが変わっていないことも確かめる。
   - CDP は 45 秒で切れる。アップロードを待つループは短くし（20 秒程度）、タイムアウトしたらループせずに値を1回だけ読み直す。
5. 入った欄を空に戻す（native setter で `''` を入れて `input` / `change` を発火）。コメントや編集は送信・保存しない。
6. 一時コピーを消す。

`user-attachments` の URL は同じリポジトリのどの PR の本文でも使える。

### 5. PR 本文に入れる

- 本文の「# 動作確認」の末尾に、次の1行と画像を足す。コメントにはしない。
  - 既存の改修: `- 変更箇所のキャプチャ（赤枠。PC 1366px / SP 375px。変更前は本番、変更後はローカル環境で撮影）`
  - 新規: `- 追加箇所のキャプチャ（赤枠。PC 1366px / SP 375px。ローカル環境で撮影）`
  - 2b で撮った場合: 幅と撮影元を実際のものに合わせる（例: `- 変更箇所のキャプチャ（赤枠。PC 約1350px。変更前・変更後ともローカル環境で撮影）`）。パターンが複数あるなら、その組み合わせも1行で書く。
  - 画像: `<img width="..." height="..." alt="..." src="https://github.com/user-attachments/assets/..." />`（アップロード時に入った img タグをそのまま使う）
- 既に画像があれば差し替える。本文のほかの行は変えない。
- `gh pr view <n> --json body -q .body` で取得 → 置き換え → `gh pr edit <n> --body-file` で更新する。置き換えの前後は diff で確認する。
- 更新後、Chrome で PR を開き直し、本文の `img` が読み込めている（`naturalWidth` が 0 でない）ことを確認する。

## 後片付け

- 撮影のためにビルドや起動をした場合、`next-env.d.ts` などビルドで書き換わったファイル、`db:migrate` で書き出された `schema.rb` を元に戻す（コミットしない）。
- 変更前を撮るために置き換えたファイルを戻し、`git status --short` で差分が無いことを確かめる。
- 2b で撮った場合、撮影のために開いた Chrome のタブを閉じる。
- 一時的に起動したサーバーは止める。ユーザーが見る可能性がある dev サーバーは、止めるか聞くか、起動したままであることを報告する。

## 完了条件

- [ ] 見た目が変わる PR すべてに、変更箇所を赤枠で囲んだ画像を貼った（変わらない PR には貼っていない）
- [ ] 画像に PC と SP（SP のレイアウトを持たない画面は PC だけ）、撮影元の注記が入っていて、見出しの幅が実際に撮った幅と合っている
- [ ] ログインが要る画面でも撮影を省いていない（ユーザーに頼んだのはログインだけ）
- [ ] 本文の「# 動作確認」に入れ、コメントは送信していない（コメント欄も空に戻した）
- [ ] PR 画面で画像が表示されることを確かめた
- [ ] 一時ファイルとビルドの副産物を片付けた
