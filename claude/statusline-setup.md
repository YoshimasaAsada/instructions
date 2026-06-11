# Claude Code ステータスライン設定

コンテキストウィンドウ・5時間制限・7日制限をプログレスバーで1行表示する設定。

## 作成ファイル

### `~/.claude/statusline.sh`

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
FH_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; CYAN='\033[36m'; DIM='\033[2m'; RESET='\033[0m'

make_bar() {
    local pct="$1"
    local width=10
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar=""
    [ "$filled" -gt 0 ] && printf -v f "%${filled}s" && bar="${f// /▓}"
    [ "$empty" -gt 0 ] && printf -v e "%${empty}s" && bar="${bar}${e// /░}"
    echo "$bar"
}

bar_color() {
    local pct="$1"
    if [ "$pct" -ge 90 ]; then echo "$RED"
    elif [ "$pct" -ge 70 ]; then echo "$YELLOW"
    else echo "$GREEN"
    fi
}

CTX_BAR=$(make_bar "$CTX_PCT")
CTX_COLOR=$(bar_color "$CTX_PCT")

LINE="${CYAN}[$MODEL]${RESET}  ${DIM}ctx${RESET} ${CTX_COLOR}${CTX_BAR}${RESET} ${CTX_PCT}%"

if [ -n "$FIVE_H" ] || [ -n "$WEEK" ]; then
    FH_INT=0
    WK_INT=0
    [ -n "$FIVE_H" ] && FH_INT=$(printf '%.0f' "$FIVE_H")
    [ -n "$WEEK" ] && WK_INT=$(printf '%.0f' "$WEEK")

    FH_BAR=$(make_bar "$FH_INT")
    WK_BAR=$(make_bar "$WK_INT")
    FH_COLOR=$(bar_color "$FH_INT")
    WK_COLOR=$(bar_color "$WK_INT")

    FH_TIME=""
    WK_TIME=""
    [ -n "$FH_RESET" ] && FH_TIME=" $(TZ='Asia/Tokyo' date -r "$FH_RESET" +'↺%H:%M')"
    [ -n "$WK_RESET" ] && WK_TIME=" $(TZ='Asia/Tokyo' date -r "$WK_RESET" +'↺%m/%d')"

    LINE="${LINE}  ${DIM}5h${RESET} ${FH_COLOR}${FH_BAR}${RESET} ${FH_INT}%${DIM}${FH_TIME}${RESET}  ${DIM}7d${RESET} ${WK_COLOR}${WK_BAR}${RESET} ${WK_INT}%${DIM}${WK_TIME}${RESET}"
fi

printf '%b\n' "$LINE"
```

```bash
chmod +x ~/.claude/statusline.sh
```

### `~/.claude/settings.json` に追加

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

## 表示例

```
[Sonnet]  ctx ▓▓▓░░░░░░░ 35%  5h ▓▓░░░░░░░░ 24% ↺17:40  7d ▓▓▓▓░░░░░░ 41% ↺05/25
```

| セグメント | データソース | 説明 |
|---|---|---|
| `ctx` | `context_window.used_percentage` | 現在のコンテキストウィンドウ使用率 |
| `5h` | `rate_limits.five_hour.used_percentage` | 5時間ローリングウィンドウのレート制限使用率 |
| `↺HH:MM` | `rate_limits.five_hour.resets_at` | 5時間制限のリセット時刻（JST） |
| `7d` | `rate_limits.seven_day.used_percentage` | 7日間のレート制限使用率 |
| `↺MM/DD` | `rate_limits.seven_day.resets_at` | 7日間制限のリセット日（JST） |

## 色の閾値

| 色 | 条件 |
|---|---|
| 緑 | 70%未満 |
| 黄 | 70〜89% |
| 赤 | 90%以上 |

## 注意事項

- `rate_limits` フィールドはPro/Maxサブスクライバーかつ初回APIレスポンス後から取得可能。それまでは `ctx` のみ表示される
- `jq` が必要（未インストールの場合は `brew install jq`）
- 参考: https://code.claude.com/docs/ja/statusline
