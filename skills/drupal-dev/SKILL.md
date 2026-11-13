---
name: drupal-dev
description: Use when working on any Drupal 10/11 site or contrib module in ddev — writing or reviewing module/theme code, running or writing PHPUnit tests (Unit, Kernel, Functional, run-tests.sh), giving parallel agents their own test stands, preparing or publishing a module on drupal.org, reading drupal.org GitLab CI results (phpcs, phpstan, cspell, previous major / next minor jobs), or doing a security review of a Drupal site. Симптомы — «прогони тесты», «стенд для агента», «тесты медленные на WSL», «упал CI на drupal.org», «cspell ругается на e-mail», «сайт в подкаталоге /web», «опубликовать модуль», «хуки на атрибутах», «проверь безопасность сайта».
---

# Drupal: разработка, тесты, публикация

Общие правила для всех Drupal-проектов владельца. Специфика проекта (имя ddev-проекта,
модули, доступы к dev/prod, рецепты) — в `AGENTS.md` проекта; он важнее этого навыка.

## Жёсткие правила

1. **Прод и dev-сайт — только чтение**, если в `AGENTS.md` или в разговоре явно не разрешено
   иное. Дампы боевой/dev-БД в локальные стенды не заливать; персональные данные не копировать.
2. **Один параллельный агент = один стенд** (свой worktree + свой ddev-проект). Два агента на
   одном ddev-проекте не работают. После работы стенд остановить или удалить (~1 ГБ памяти).
3. **Тесты: по ходу работы — быстрые** (Unit + Kernel, модуль, который правишь),
   **полный набор (+ Functional) — один раз в конце.** Совместимость с предыдущим мажором
   ядра локально не гоняем — это делает CI drupal.org.
4. **Тесты не трогают БД сайта**: отдельная БД `phpunit`. ExistingSite (DTT) — только для
   сайтов и никогда против прода.
5. **Секреты** — только через механизм проекта (см. его `AGENTS.md`); ключи модулей — в
   `$settings`, не в конфиге; не печатать значения ни в выводе, ни в отчётах.
6. **drupal.org за бот-проверкой**: не обходить её (никаких антидетект-браузеров). Данные —
   через API (`git.drupalcode.org/api/v4`, `www.drupal.org/api-d7`, `updates.drupal.org`) или
   спросить владельца.
7. Код для `^10.3 || ^11` пишется так, чтобы работал на обоих — см. `references/d11-practices.md`.

## Скрипты (`~/.claude/skills/drupal-dev/scripts/`)

| Скрипт | Что | Запуск |
| --- | --- | --- |
| `test.sh` | параллельный `run-tests.sh` в web-контейнере ddev этого дерева, сводка падений из junit | из каталога ddev-проекта или стенда: `test.sh [модуль\|путь] [--full]` |
| `stand.sh` | стенды: worktree + свой ddev, tmpfs и MariaDB без fsync для тестов | из основного дерева: `stand.sh create N`, `list`, `stop N`, `rm N` |
| `contrib-cspell.sh` | cspell по правилам CI drupal.org, без скачивания чужого кода | `contrib-cspell.sh <каталог contrib-модуля>` |
| `ci-artifacts.sh` | пайплайн, задания и артефакты CI drupal.org без входа | `ci-artifacts.sh <проект> [sha] [--get [задание]]` |

У каждого скрипта `--help`. Проект может держать свои копии в `scripts/` — тогда главнее они.

## Справочники — читать по задаче

| Задача | Файл |
| --- | --- |
| запуск тестов, матрица типов, скорость, ловушки run-tests.sh | `references/testing.md` |
| стенды для параллельных агентов, возврат их работы | `references/stands.md` |
| contrib-модуль: стенд ddev-drupal-contrib, CI drupal.org, публикация, страница проекта | `references/contrib-publishing.md` |
| код под D10.3/D11: хуки, валидаторы файлов, доступ, кэш, рендер, формы | `references/d11-practices.md` |
| аудит безопасности сайта | `references/security-review.md` |
| бриф субагенту на Drupal-задачу | `references/agent-brief.md` |
