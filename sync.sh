#!/bin/bash
# ============================================
# Claude Code Config Sync
# Единый источник правды → все проекты + глобальные
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="/c/Users/umidi/.claude"

# Список проектов для синхронизации
PROJECTS=(
  "/d/claude/aiplus_telegram_bot"
  "/d/claude/aiplus_insta"
  "/d/claude/aiplus_ai"
  "/d/claude/asistent.kz"
  "/d/claude/aiplus_server_offline"
  "/d/claude/aiplus_docs"
  "/d/claude/aiplus_website"
  "/d/claude/aiplus_mobile"
  "/d/claude/aiplus_online_86.107.45.163"
)

echo "========================================"
echo "  Claude Code Config Sync"
echo "  Источник: $SCRIPT_DIR"
echo "========================================"
echo ""

# --- 1. Синхронизация глобальных ---
echo "[1/3] Глобальные настройки (~/.claude/) ..."

# CLAUDE.md
cp "$SCRIPT_DIR/CLAUDE.md" "$GLOBAL_DIR/CLAUDE.md"
echo "  ✓ CLAUDE.md → ~/.claude/"

# Skills
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$GLOBAL_DIR/skills/$skill_name"
  cp "$skill_dir"SKILL.md "$GLOBAL_DIR/skills/$skill_name/SKILL.md"
  echo "  ✓ /skills/$skill_name/"
done

echo ""

# --- 2. Синхронизация скиллов в проекты ---
echo "[2/3] Скиллы → проекты ..."

for project in "${PROJECTS[@]}"; do
  project_name=$(basename "$project")

  if [ ! -d "$project" ]; then
    echo "  ✗ $project_name — папка не найдена, пропускаю"
    continue
  fi

  # Создать .claude/skills/ если нет
  mkdir -p "$project/.claude/skills"

  # Копировать все скиллы
  for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$project/.claude/skills/$skill_name"
    cp "$skill_dir"SKILL.md "$project/.claude/skills/$skill_name/SKILL.md"
  done

  echo "  ✓ $project_name — 7 скиллов синхронизированы"
done

echo ""

# --- 3. Итог ---
echo "[3/3] Готово!"
echo ""
echo "Синхронизировано:"
echo "  • CLAUDE.md (глобальные правила)"
echo "  • 7 скиллов: brainstorming, build, research, review, docs, report, test"
echo ""
echo "Примечание: проектные CLAUDE.md НЕ перезаписываются."
echo "Стек-специфичные скиллы (security, sql-audit, migrate-check) — в проектах."
echo "========================================"
