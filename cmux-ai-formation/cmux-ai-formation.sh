#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./cmux-ai-formation.sh [project_dir] [--agent codex|claude] [--title TITLE]

Examples:
  ./cmux-ai-formation.sh
  ./cmux-ai-formation.sh ~/develop/my-app
  ./cmux-ai-formation.sh . --agent claude --title "fix-login"

Layout:
  top-left:     Yazi
  top-right:    lazygit
  left-middle:  mo browser
  bottom:       Codex / Claude Code
USAGE
}

missing_commands=()

has_command() {
  command -v "$1" >/dev/null 2>&1
}

collect_missing() {
  local command_name
  for command_name in "$@"; do
    if ! has_command "$command_name"; then
      missing_commands+=("$command_name")
    fi
  done
}

print_install_guidance() {
  local brew_packages=()
  local manual_items=()
  local command_name

  for command_name in "${missing_commands[@]}"; do
    case "$command_name" in
      jq)
        brew_packages+=("jq")
        ;;
      mo)
        brew_packages+=("k1LoW/tap/mo")
        ;;
      yazi)
        brew_packages+=("yazi")
        ;;
      lazygit)
        brew_packages+=("lazygit")
        ;;
      delta)
        brew_packages+=("git-delta")
        ;;
      cmux|codex|claude)
        manual_items+=("$command_name")
        ;;
      *)
        manual_items+=("$command_name")
        ;;
    esac
  done

  echo "Missing required tools:" >&2
  printf '  - %s\n' "${missing_commands[@]}" >&2
  echo >&2

  if [[ ${#brew_packages[@]} -gt 0 ]]; then
    echo "Install Homebrew-managed tools with:" >&2
    printf '  brew install' >&2
    printf ' %s' "${brew_packages[@]}" >&2
    printf '\n\n' >&2
  fi

  if [[ ${#manual_items[@]} -gt 0 ]]; then
    echo "Install or configure these manually:" >&2
    for command_name in "${manual_items[@]}"; do
      case "$command_name" in
        cmux)
          echo "  - cmux: install CMUX and make sure the cmux CLI is on PATH" >&2
          ;;
        codex)
          echo "  - codex: install and authenticate OpenAI Codex CLI" >&2
          ;;
        claude)
          echo "  - claude: install and authenticate Claude Code CLI" >&2
          ;;
        *)
          echo "  - $command_name" >&2
          ;;
      esac
    done
    echo >&2
  fi

  echo "After installation, run this script again." >&2
}

parse_ref() {
  # Input examples:
  #   OK surface:43 pane:20 workspace:9
  #   OK workspace:9
  local key="$1"
  awk -v key="$key" '{
    for (i = 1; i <= NF; i++) {
      if ($i ~ "^" key ":[0-9]+$") {
        print $i
        exit
      }
    }
  }'
}

json_for_workspace() {
  local workspace="$1"
  cmux tree --workspace "$workspace" --json
}

first_surface_ref() {
  local workspace="$1"
  json_for_workspace "$workspace" | jq -r --arg ws "$workspace" '
    .windows[].workspaces[]
    | select(.ref == $ws)
    | .panes[0].selected_surface_ref
  '
}

surface_refs() {
  local workspace="$1"
  json_for_workspace "$workspace" | jq -r --arg ws "$workspace" '
    .windows[].workspaces[]
    | select(.ref == $ws)
    | .panes[].surfaces[].ref
  '
}

pane_for_surface() {
  local workspace="$1"
  local surface="$2"
  json_for_workspace "$workspace" | jq -r --arg ws "$workspace" --arg surface "$surface" '
    .windows[].workspaces[]
    | select(.ref == $ws)
    | .panes[]
    | select(.surfaces[].ref == $surface)
    | .ref
  ' | head -n 1
}

new_surface_after() {
  local workspace="$1"
  local before_file="$2"

  surface_refs "$workspace" | grep -vxFf "$before_file" | head -n 1
}

wait_for_cmux() {
  local i
  for i in $(seq 1 30); do
    if cmux ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  echo "CMUX socket did not become ready." >&2
  exit 1
}

send_line() {
  local workspace="$1"
  local surface="$2"
  local text="$3"

  cmux send --workspace "$workspace" --surface "$surface" "$text" >/dev/null
  cmux send-key --workspace "$workspace" --surface "$surface" Enter >/dev/null
}

project_dir="${1:-$PWD}"
agent="codex"
title=""

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" != "" && "${1:-}" != --* ]]; then
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      agent="${2:-}"
      shift 2
      ;;
    --title)
      title="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

project_dir="$(cd "$project_dir" && pwd)"
project_name="$(basename "$project_dir")"
title="${title:-AI: $project_name}"

if [[ "$agent" != "codex" && "$agent" != "claude" ]]; then
  echo "--agent must be codex or claude" >&2
  exit 1
fi

collect_missing cmux jq mo yazi lazygit "$agent"

if [[ ${#missing_commands[@]} -gt 0 ]]; then
  print_install_guidance
  exit 1
fi

open -a cmux >/dev/null 2>&1 || true
wait_for_cmux

if cmux list-windows 2>/dev/null | grep -q '^No windows$'; then
  cmux new-window >/dev/null
fi

mo -wR "$project_dir" --no-open >/dev/null

workspace_out="$(cmux new-workspace --cwd "$project_dir")"
workspace="$(printf '%s\n' "$workspace_out" | parse_ref workspace)"

if [[ -z "$workspace" ]]; then
  echo "Failed to create CMUX workspace: $workspace_out" >&2
  exit 1
fi

cmux rename-workspace --workspace "$workspace" "$title" >/dev/null

yazi_surface="$(first_surface_ref "$workspace")"
if [[ -z "$yazi_surface" || "$yazi_surface" == "null" ]]; then
  echo "Failed to locate initial CMUX surface." >&2
  exit 1
fi

before_surfaces="$(mktemp /private/tmp/cmux-ai-formation-before.XXXXXX)"
surface_refs "$workspace" > "$before_surfaces"
cmux new-split down --workspace "$workspace" --surface "$yazi_surface" >/dev/null
ai_surface="$(new_surface_after "$workspace" "$before_surfaces")"

surface_refs "$workspace" > "$before_surfaces"
cmux new-split right --workspace "$workspace" --surface "$yazi_surface" >/dev/null
lazygit_surface="$(new_surface_after "$workspace" "$before_surfaces")"
lazygit_pane="$(pane_for_surface "$workspace" "$lazygit_surface")"
yazi_pane="$(pane_for_surface "$workspace" "$yazi_surface")"

if [[ -z "$ai_surface" || -z "$lazygit_surface" || -z "$lazygit_pane" || -z "$yazi_pane" ]]; then
  echo "Failed to create CMUX terminal panes." >&2
  cmux tree --workspace "$workspace" >&2 || true
  exit 1
fi

cmux focus-pane --workspace "$workspace" --pane "$yazi_pane" >/dev/null
surface_refs "$workspace" > "$before_surfaces"
cmux new-pane --type browser --direction down --workspace "$workspace" --url http://localhost:6275 >/dev/null
browser_surface="$(new_surface_after "$workspace" "$before_surfaces")"
rm -f "$before_surfaces"

if [[ -z "$browser_surface" ]]; then
  echo "Failed to create CMUX browser pane." >&2
  cmux tree --workspace "$workspace" >&2 || true
  exit 1
fi

send_line "$workspace" "$yazi_surface" "yazi '$project_dir'"
send_line "$workspace" "$lazygit_surface" "lazygit"
send_line "$workspace" "$ai_surface" "$agent"

cmux focus-pane --workspace "$workspace" --pane "$(pane_for_surface "$workspace" "$ai_surface")" >/dev/null

cat <<EOF
Created CMUX AI coding formation.

Workspace: $workspace
Title:     $title
Project:   $project_dir
Agent:     $agent
Preview:   http://localhost:6275

Layout:
  top-left:     yazi
  top-right:    lazygit
  left-middle:  mo browser
  bottom:       $agent
EOF
