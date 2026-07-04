#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <existing-branch> [destination]" >&2
  exit 2
}

open_in_vscode() {
  local path=$1

  if [[ "${WORKTREE_SKIP_VSCODE:-0}" == "1" ]]; then
    echo "EDITOR_STATUS=skipped"
    return 0
  fi

  if command -v code >/dev/null 2>&1; then
    if code "$path"; then
      echo "EDITOR_STATUS=opened"
      return 0
    fi
  elif [[ "$(uname -s)" == "Darwin" ]] && command -v open >/dev/null 2>&1; then
    if open -a "Visual Studio Code" "$path"; then
      echo "EDITOR_STATUS=opened"
      return 0
    fi
  fi

  echo "EDITOR_STATUS=failed" >&2
  echo "VS Code could not be opened. Run: code \"$path\"" >&2
  return 3
}

[[ $# -ge 1 && $# -le 2 ]] || usage

branch=$1
destination=${2:-}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Not inside a Git worktree." >&2
  exit 2
}

main_root=$(git worktree list --porcelain | awk '
  $1 == "worktree" {
    print substr($0, 10)
    exit
  }
')

[[ -n "$main_root" ]] || {
  echo "Could not determine the main worktree." >&2
  exit 2
}

main_root=$(cd "$main_root" && pwd -P)
current_root=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)

git -C "$main_root" check-ref-format --branch "$branch" >/dev/null

# 同じブランチが別のworktreeにあれば再利用し、現在のworktreeなら後で移動する。
existing_path=$(git -C "$main_root" worktree list --porcelain | awk -v wanted="refs/heads/$branch" '
  $1 == "worktree" { path = substr($0, 10) }
  $1 == "branch" && $2 == wanted {
    print path
    exit
  }
')

if [[ -n "$existing_path" ]]; then
  existing_path=$(cd "$existing_path" && pwd -P)
  if [[ "$existing_path" != "$current_root" ]]; then
    echo "WORKTREE_STATUS=existing"
    echo "WORKTREE_PATH=$existing_path"
    open_in_vscode "$existing_path"
    exit $?
  fi
fi

if [[ -z "$destination" ]]; then
  repo_name=$(basename "$main_root")
  short_name=${branch//\//-}
  destination="$(dirname "$main_root")/${repo_name}-worktrees/$short_name"
elif [[ "$destination" != /* ]]; then
  destination="$main_root/$destination"
fi

if [[ -e "$destination" ]]; then
  echo "Destination already exists and is not the target branch's registered worktree: $destination" >&2
  exit 2
fi

mkdir -p "$(dirname "$destination")"

source_status="unchanged"
relocated_current=0
stash_commit=""
stash_status="none"

branch_is_checked_out() {
  local candidate=$1
  git -C "$main_root" worktree list --porcelain | awk -v wanted="refs/heads/$candidate" '
    $1 == "branch" && $2 == wanted { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

find_fallback_branch() {
  local remote_default candidate seen=" "
  remote_default=$(git -C "$main_root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  remote_default=${remote_default#origin/}

  for candidate in "$remote_default" main develop master; do
    [[ -n "$candidate" && "$candidate" != "$branch" ]] || continue
    [[ "$seen" != *" $candidate "* ]] || continue
    seen+="$candidate "
    git -C "$main_root" show-ref --verify --quiet "refs/heads/$candidate" || continue
    branch_is_checked_out "$candidate" && continue
    echo "$candidate"
    return 0
  done

  return 1
}

find_stash_selector() {
  git -C "$main_root" stash list --format='%gd %H' | awk -v commit="$stash_commit" '
    $2 == commit {
      print $1
      exit
    }
  '
}

apply_and_drop_stash() {
  local target=$1 selector

  [[ -n "$stash_commit" ]] || return 0

  if ! git -C "$target" stash apply --index "$stash_commit"; then
    stash_status="conflict-retained"
    echo "Stashed changes could not be applied cleanly. Resolve conflicts in: $target" >&2
    echo "The stash was retained: $stash_commit" >&2
    return 1
  fi

  selector=$(find_stash_selector)
  if [[ -n "$selector" ]] && git -C "$main_root" stash drop "$selector" >/dev/null; then
    stash_status="applied"
  else
    stash_status="applied-retained"
    echo "Changes were applied, but the temporary stash could not be removed: $stash_commit" >&2
  fi

  return 0
}

restore_source_state() {
  local failed=0

  if [[ $relocated_current -eq 1 ]]; then
    git -C "$current_root" switch "$branch" >/dev/null 2>&1 || {
      echo "Failed to restore source worktree to branch: $branch" >&2
      failed=1
    }
  fi

  if [[ -n "$stash_commit" && $failed -eq 0 ]]; then
    apply_and_drop_stash "$current_root" || failed=1
  fi

  return "$failed"
}

if [[ -n "$existing_path" && "$existing_path" == "$current_root" ]]; then
  if [[ -n "$(git -C "$current_root" status --porcelain --untracked-files=normal)" ]]; then
    stash_message="create-branch-worktree:$branch:$(date -u +%Y%m%dT%H%M%SZ)"
    git -C "$current_root" stash push --include-untracked --message "$stash_message" >/dev/null
    stash_commit=$(git -C "$main_root" rev-parse --verify refs/stash)
    stash_status="created"

    if [[ -n "$(git -C "$current_root" status --porcelain --untracked-files=normal)" ]]; then
      echo "Not all changes could be stashed safely; restoring the source worktree." >&2
      apply_and_drop_stash "$current_root" || true
      exit 2
    fi
  fi

  fallback_branch=$(find_fallback_branch || true)
  if [[ -n "$fallback_branch" ]]; then
    if ! git -C "$current_root" switch "$fallback_branch"; then
      apply_and_drop_stash "$current_root" || true
      exit 1
    fi
    source_status="switched:$fallback_branch"
  else
    if ! git -C "$current_root" switch --detach; then
      apply_and_drop_stash "$current_root" || true
      exit 1
    fi
    source_status="detached"
  fi
  relocated_current=1
fi

if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"; then
  if ! git -C "$main_root" worktree add "$destination" "$branch"; then
    restore_source_state || true
    exit 1
  fi
else
  remote_refs=()
  while IFS= read -r ref; do
    [[ -n "$ref" && "$ref" != */HEAD ]] && remote_refs+=("$ref")
  done < <(git -C "$main_root" for-each-ref --format='%(refname)' "refs/remotes/*/$branch")

  if [[ ${#remote_refs[@]} -eq 0 ]]; then
    echo "Existing branch not found locally or in remote-tracking refs: $branch" >&2
    exit 2
  fi

  if [[ ${#remote_refs[@]} -gt 1 ]]; then
    echo "Branch exists on multiple remotes; specify or prepare the intended local branch first:" >&2
    printf '  %s\n' "${remote_refs[@]#refs/remotes/}" >&2
    exit 2
  fi

  remote_branch=${remote_refs[0]#refs/remotes/}
  git -C "$main_root" worktree add --track -b "$branch" "$destination" "$remote_branch"
fi

stash_transfer_failed=0
if ! apply_and_drop_stash "$destination"; then
  stash_transfer_failed=1
fi

echo "WORKTREE_STATUS=created"
echo "WORKTREE_PATH=$destination"
echo "SOURCE_WORKTREE_STATUS=$source_status"
echo "STASH_STATUS=$stash_status"

editor_failed=0
open_in_vscode "$destination" || editor_failed=$?

[[ $stash_transfer_failed -eq 0 ]] || exit 1
[[ $editor_failed -eq 0 ]] || exit "$editor_failed"
