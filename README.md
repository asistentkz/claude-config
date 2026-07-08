# Claude Code Config — Единый источник правды

Глобальные правила, субагенты и скиллы для всех проектов AiPlus.

## Структура

```
claude-config/
├── CLAUDE.md            # Глобальные правила (язык, brainstorming first, одобрение, роутинг моделей)
├── sync.sh              # Синхронизация → ~/.claude/ (CLAUDE.md + skills/ + agents/)
├── README.md            # Этот файл
├── agents/              # Субагенты Claude Code (модель задаётся в frontmatter)
│   ├── architect.md     #   Fable — системная/межсервисная архитектура (ЕДИНСТВЕННАЯ точка Fable), read-only
│   ├── researcher.md    #   Sonnet — исследование кодовой базы/веба, read-only
│   └── mechanic.md      #   Haiku — механика: grep/поиск/переименования/форматирование
├── statusline/
│   └── statusline.sh    # Статус-строка: модель сессии + режим architect + лимит 5h (jq-free, вкл. вручную)
└── skills/
    │
    │  # Основные (свои)
    ├── brainstorming/                  # Мозговой штурм (обязательно первое сообщение)
    ├── build/                          # Оркестратор разработки (модель на каждый этап, не кодит сам)
    ├── plan/                           # Сбор инфо + план → верификация Fable (research→черновик→architect)
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
    │  # Роутинг моделей
    ├── fable-off/                      # architect: Fable → Opus (фолбэк) + sync
    ├── fable-on/                       # architect: Opus → Fable (возврат) + sync
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

## Роутинг моделей

Задачи распределяются по моделям автоматически. 📖 **Гайд для команды (как повторить у себя) — [`MODEL-ROUTING.md`](MODEL-ROUTING.md).** Полная карта «тип задачи → модель» — в `CLAUDE.md`, секция **«Роутинг моделей по задачам»**. Кратко:

- **Субагенты** (`agents/`) несут модель в frontmatter: `architect`=Fable (только системная архитектура — единственная точка Fable), `researcher`=Sonnet, `mechanic`=Haiku.
- **Главный цикл** — Opus 4.8 по умолчанию; всё, чего нет в карте → Opus.
- **Скиллы**: worker-скиллы низкой ставки пиннятся `model: sonnet` (docs, report, test, deep-research, dependency-optimizer, cicd-quick-setup, error-handling-standardizer, context-budget, skill-stocktake, research); `review`→opus; `fable-off/on`→haiku. Опус-скиллы и оркестраторы (`build`, `plan`, `spec-to-code`, `subagent-driven-development`, `dispatching-parallel-agents`) и дисциплины (`systematic-debugging`, TDD, verification) без пина — едут на дефолтном Opus.
- **Фолбэк Fable→Opus**: если Fable недоступна/лимит/refusal — `/fable-off` (architect → Opus), возврат — `/fable-on`. Правят исходник `agents/architect.md` + запускают `sync.sh`.
- **statusline** (опц.): показывает текущую модель сессии + режим architect + лимит 5h. Включить — прописать `statusLine` в `~/.claude/settings.json` (пример — в шапке `statusline/statusline.sh`).

## Как использовать

### Первая настройка (на новой машине)
```bash
git clone git@github.com:asistentkz/claude-config.git D:/claude/claude-config
cd D:/claude/claude-config
bash sync.sh
```

### Обновление
1. Отредактировать файлы в `claude-config/`
2. Запустить `bash sync.sh`
3. Закоммитить и запушить: `git add <файлы> && git commit -m "..." && git push`

## Что куда синхронизируется

`sync.sh` копирует **только в `~/.claude/`** (глобальные настройки, работают во всех проектах):

| Источник | Куда | Режим |
|----------|------|-------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | перезапись |
| `skills/*` | `~/.claude/skills/*` | перезапись SKILL.md |
| `agents/*` | `~/.claude/agents/*` | **full-replace** (папка чистится перед копированием — призраков удалённых агентов не остаётся) |

## Что НЕ синхронизируется

- **Проектные `CLAUDE.md`** — специфичны для каждого проекта (стек, порты, интеграции)
- **Стек-специфичные скиллы** — `golang-patterns`, `golang-testing`, `dart-flutter-patterns`, `flutter-dart-code-review` живут локально в проекте (vault) и в git не отправляются
- **`settings.json`** — permissions и хуки специфичны для каждой машины
- **`statusline/`** — не копируется; статус-строка запускается напрямую из claude-config (путь прописан в `settings.json`). `statusline.sh` — jq-free (jq в Git Bash на Windows нет)

## Правила

- Глобальные правила — в этом репо
- Проектные правила — в проектном `CLAUDE.md`
- **Один источник правды** — менять здесь, синхронизировать скриптом, коммитить и пушить
```
