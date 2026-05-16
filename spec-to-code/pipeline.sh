#!/usr/bin/env bash
# AI自動開発パイプライン
# 使い方: ./pipeline.sh <requirements.txt> [--name NAME] [--max-loops N] [--output-dir DIR] [--target-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- デフォルト値 ---
NAME="feature"
MAX_LOOPS=3
OUTPUT_DIR="./output"
TARGET_DIR="."
REQUIREMENTS_FILE=""

# --- 引数パース ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)       NAME="$2";        shift 2 ;;
    --max-loops)  MAX_LOOPS="$2";   shift 2 ;;
    --output-dir) OUTPUT_DIR="$2";  shift 2 ;;
    --target-dir) TARGET_DIR="$2";  shift 2 ;;
    -*)           echo "Unknown option: $1" >&2; exit 2 ;;
    *)            REQUIREMENTS_FILE="$1"; shift ;;
  esac
done

if [[ -z "$REQUIREMENTS_FILE" ]]; then
  echo "Error: requirements ファイルを指定してください。" >&2
  echo "使い方: $0 <requirements.txt> [--name NAME] [--max-loops N]" >&2
  exit 2
fi

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  echo "Error: ファイルが見つかりません: $REQUIREMENTS_FILE" >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"

SPEC_FILE="$OUTPUT_DIR/${NAME}.spec.md"
REVIEW_FILE="$OUTPUT_DIR/${NAME}.review.md"

log() { echo "[pipeline] $*"; }

# -------------------------------------------------------------------
# Phase 1: 仕様書作成
# -------------------------------------------------------------------
log "Phase 1: 仕様書を作成しています..."

claude -p "$(cat "$SCRIPT_DIR/create-spec.md")

# 要件

$(cat "$REQUIREMENTS_FILE")" > "$SPEC_FILE"

log "仕様書を生成しました: $SPEC_FILE"

# -------------------------------------------------------------------
# Phase 2-3: レビュー → 修正ループ
# -------------------------------------------------------------------
LOOP=0
while [[ $LOOP -lt $MAX_LOOPS ]]; do
  LOOP=$((LOOP + 1))
  log "Phase 2: レビュー実行中... (ループ $LOOP/$MAX_LOOPS)"

  claude -p "$(cat "$SCRIPT_DIR/review-spec.md")

# レビュー対象仕様書

$(cat "$SPEC_FILE")" > "$REVIEW_FILE"

  # VERDICT を抽出
  VERDICT=$(grep -m1 "^VERDICT:" "$REVIEW_FILE" | awk '{print $2}' || true)

  if [[ "$VERDICT" == "APPROVED" ]]; then
    log "レビュー承認: APPROVED"
    break
  fi

  if [[ $LOOP -ge $MAX_LOOPS ]]; then
    log "警告: 最大ループ回数 ($MAX_LOOPS) に達しました。残存指摘が残っています。"
    echo ""
    echo "--- 残存指摘 ---"
    grep -A1 "指摘件数:" "$REVIEW_FILE" || true
    exit 1
  fi

  log "Phase 3: 仕様書を修正しています... (ループ $LOOP)"

  REVISED=$(claude -p "$(cat "$SCRIPT_DIR/fix-spec-from-review.md")

# 現在の仕様書

$(cat "$SPEC_FILE")

# レビュー結果

$(cat "$REVIEW_FILE")")

  echo "$REVISED" > "$SPEC_FILE"
  log "仕様書を更新しました: $SPEC_FILE"
done

# -------------------------------------------------------------------
# Phase 4: 実装
# -------------------------------------------------------------------
log "Phase 4: 実装を開始しています..."

cd "$TARGET_DIR"
claude -p "$(cat "$SCRIPT_DIR/scaffold-from-spec.md")

# 仕様書

$(cat "$SPEC_FILE")"

log "完了しました。"
log "  仕様書:       $SPEC_FILE"
log "  レビュー結果: $REVIEW_FILE"
log "  実装先:       $TARGET_DIR"
