---
name: postgres-patterns
description: Справочник паттернов PostgreSQL под AiPlus — индексы, пагинация, очереди Watermill, multi-schema, timezone, soft-delete, типы, анти-паттерны с диагностикой. Read-only.
allowed-tools: Read, Grep, Glob
---

# PostgreSQL Patterns (AiPlus)

Справочник под стек AiPlus: Go 1.22, pgx/v5, **PostgreSQL 16.13** (Yandex Managed), 15 схем, Watermill-очереди.
Read-only — здесь нет правок, только паттерны и диагностические запросы. Для ревью SQL см. `database-reviewer`, для безопасных миграций — `database-migrations`. Для запуска запросов и карты таблиц — скилл `psql`.

## Типы данных

| Назначение | Тип | Не использовать |
|------------|-----|-----------------|
| ID сущностей | `uuid` (домен использует префиксные UUID через `kit/id`) или `bigint` | `int`, `serial` для бизнес-ID |
| Деньги / AIBucks | `numeric` | `float`, `double precision` |
| Строки | `text` | `varchar(N)` без причины |
| Время | `timestamptz` | `timestamp` (см. timezone ниже) |
| Флаги | `boolean` | `int`, `varchar` |
| JSON-пейлоады | `jsonb` (`action_data`, `payload`, `test_questions`) | `json`, `text` |

`bigint`, не `int` — AiPlus продакшн, таблицы `activities`/`sessions`/`action_history` растут без потолка, 32-битный счётчик переполнится.

## Индексы

### Шпаргалка

| Паттерн запроса | Тип индекса | Пример |
|-----------------|-------------|--------|
| `WHERE col = v` / `col > v` | B-tree | `CREATE INDEX ix ON t (col)` |
| `WHERE a = x AND b > y` | composite | `CREATE INDEX ix ON t (a, b)` |
| `WHERE jsonb_col @> '{}'` | GIN | `CREATE INDEX ix ON t USING gin (col)` |
| `WHERE arr_col @> ARRAY[...]` (`roles`, `branch_ids`) | GIN | `CREATE INDEX ix ON t USING gin (col)` |
| Append-only по времени (`action_history.created_at`) | BRIN | `CREATE INDEX ix ON t USING brin (created_at)` |

### Правила

- **FK индексируем всегда** — без исключений. Неиндексированный FK = seq scan на JOIN и блокировки при каскадах. Goose/`CREATE TABLE` индекс на FK не создаёт сам.
- **Порядок колонок в composite**: сначала колонки на равенство, потом на диапазон.
  ```sql
  -- WHERE student_id = $1 AND created_at > $2
  CREATE INDEX ix ON educational.activities (student_id, created_at);
  ```
- **Partial-индекс под soft-delete** — меньше размер, быстрее активные выборки:
  ```sql
  CREATE INDEX ix ON educational.students (last_name) WHERE deleted_at IS NULL;
  ```
- **Covering (`INCLUDE`)** — убирает поход в heap, когда все нужные колонки в индексе:
  ```sql
  CREATE INDEX ix ON usermgmt.accounts (phone) INCLUDE (id, roles);
  ```

## Пагинация: cursor вместо OFFSET

`OFFSET` на больших таблицах (`activities`, `sessions`, `lessons`, `action_history`) — O(n): БД читает и отбрасывает все пропущенные строки.

```sql
-- ПЛОХО: чем больше страница, тем медленнее
SELECT * FROM educational.activities
WHERE student_id = $1 ORDER BY created_at DESC OFFSET 10000 LIMIT 20;

-- ХОРОШО: keyset/cursor, O(1) по индексу (student_id, created_at)
SELECT * FROM educational.activities
WHERE student_id = $1 AND created_at < $2  -- $2 = created_at последней строки прошлой страницы
ORDER BY created_at DESC LIMIT 20;
```

## Очереди: FOR UPDATE SKIP LOCKED

Watermill (`wm_*` таблицы) хранит очереди событий/команд в PG. Для собственной выборки задач из таблицы-очереди берите строку под блокировку и пропускайте занятые конкурентами — даёт параллелизм воркеров без взаимных блокировок.

```sql
UPDATE staff.tasks SET task_current_status = 'processing'
WHERE id = (
  SELECT id FROM staff.tasks
  WHERE task_current_status = 'pending'
  ORDER BY created_at
  FOR UPDATE SKIP LOCKED
  LIMIT 1
)
RETURNING *;
```

Без `SKIP LOCKED` воркеры выстраиваются в очередь на одну строку. `ORDER BY` фиксирует порядок блокировки — снижает риск дедлоков.

## UPSERT

```sql
INSERT INTO gamification.student_states (student_id, rank_score)
VALUES ($1, $2)
ON CONFLICT (student_id)
DO UPDATE SET rank_score = EXCLUDED.rank_score;
```

Конфликт-таргет должен совпадать с реальным UNIQUE/PK-ограничением.

## Multi-schema (15 схем)

Схемы: `usermgmt`, `educational`, `courseware`, `staff`, `registry`, `sales`, `mentoring`, `notifications`, `gamification`, `aibucks`, `qcd`, `helpdesk`, `marketing`, `media`, `finance`.

- **Всегда квалифицируйте таблицы схемой** — `educational.students`, не `students`. Не полагайтесь на `search_path`: он зависит от роли подключения и в продакшне не настроен под прикладные схемы.
- **Cross-schema FK допустимы** (`educational.teachers.employee_id` → `staff.employees`) — индексируйте такой FK так же, как любой другой.
- **Cross-schema JOIN** — обычный JOIN с квалификацией: `educational.students JOIN usermgmt.accounts`.
- Массивы (`roles`, `disciplines`, `branch_ids`, `city_ids`) — запрос через `ANY()` или `@>`, под частые фильтры — GIN.

## Timezone

- **Хранить `timestamptz`**, не `timestamp`. Все timestamp в БД — **UTC**.
- **Единственное исключение** — время уроков в `educational.lessons` (`begin_date`, `begin_hour`, `begin_minute`, `end_hour`, `end_minute`): они в **Asia/Almaty (UTC+5)**. Не конвертируйте их как UTC — получите сдвиг на 5 часов. Любой новый столбец времени — UTC `timestamptz`, никакого локального времени.
- В запросах **параметризуйте текущее время** (`$N`, не `now()`) — детерминизм под тестами (правило репозитория).

## Soft-delete (конвенция AiPlus)

- Большинство таблиц помечают удаление `deleted_at` (`students`, `employees`, `teachers`, `groups`, `lessons`, ...), а не удаляют строку.
- **Каждая выборка добавляет `WHERE deleted_at IS NULL`** — иначе в результат попадут «удалённые».
- Под это держите partial-индексы (см. выше).
- `version` — это optimistic concurrency (pgx `pg.RetryOCC`), **не** бизнес-версия и не soft-delete.

## Анти-паттерны + диагностика

| Анти-паттерн | Чем плох |
|--------------|----------|
| `SELECT *` в проде | тянет лишние колонки, ломает covering-индекс |
| seq scan по большой таблице | фильтр не по индексированной колонке (см. large-table warnings в `psql`) |
| OFFSET-пагинация | O(n) на больших таблицах |
| неиндексированный FK | медленные JOIN, блокировки при каскадах |
| `now()` внутри запроса | недетерминизм под тестами |
| скан `activities` по `activity_type_id` в одиночку | нет ведущего `student_id`/`lesson_id` |

```sql
-- Неиндексированные FK
SELECT conrelid::regclass AS tbl, a.attname AS col
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid AND a.attnum = ANY(i.indkey)
  );

-- Самые медленные запросы (нужен pg_stat_statements)
SELECT query, calls, round(mean_exec_time::numeric, 1) AS mean_ms, rows
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC LIMIT 20;

-- Bloat / залежавшийся VACUUM
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- Неиспользуемые индексы (кандидаты на удаление)
SELECT relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY relname;

-- План конкретного запроса
EXPLAIN (ANALYZE, BUFFERS) <query>;
-- Ищите Seq Scan на больших таблицах и расхождение rows estimated vs actual.
```

## Связанное

- Скилл `psql` — карта 15 схем, таблиц, large-table warnings, запуск запросов через `psql service=<service>`.
- Скилл `database-reviewer` — чек-лист ревью SQL/схем.
- Скилл `database-migrations` — zero-downtime миграции под Goose.
