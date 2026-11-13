# Стенды для параллельных агентов — `scripts/stand.sh`

Стенд N:

- git worktree репозитория в `<родитель>/<репо>-stands/tN` на ветке `stand/tN`
  (от текущего HEAD или `--from REF`; своя ветка — `--branch`);
- свой ddev-проект `<имя ddev>-tN` (`https://<имя>-tN.ddev.site`) со своими web и db;
  имя и окружение тестов — в `.ddev/config.local.yaml`, отслеживаемый `config.yaml` не меняется;
- зависимости composer (vendor, core, contrib) **копируются** из основного дерева, если
  `composer.lock` совпадает; иначе `ddev composer install` (или флаг `--composer`);
- ускорение тестов (файлы в `.ddev/`, не коммитятся): `docker-compose.stand.yaml` — tmpfs для
  БД `phpunit` (8 ГБ) и `<docroot>/sites/simpletest` (4 ГБ); `mysql/zz-stand-tests.cnf` —
  MariaDB без fsync/doublewrite/binlog; хук post-start пересоздаёт БД `phpunit` в tmpfs.
  tmpfs пустеет при `ddev restart` — это тестовые сайты, они одноразовые.

С основным стендом ничего записываемого не общее: другие каталоги, контейнеры, том БД.
Общие только объекты git и кэш composer. Пользовательские файлы, `settings.local.php`, БД
сайта не копируются — их нет в git; БД стенда пустая.

```bash
cd <проект>                         # основное дерево (или любой стенд)
stand.sh create 3                   # ~40 с – 2 мин: worktree + копия vendor + ddev start
stand.sh create 4 --from master --branch fix/foo
stand.sh list                       # стенды, статус ddev, ветки
stand.sh stop 3 / start 3
stand.sh site 3 [--recipe recipes/site] [--locale ru]   # пустой рабочий сайт admin/admin
stand.sh rm 3                       # ddev delete + worktree remove; ветка остаётся
stand.sh rm 3 --delete-branch       # и ветку, если слита
```

Определяется само: ddev-проект (ближайший `.ddev/config.yaml` вверх от текущего каталога,
либо единственный в репозитории — например `drupal/`), docroot и имя из `config.yaml`.
Переопределения: `DDEV_REL`, `STANDS_DIR`, `STAND_PREFIX`, `STAND_COPY_DIRS`,
`STAND_SITE_RECIPES` (см. `stand.sh --help`). В контейнерах стенда есть `DRUPAL_STAND=tN`.

`rm` отказывается удалять стенд с незакоммиченными правками (кроме своих файлов стенда);
`--force` — только если правки точно не нужны.

## Рабочий сайт на стенде

`stand.sh site N` — `drush site:install standard` + рецепты проекта, вход admin/admin.
Контента нет. Дамп боевой или dev-БД в стенд не заливать.

## Как работа агента возвращается

Агент коммитит в ветку своего стенда обычным `git commit` в worktree; push не нужен — ветка
уже в общем репозитории. Основная сессия:

```bash
git log --oneline <рабочая-ветка>..stand/t3    # что сделал агент
git merge --no-ff stand/t3                      # или cherry-pick
stand.sh rm 3 --delete-branch
```

## Правила

- один агент — один стенд; основное дерево и чужие стенды агент не трогает;
- проверено: два стенда одновременно гоняют полный набор без пересечений;
- после работы `stand.sh stop N` (каждый работающий стенд держит ~1 ГБ памяти) или `rm`.
