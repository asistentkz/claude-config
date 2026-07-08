#!/bin/bash
# Claude Code statusline — модель сессии + режим architect (Fable/Opus) + лимит 5h.
# НЕ синкается автоматически (sync.sh settings/statusline не трогает).
# Включить вручную: в ~/.claude/settings.json добавить
#   "statusLine": { "type": "command", "command": "bash D:/claude/claude-config/statusline/statusline.sh" }
# rate_limits приходит только подписчикам и только после первого ответа API; отсутствие — норма.

input=$(cat)

# Режим architect из синкнутого агента (единая точка Fable)
arch_file="/c/Users/umidi/.claude/agents/architect.md"
arch_model=$(grep -m1 '^model:' "$arch_file" 2>/dev/null | awk '{print $2}')

# Модель текущей сессии
model=$(echo "$input" | jq -r '.model.display_name // .model // "?"' 2>/dev/null)

# Лимит 5h (graceful — может отсутствовать)
pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
limit=""
[ -n "$pct" ] && limit=" | 5h:${pct}%"

printf 'M:%s | architect:%s%s' "${model:-?}" "${arch_model:-?}" "$limit"
