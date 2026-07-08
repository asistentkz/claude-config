#!/bin/bash
# Claude Code statusline — модель сессии + режим architect (Fable/Opus) + лимит 5h.
# jq-FREE: парсит stdin через grep/sed (jq не гарантирован в Git Bash на Windows).
# НЕ синкается sync.sh. Запускается напрямую из claude-config (см. путь в settings.json).
# Включить: в ~/.claude/settings.json ->
#   "statusLine": { "type": "command", "command": "bash /d/claude/claude-config/statusline/statusline.sh" }
# rate_limits приходит только подписчикам и только после первого ответа API; отсутствие — норма.

input=$(cat)

# Режим architect из синкнутого агента (единая точка Fable)
arch_file="/c/Users/umidi/.claude/agents/architect.md"
arch_model=$(grep -m1 '^model:' "$arch_file" 2>/dev/null | awk '{print $2}')

# Модель текущей сессии: model.display_name (единственный display_name в JSON statusline)
model=$(printf '%s' "$input" \
  | grep -o '"display_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 \
  | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')

# Лимит 5h (graceful — поля может не быть)
pct=$(printf '%s' "$input" \
  | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' \
  | head -1 \
  | grep -o '[0-9.]*$')
limit=""
[ -n "$pct" ] && limit=" | 5h:${pct}%"

printf 'M:%s | architect:%s%s' "${model:-?}" "${arch_model:-?}" "$limit"
