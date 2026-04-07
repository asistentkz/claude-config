---
name: cicd-quick-setup
description: Собирает готовый деплой-пайплайн под стек проекта (Docker, GitHub Actions, PM2, VPS) с защитой существующих конфигов
allowed-tools: Read, Grep, Glob, Agent, WebSearch, Edit, Write, Bash
argument-hint: "[проект или 'auto' для автоопределения стека]"
---

Настрой CI/CD для проекта: $ARGUMENTS

## Правила
- **НИКОГДА не перезаписывай существующие CI/CD конфиги** без явного одобрения
- Сначала покажи план, дождись "да" — потом создавай файлы
- Адаптируй под конкретный стек проекта, не используй универсальные шаблоны

## Шаг 1: Проверка существующих CI/CD

Проверь наличие конфигов:
- `.github/workflows/` — GitHub Actions
- `Dockerfile`, `docker-compose.yml` — Docker
- `ecosystem.config.js` — PM2
- `.gitlab-ci.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`
- `Makefile` с deploy таргетами
- Скрипты деплоя в `scripts/`, `deploy/`

**Если нашёл** → показать что уже есть, спросить: "CI/CD уже настроен. Улучшить/дополнить или оставить как есть?"
**Если не нашёл** → перейти к шагу 2

## Шаг 2: Определение стека

Автоматически определи:
- Язык/рантайм: `package.json` → Node.js, `go.mod` → Go, `composer.json` → PHP, `pubspec.yaml` → Flutter
- Менеджер пакетов: npm, yarn, pnpm, go mod, composer
- Фреймворк: Express, Fastify, Next.js, Gin, Laravel, и т.д.
- БД: SQLite, PostgreSQL, MySQL (из конфигов и кода)
- Текущий способ запуска: PM2, systemd, docker, ручной

## Шаг 3: Выбор стратегии деплоя

Предложи варианты под стек:

### Для Node.js ботов (PM2):
- `ecosystem.config.js` — конфиг PM2 для всех процессов
- GitHub Actions: push → SSH → git pull → npm install → pm2 restart
- Опционально: Docker + docker-compose

### Для Go:
- Multi-stage Docker build (builder → scratch/alpine)
- GitHub Actions: test → build → deploy binary
- Опционально: goreleaser

### Для Flutter:
- GitHub Actions: test → build APK/IPA → upload artifacts
- Fastlane интеграция
- Firebase App Distribution

### Для PHP:
- GitHub Actions: test → SSH deploy
- Docker + nginx/php-fpm
- Опционально: Deployer

## Шаг 4: Генерация конфигов

Покажи план файлов для создания:
```
Создам:
1. [путь] — [описание]
2. [путь] — [описание]
...
```

Дождись одобрения, затем создай файлы.

## Шаг 5: Инструкция по запуску

Выдай:
- Какие секреты/переменные нужно добавить (SSH ключи, токены)
- Как протестировать пайплайн локально
- Как запустить первый деплой
- Что мониторить после запуска

## Формат отчёта

### Стек проекта
| Параметр | Значение |
|----------|----------|

### Существующий CI/CD
- Найдено / Не найдено (детали)

### Предлагаемая стратегия
- Описание пайплайна
- Схема: push → ... → deploy

### Файлы для создания
| # | Файл | Назначение |

### Секреты и переменные
| # | Название | Где получить |

### Чек-лист после настройки
- [ ] Секреты добавлены в GitHub/GitLab
- [ ] Тестовый push прошёл
- [ ] Деплой на staging работает
- [ ] Rollback проверен
