# AI Instructions Repository

AIへの指示書（プロンプト・ガイドライン）を一元管理するリポジトリです。

## 運用ルール

- 指示書は用途別にディレクトリを分けて管理する
- ファイル名は用途がわかる英語名（例: `review.md`, `refactor.md`）
- 「コミットして」と依頼すると、Claude が変更内容を解析し、このREADMEのインデックスを更新した上でコミットを作成する

## ディレクトリ構成

```
instructions/
├── README.md                    # このファイル（インデックス）
├── CLAUDE.md                    # Claude Code 向け運用ルール
├── utils/                       # 汎用指示書
├── claude/                      # Claude Code 固有の指示書
├── skills/                      # Claude Code カスタムスキル原本（~/.claude/skills/ のミラー）
├── spec-to-code/                # 自動開発パイプライン
├── claude-code-feature-harness/ # 対話型機能開発ハーネス
└── cmux-ai-formation/           # CMUX 作業環境構築
```

## カスタムスキルの利用（他PCでの再現）

`skills/` には Claude Code のカスタムスキル（`~/.claude/skills/` の内容）を原本のままミラーしています。
別のPCで同じスキルを使うには、clone 後に各スキルを `~/.claude/skills/` へ配置します。

```bash
# コピーする場合
cp -R skills/* ~/.claude/skills/

# もしくは symlink で常に最新へ追従させる場合（例）
for s in skills/*/; do ln -sfn "$(pwd)/$s" ~/.claude/skills/"$(basename "$s")"; done
```

スキルをローカルで更新したら `skills/` 側へ反映し、`diff -r ~/.claude/skills/<name> skills/<name>` が空（完全一致）であることを確認してからコミットします。

## Index

<!-- INDEX_START -->
### ルート/（共通）

| ファイル | 説明 |
|----------|------|
| [base-CLAUDE.md](base-CLAUDE.md) | 各プロジェクトへ `CLAUDE.md` を導入するためのベーステンプレートと運用ルール集 |

### skills/（Claude Code カスタムスキル原本）

| ファイル | 説明 |
|----------|------|
| [skills/clean-commits/SKILL.md](skills/clean-commits/SKILL.md) | フィーチャーブランチのコミットをレイヤー×機能領域で分割し既存scope慣習に沿ってsquash・force pushするスキル |
| [skills/create-branch-worktree/SKILL.md](skills/create-branch-worktree/SKILL.md) | 既存ブランチのworktreeを安全に作成または再利用し、Visual Studio Codeで開くスキル |
| [skills/design-doc/SKILL.md](skills/design-doc/SKILL.md) | 要件定義書と既存コードをもとに実装可能な技術設計書を自律的に作成・更新するスキル |
| [skills/requirements-definition/SKILL.md](skills/requirements-definition/SKILL.md) | コードで裏取りし確認事項を既定案付きで列挙する正式な要件定義書を作成するスキル |
| [skills/requirements-definition/template.md](skills/requirements-definition/template.md) | requirements-definition スキルが使う要件定義書テンプレート |
| [skills/requirements-definition-draft/SKILL.md](skills/requirements-definition-draft/SKILL.md) | 雑な依頼やSlackメモを壁打ちしながら要件整理メモに分解するスキル |
| [skills/task-breakdown/SKILL.md](skills/task-breakdown/SKILL.md) | 技術設計書を依存関係順の検証可能な実装タスクリストへ自律的に分解するスキル |

### spec-to-code/（AI自動開発パイプライン）

| ファイル | 説明 |
|----------|------|
| [spec-to-code/create-spec.md](spec-to-code/create-spec.md) | 要件テキストから固定フォーマットの仕様書を生成する指示書 |
| [spec-to-code/review-spec.md](spec-to-code/review-spec.md) | 仕様書をレビューしVERDICT自動判定ブロック付きの指摘レポートを生成する指示書 |
| [spec-to-code/fix-spec-from-review.md](spec-to-code/fix-spec-from-review.md) | レビュー指摘を仕様書に反映して修正する指示書 |
| [spec-to-code/scaffold-from-spec.md](spec-to-code/scaffold-from-spec.md) | 設計書（spec.md）に沿って実装順序どおりに雛形コードを生成する指示書 |
| [spec-to-code/roles/orchestrator.md](spec-to-code/roles/orchestrator.md) | PRD作成から実装・検証・レビュー修正までを統括するオーケストレーター定義 |
| [spec-to-code/roles/pm.md](spec-to-code/roles/pm.md) | 要件テキストから検証可能なPRDを作成するProduct Managerロール |
| [spec-to-code/roles/tech-lead.md](spec-to-code/roles/tech-lead.md) | PRDの実現可能性をレビューしてアーキテクチャを設計するTech Leadロール |
| [spec-to-code/roles/backend-engineer.md](spec-to-code/roles/backend-engineer.md) | API・DB・ビジネスロジックを実ファイルへ実装するBackend Engineerロール |
| [spec-to-code/roles/frontend-engineer.md](spec-to-code/roles/frontend-engineer.md) | UI・状態管理・API連携を実ファイルへ実装するFrontend Engineerロール |
| [spec-to-code/roles/qa-engineer.md](spec-to-code/roles/qa-engineer.md) | 受け入れ条件のテスト追加とカバレッジ判定を行うQA Engineerロール |
| [spec-to-code/roles/security-reviewer.md](spec-to-code/roles/security-reviewer.md) | OWASP Top 10を中心に実装差分を評価するSecurity Reviewerロール |
| [spec-to-code/roles/code-reviewer.md](spec-to-code/roles/code-reviewer.md) | 検証・QA・セキュリティ結果を含めて総合判定するCode Reviewerロール |

### claude-code-feature-harness/（対話型機能開発）

| ファイル | 説明 |
|----------|------|
| [claude-code-feature-harness/skills/develop-feature/SKILL.md](claude-code-feature-harness/skills/develop-feature/SKILL.md) | Slackから手動貼り付けした要望を要件・設計・タスク・実装へ進めるClaude Code Skill |
| [claude-code-feature-harness/skills/develop-feature/workflow.md](claude-code-feature-harness/skills/develop-feature/workflow.md) | 各文書のレビュー反復、承認ゲート、実装までの状態遷移を定義するワークフロー |
| [claude-code-feature-harness/skills/resume-feature/SKILL.md](claude-code-feature-harness/skills/resume-feature/SKILL.md) | 保存された状態と成果物から機能開発ハーネスを再開するClaude Code Skill |
| [claude-code-feature-harness/agents/requirements-analyst.md](claude-code-feature-harness/agents/requirements-analyst.md) | 要望と指摘から検証可能な要件定義書を作成・修正するサブエージェント |
| [claude-code-feature-harness/agents/requirements-reviewer.md](claude-code-feature-harness/agents/requirements-reviewer.md) | 要件の矛盾・漏れ・曖昧さ・検証可能性を独立評価するサブエージェント |
| [claude-code-feature-harness/agents/system-designer.md](claude-code-feature-harness/agents/system-designer.md) | 承認済み要件と既存コードから技術設計を作成・修正するサブエージェント |
| [claude-code-feature-harness/agents/design-reviewer.md](claude-code-feature-harness/agents/design-reviewer.md) | 技術設計を要件とリポジトリ制約に照らして独立評価するサブエージェント |
| [claude-code-feature-harness/agents/task-planner.md](claude-code-feature-harness/agents/task-planner.md) | 承認済み要件・設計から依存関係順の実装タスクを作るサブエージェント |
| [claude-code-feature-harness/agents/task-reviewer.md](claude-code-feature-harness/agents/task-reviewer.md) | タスクの網羅性・順序・実現可能性・検証可能性を独立評価するサブエージェント |
| [claude-code-feature-harness/agents/implementation-engineer.md](claude-code-feature-harness/agents/implementation-engineer.md) | 人間承認後にタスクを実装しテスト・検証するサブエージェント |

### utils/（汎用）

| ファイル | 説明 |
|----------|------|
| [utils/clean-commits.md](utils/clean-commits.md) | 差分同一性を保証しながらコミット履歴を安全に整理する指示書 |
| [utils/create-adr.md](utils/create-adr.md) | 技術的意思決定をADR形式で背景・選択肢・理由とともに記録する指示書 |
| [utils/create-docs.md](utils/create-docs.md) | 未確定事項確認と根拠明記を徹底し、要件定義書・設計書・タスクリストを生成する指示書 |
| [utils/create-onboarding.md](utils/create-onboarding.md) | コードベース調査をもとに新メンバー向けオンボーディングガイドを作成する指示書 |
| [utils/create-pr.md](utils/create-pr.md) | 差分とコミット履歴からPR説明文を構造化して生成する指示書 |
| [utils/create-test-code.md](utils/create-test-code.md) | 仕様ベースでテスト観点を抽出し壊れにくいテストコードを作成する指示書 |
| [utils/debug.md](utils/debug.md) | エラーログと再現手順から原因分析・修正案・再発防止策を提示する指示書 |
| [utils/fix-from-review.md](utils/fix-from-review.md) | レビュー指摘を分類して要件定義書・設計書・タスクリストへ反映する指示書 |
| [utils/generate-tests.md](utils/generate-tests.md) | 正常系・境界値・異常系を網羅したテストケースとテストコードを生成する指示書 |
| [utils/impact-analysis.md](utils/impact-analysis.md) | 変更対象の直接・間接依存を追跡して影響マップを作成する指示書 |
| [utils/migration-safety.md](utils/migration-safety.md) | DBマイグレーションのリスク評価と実行計画・ロールバック計画を作成する指示書 |
| [utils/refactor.md](utils/refactor.md) | 振る舞いを変えずに責務分離・重複排除・可読性改善を進める指示書 |
| [utils/review.md](utils/review.md) | 根拠コードを添えて優先度別に指摘するCTO視点のコードレビュー指示書 |
| [utils/review-loop.md](utils/review-loop.md) | レビュー→修正→再レビューを指摘ゼロまで反復するワンストップ指示書 |

### claude/（Claude Code 固有）

| ファイル | 説明 |
|----------|------|
| [claude/create-docs.md](claude/create-docs.md) | Exploreエージェントを活用して要件定義・設計書・タスクリストを作成する指示書 |
| [claude/fix-from-review.md](claude/fix-from-review.md) | review結果を3文書に反映するClaude Code向けレビュー修正ワークフロー指示書 |
| [claude/statusline-setup.md](claude/statusline-setup.md) | コンテキストと5時間・7日制限をプログレスバー表示するステータスライン設定 |

### cmux-ai-formation/（CMUX作業環境）

| ファイル | 説明 |
|----------|------|
| [cmux-ai-formation/cmux-ai-coding-formation-instructions.md](cmux-ai-formation/cmux-ai-coding-formation-instructions.md) | CMUX上へAI・Git・ファイル・Markdown確認ペインを配置する運用手順 |
| [cmux-ai-formation/cmux-ai-coding-tools.md](cmux-ai-formation/cmux-ai-coding-tools.md) | CMUXを中心としたAIコーディング環境の推奨ツールと設定一覧 |
<!-- INDEX_END -->
