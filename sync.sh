#!/bin/bash
# ============================================
# Claude Code Config Sync
# Единый источник правды → глобальные настройки
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="/c/Users/umidi/.claude"

echo "========================================"
echo "  Claude Code Config Sync"
echo "  Источник: $SCRIPT_DIR"
echo "========================================"
echo ""

# --- 1. Синхронизация глобальных ---
echo "[1/2] Глобальные настройки (~/.claude/) ..."

# CLAUDE.md
cp "$SCRIPT_DIR/CLAUDE.md" "$GLOBAL_DIR/CLAUDE.md"
echo "  ✓ CLAUDE.md → ~/.claude/"

# Skills
skill_count=0
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$GLOBAL_DIR/skills/$skill_name"
  cp "$skill_dir"SKILL.md "$GLOBAL_DIR/skills/$skill_name/SKILL.md"
  echo "  ✓ /skills/$skill_name/"
  skill_count=$((skill_count + 1))
done

echo ""

# --- Субагенты (~/.claude/agents/) ---
# Папка agents/ полностью принадлежит claude-config — чистим перед копированием,
# чтобы переименованный/удалённый агент не оставил «призрака» в глобале.
echo "  Субагенты (~/.claude/agents/) ..."
rm -rf "$GLOBAL_DIR/agents"
mkdir -p "$GLOBAL_DIR/agents"
agent_count=0
if [ -d "$SCRIPT_DIR/agents" ]; then
  for agent_file in "$SCRIPT_DIR/agents"/*.md; do
    [ -e "$agent_file" ] || continue
    cp "$agent_file" "$GLOBAL_DIR/agents/"
    echo "  ✓ /agents/$(basename "$agent_file")"
    agent_count=$((agent_count + 1))
  done
fi

echo ""

# --- 2. Итог ---
echo "[2/2] Готово!"
echo ""
echo "Синхронизировано:"
echo "  • CLAUDE.md (глобальные правила)"
echo "  • $skill_count скиллов → ~/.claude/skills/"
echo "  • $agent_count субагентов → ~/.claude/agents/"
echo ""
echo "Примечание: проектные CLAUDE.md НЕ перезаписываются."
echo "Стек-специфичные скиллы (security, sql-audit, migrate-check и др.) — в проектах."
echo "========================================"
