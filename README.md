# Claude Code Config — Единый источник правды

Глобальные правила и скиллы для всех проектов AiPlus.

## Структура

```
claude-config/
├── CLAUDE.md          # Глобальные правила (язык, brainstorming first, одобрение и т.д.)
├── sync.sh            # Скрипт синхронизации → все проекты + ~/.claude/
├── README.md          # Этот файл
└── skills/
    │
    │  # Основные (свои)
    ├── brainstorming/                  # Мозговой штурм (обязательно первое сообщение)
    ├── build/                          # Оркестратор разработки (не кодит сам)
    ├── research/                       # Исследование кода
    ├── deep-research/                  # Глубокий веб-ресёрч (4 режима)
    ├── review/                         # Ревью перед деплоем
    ├── docs/                           # Генерация документации
    ├── report/                         # Итоговые отчёты
    ├── test/                           # Написание тестов
    ├── tz/                             # Создание технического задания
    ├── audit-server/                   # Аудит продакшн-сервера (SSH, чек-лист, бэкап)
    ├── spec-to-code/                   # TDD-пайплайн: ТЗ → тесты → код → /review
    │
    │  # Аудит и качество кода
    ├── api-contract-guardian/          # Проверка API контрактов и схем
    ├── cicd-quick-setup/               # Готовый деплой-пайплайн под стек
    ├── dependency-optimizer/           # Аудит зависимостей (CVE, мусор, тяжёлые)
    ├── error-handling-standardizer/    # Единая обработка ошибок и логирование
    ├── performance-scanner/            # Узкие места и медленные операции
    │
    │  # Superpowers [SP]
    ├── systematic-debugging/           # [SP] 4-фазный дебаг
    ├── test-driven-development/        # [SP] RED-GREEN-REFACTOR
    ├── verification-before-completion/ # [SP] Проверка "готово"
    ├── subagent-driven-development/    # [SP] Субагенты + 2-stage review
    ├── dispatching-parallel-agents/    # [SP] Параллельные субагенты
    ├── receiving-code-review/          # [SP] Приём фидбека от ревью
    ├── finishing-a-development-branch/ # [SP] Merge/PR/cleanup
    ├── using-git-worktrees/            # [SP] Изоляция через worktree
    │
    │  # База данных (PostgreSQL под AiPlus)
    ├── postgres-patterns/              # Индексы, пагинация, очереди Watermill, multi-schema
    ├── database-reviewer/              # Ревью SQL/схем/миграций (read-only, file:line)
    ├── database-migrations/            # Zero-downtime миграции (Goose, expand-contract)
    │
    │  # Обслуживание сетапа (ревизоры — только отчёт)
    ├── skill-stocktake/                # Ревизия скиллов: дубли, качество, вердикты
    ├── context-budget/                 # Аудит токен-бюджета (CLAUDE.md/скиллы/MCP)
    └── rules-distill/                  # Принципы из 2+ скиллов → правила
```

## Как использовать

### Первая настройка (на новой машине)
```bash
git clone <repo-url> D:/claude/claude-config
cd D:/claude/claude-config
bash sync.sh
```

### Обновление
1. Отредактировать файлы в `claude-config/`
2. Запустить `bash sync.sh`
3. Закоммитить изменения: `git add . && git commit -m "update config"`

### Добавить новый проект
Добавить путь в массив `PROJECTS` в `sync.sh`, запустить `bash sync.sh`.

## Что куда попадает

| Источник | Куда синхронизируется |
|----------|----------------------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` (глобально) |
| `skills/*` | `~/.claude/skills/*` (глобально) |
| `skills/*` | `<проект>/.claude/skills/*` (в каждый проект) |

## Что НЕ синхронизируется

- **Проектные `CLAUDE.md`** — они специфичны для каждого проекта (стек, порты, интеграции)
- **Стек-специфичные скиллы** — `golang-patterns`, `golang-testing`, `dart-flutter-patterns`, `flutter-dart-code-review` живут локально в проекте (vault) и в git не отправляются
- **`settings.json`** — permissions и хуки специфичны для каждой машины

## Правила

- Глобальные правила — в этом репо
- Проектные правила — в проектном `CLAUDE.md`
- **Один источник правды** — менять здесь, синхронизировать скриптом
