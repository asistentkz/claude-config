---
name: fable-on
description: Вернуть агента architect на Fable (после /fable-off). Правит исходник в claude-config и запускает sync.
allowed-tools: Read, Edit, Bash
model: haiku
---

Возврат architect: Opus → Fable.

Выполни:
1. В файле `D:/claude/claude-config/agents/architect.md` замени строку frontmatter `model: opus` на `model: fable`. Если там уже `model: fable` — сообщи, что Fable уже активна, и остановись.
2. Запусти синк: `bash D:/claude/claude-config/sync.sh`
3. Подтверди пользователю: «architect вернулся на Fable.»

ВАЖНО: правим ИСХОДНИК в claude-config (не глобал ~/.claude).
