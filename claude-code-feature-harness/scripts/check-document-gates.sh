#!/usr/bin/env bash

set -euo pipefail

if (( $# != 1 )); then
  echo "Usage: $0 <feature-directory>" >&2
  exit 2
fi

feature_dir=$1
history_dir="$feature_dir/history"

fail() {
  echo "Gate failed: $*" >&2
  exit 1
}

[[ -d "$feature_dir" ]] || fail "feature directory does not exist: $feature_dir"
[[ -d "$history_dir" ]] || fail "history directory does not exist: $history_dir"

for artifact in request.md requirements.md design.md tasks.md status.md; do
  [[ -s "$feature_dir/$artifact" ]] || fail "missing or empty artifact: $artifact"
done

latest_review() {
  local phase=$1
  local latest

  latest=$(
    find "$history_dir" -maxdepth 1 -type f \
      -name "${phase}-review-v*.md" -print \
      | sort -V \
      | tail -n 1
  )

  [[ -n "$latest" ]] || fail "no ${phase} review found"
  printf '%s\n' "$latest"
}

check_review() {
  local phase=$1
  local review

  review=$(latest_review "$phase")

  grep -qx 'VERDICT: APPROVED' "$review" \
    || fail "latest ${phase} review is not approved: $review"
  grep -qx 'FINDINGS: 0' "$review" \
    || fail "latest ${phase} review still has findings: $review"
  grep -qx 'USER_INPUT_REQUIRED: 0' "$review" \
    || fail "latest ${phase} review still requires user input: $review"

  echo "Gate passed: $phase ($review)"
}

check_review requirements
check_review design
check_review tasks

echo "All document gates passed for: $feature_dir"
