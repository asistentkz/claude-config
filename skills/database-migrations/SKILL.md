---
name: database-migrations
description: Zero-downtime миграции PostgreSQL под AiPlus (Goose, продакшн со школами) — expand-contract, CONCURRENTLY, батч-бэкфилл, Watermill-совместимость. Может генерить миграции с апрувом.
allowed-tools: Read, Grep, Glob, Write
---

# Database Migrations (AiPlus)

Безопасные изменения схемы для продакшна, который обслуживает школы Казахстана — **ронять нельзя**. Стек: Go 1.22, **Goose**, миграции встроены в бинарь и применяются на старте приложения (`kit/dbMigration`).

При генерации миграции — **сначала показать SQL пользователю, записать файл только после явного апрува**. Не применять (`make run` мигрирует на старте) без отдельного подтверждения.

## Формат файла

Путь: `mono_backend/dbmigrations/YYYYMMDDHHMMSS_name.sql`. Создавать через `make goose name=description` (генерирует timestamp-имя). Шаблон Goose:

```sql
-- +goose Up
-- +goose StatementBegin
ALTER TABLE educational.lessons ADD COLUMN topic_label TEXT;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE educational.lessons DROP COLUMN topic_label;
-- +goose StatementEnd
```

- **Каждый Up обязан иметь Down** (откат через `make down-one`). Если откат невозможен — пометить комментарием и согласовать.
- Таблицы **квалифицируем схемой** (`educational.lessons`) — 15 схем, `search_path` в проде не настроен.
- **`CONCURRENTLY` нельзя в транзакции** — для такой команды используйте `-- +goose NO TRANSACTION` в начале файла (Goose иначе оборачивает statement в транзакцию).

## Принципы

1. Любое изменение схемы — миграция. Никаких ручных ALTER в проде.
2. Миграция, прошедшая в проде, **неизменна** — правка ведёт к дрифту между средами. Нужна правка → новая миграция.
3. **DDL и DML — разные миграции** (схема отдельно, бэкфилл данных отдельно).
4. Тестируйте на объёме, близком к проду: то, что мгновенно на 100 строках, лочит таблицу на 10М (`activities`, `sessions`, `lessons`, `action_history`).
5. Откат в проде — это **новая forward-миграция**, а не правка старой.

## Чек-лист перед миграцией

- [ ] Есть Up и Down (или явно помечено «необратимо»)
- [ ] Нет full-lock на большой таблице (см. ниже)
- [ ] Новый столбец — nullable или с дефолтом (не `NOT NULL` без дефолта)
- [ ] Индекс на существующей таблице — `CONCURRENTLY` + `NO TRANSACTION`
- [ ] Бэкфилл — отдельная миграция, батчами
- [ ] FK проиндексирован (см. `postgres-patterns`)
- [ ] Совместимо с Watermill-обработчиками, читающими старую схему во время раската

## Безопасные операции

### Добавление столбца

```sql
-- ХОРОШО: nullable, без блокировки
ALTER TABLE educational.students ADD COLUMN nickname TEXT;

-- ХОРОШО: с дефолтом (PG 11+ — мгновенно, без перезаписи строк)
ALTER TABLE educational.students ADD COLUMN is_vip BOOLEAN NOT NULL DEFAULT false;

-- ПЛОХО: NOT NULL без дефолта на существующей таблице — full rewrite + блокировка
ALTER TABLE educational.students ADD COLUMN tier TEXT NOT NULL;
```

### Индекс без простоя

```sql
-- +goose NO TRANSACTION
-- +goose Up
-- +goose StatementBegin
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_activities_student_created
  ON educational.activities (student_id, created_at);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX CONCURRENTLY IF EXISTS educational.ix_activities_student_created;
-- +goose StatementEnd
```

Обычный `CREATE INDEX` (без `CONCURRENTLY`) блокирует запись на всё время построения — на больших таблицах это даунтайм.

### Бэкфилл данных батчами

Один `UPDATE` на всю большую таблицу = долгая транзакция, блокировки, раздувание WAL. Бейте на батчи:

```sql
-- Отдельная миграция, ПОСЛЕ добавления столбца
DO $$
DECLARE rows_updated INT;
BEGIN
  LOOP
    UPDATE educational.activities
    SET score_percent = round(score_points::numeric / NULLIF(max_score_points, 0) * 100)
    WHERE score_percent IS NULL
      AND id IN (
        SELECT id FROM educational.activities
        WHERE score_percent IS NULL
        LIMIT 5000
        FOR UPDATE SKIP LOCKED
      );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RAISE NOTICE 'backfilled % rows', rows_updated;
    EXIT WHEN rows_updated = 0;
    COMMIT;
  END LOOP;
END $$;
```

## Expand-contract (главный паттерн)

Никогда не переименовывать/удалять столбец одним шагом — приложение и Watermill-обработчики во время раската читают **старую** схему. Разносим по разным PR:

```
EXPAND   (PR 1): добавить новый столбец/таблицу (nullable или с дефолтом)
                 деплой: код пишет в СТАРОЕ и НОВОЕ
BACKFILL (PR 2): отдельная миграция, батчами заполнить новое из старого
MIGRATE  (PR 3): деплой: код читает из НОВОГО, пишет в оба; сверить консистентность
CONTRACT (PR 4): деплой: код использует только новое; затем миграция дропает старое
```

### Переименование столбца

```sql
-- PR 1: добавить новый
ALTER TABLE educational.groups ADD COLUMN display_level TEXT;
-- PR 2 (data): UPDATE ... SET display_level = level  (батчами)
-- PR 3: код читает/пишет display_level, перестаёт писать level
-- PR 4: ALTER TABLE educational.groups DROP COLUMN level;
```

### Удаление столбца

1. Убрать **все** ссылки в коде (включая Watermill eHandler/asyncCmdHandler и queries).
2. Задеплоить приложение без столбца.
3. Следующей миграцией — `DROP COLUMN`.

Дроп до выката кода = паника/ошибки на читающих старую схему обработчиках.

## Совместимость с Watermill

`reactor` обрабатывает события/команды асинхронно с ретраями (5 попыток, exp backoff). Во время раската:

- В очереди (`wm_*`) могут лежать сообщения, сформированные **старым** кодом под старую схему — новый обработчик должен их прочитать.
- Дроп столбца/таблицы, на которые ещё ссылается необработанное сообщение → ретраи и зависшие сообщения.
- Любое разрушающее изменение схемы — только в фазе CONTRACT, когда очередь дренирована и код мигрирован.

## Связь с pr-size

Миграции **не считаются** в LOC по правилу `pr-size`, но логически дробятся как любая работа: expand / backfill / migrate / contract — каждая фаза отдельным PR. Не схлопывайте их в один PR ради «удобства» — это убивает возможность безопасного отката.

## Анти-паттерны

| Анти-паттерн | Чем плох | Как правильно |
|--------------|----------|----------------|
| ручной ALTER в проде | нет аудита, не воспроизводимо | только файл миграции |
| правка применённой миграции | дрифт между средами | новая миграция |
| `NOT NULL` без дефолта | full rewrite + блокировка | nullable → бэкфилл → constraint |
| inline `CREATE INDEX` на большой таблице | блокирует запись | `CONCURRENTLY` + `NO TRANSACTION` |
| DDL + DML в одной миграции | долгая транзакция, тяжёлый откат | разделить |
| дроп столбца до выката кода | паника обработчиков/хендлеров | сначала код, потом дроп |

## Связанное

- Скилл `postgres-patterns` — индексы, типы, soft-delete, timezone.
- Скилл `database-reviewer` — ревью миграции перед PR.
- Скилл `psql` — проверка схемы (`\d+ schema.table`) и `EXPLAIN` до/после.
- Правило `pr-size` — дробление многошаговых изменений.
