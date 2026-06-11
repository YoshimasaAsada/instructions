#!/usr/bin/env bash
# spec-to-code エージェントチームパイプライン
# 使い方: ./pipeline.sh <requirements.txt> [--name NAME] [--min-loops N] [--max-loops N] [--output-dir DIR] [--target-dir DIR] [--verify-cmd CMD]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$SCRIPT_DIR/roles"

# --- デフォルト値 ---
NAME="feature"
MIN_LOOPS=2
MAX_LOOPS=3
OUTPUT_DIR="./output"
TARGET_DIR="."
VERIFY_CMD="auto"
REQUIREMENTS_FILE=""

# --- 引数パース ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)       NAME="$2";        shift 2 ;;
    --min-loops)  MIN_LOOPS="$2";   shift 2 ;;
    --max-loops)  MAX_LOOPS="$2";   shift 2 ;;
    --output-dir) OUTPUT_DIR="$2";  shift 2 ;;
    --target-dir) TARGET_DIR="$2";  shift 2 ;;
    --verify-cmd) VERIFY_CMD="$2";  shift 2 ;;
    -*)           echo "Unknown option: $1" >&2; exit 2 ;;
    *)            REQUIREMENTS_FILE="$1"; shift ;;
  esac
done

if [[ -z "$REQUIREMENTS_FILE" ]]; then
  echo "Error: requirements ファイルを指定してください。" >&2
  echo "使い方: $0 <requirements.txt> [--name NAME] [--min-loops N] [--max-loops N] [--verify-cmd CMD]" >&2
  exit 2
fi

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  echo "Error: ファイルが見つかりません: $REQUIREMENTS_FILE" >&2
  exit 2
fi

if ! [[ "$MIN_LOOPS" =~ ^[0-9]+$ && "$MAX_LOOPS" =~ ^[0-9]+$ ]]; then
  echo "Error: --min-loops と --max-loops は数値で指定してください。" >&2
  exit 2
fi

if (( MIN_LOOPS > MAX_LOOPS )); then
  echo "Error: --min-loops は --max-loops 以下にしてください。" >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"

REQUIREMENTS_FILE="$(cd "$(dirname "$REQUIREMENTS_FILE")" && pwd)/$(basename "$REQUIREMENTS_FILE")"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# オーケストレーター（Claude）を起動し、対象リポジトリ内で実装・検証・レビュー修正を反復させる
cd "$TARGET_DIR"
claude -p \
  --add-dir "$OUTPUT_DIR" \
  --allowedTools "Agent,Task,TodoWrite,Read,Write,Edit,MultiEdit,Bash,Grep,Glob,LS" \
  "$(cat "$ROLES_DIR/orchestrator.md")

# 設定

- 成果物プレフィックス（{name}）: $NAME
- 最低実装レビュー反復回数（{min_loops}）: $MIN_LOOPS
- 最大ループ回数（{max_loops}）: $MAX_LOOPS
- 出力ディレクトリ（{output_dir}）: $OUTPUT_DIR
- 実装対象ディレクトリ: $TARGET_DIR
- 検証コマンド（{verify_cmd}）: $VERIFY_CMD

# チームメンバーの役割定義

## PM

$(cat "$ROLES_DIR/pm.md")

## Tech Lead

$(cat "$ROLES_DIR/tech-lead.md")

## Backend Engineer

$(cat "$ROLES_DIR/backend-engineer.md")

## Frontend Engineer

$(cat "$ROLES_DIR/frontend-engineer.md")

## QA Engineer

$(cat "$ROLES_DIR/qa-engineer.md")

## Security Reviewer

$(cat "$ROLES_DIR/security-reviewer.md")

## Code Reviewer

$(cat "$ROLES_DIR/code-reviewer.md")

# 要件

$(cat "$REQUIREMENTS_FILE")"

SUMMARY_FILE="$OUTPUT_DIR/${NAME}.summary.md"
if [[ -f "$SUMMARY_FILE" ]] && grep -q "ステータス: INCOMPLETE" "$SUMMARY_FILE"; then
  exit 1
fi
