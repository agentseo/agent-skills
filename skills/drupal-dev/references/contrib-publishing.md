# Contrib-модуль: стенд, CI drupal.org, публикация

## Стенд модуля — ddev-drupal-contrib

Аддон `ddev/ddev-drupal-contrib` (официальный, организации ddev): модуль — центр проекта,
ядро ставится в `web/` и `vendor/` внутри каталога модуля, модуль симлинкуется в
`web/modules/custom/<name>`.

```bash
cd <каталог модуля>            # отдельный git-репозиторий модуля
# всё от стенда — в локальные исключения git, в репозиторий модуля не попадает
cat >> .git/info/exclude <<'EOF'
/.ddev/
/vendor/
/web/
/recipes/
/composer.lock
/composer.contrib.*
/.gitignore
/.prettierrc.json
/.prettierignore
/phpstan-baseline.neon
/node_modules/
EOF
ddev config --project-type=drupal11 --docroot=web --project-name=<name-with-dashes> --php-version=8.4
ddev add-on get ddev/ddev-drupal-contrib
ddev start && ddev poser && ddev symlink-project
ddev exec "cd web/core && yarn install --immutable"     # для eslint/stylelint/cspell
```

Команды: `ddev phpunit [путь]`, `ddev phpcs`, `ddev phpstan`, `ddev eslint`, `ddev stylelint`,
`contrib-cspell.sh <каталог>`. `ddev core-version ^10` ставит предыдущий мажор (только для
отладки падения из CI), `ddev core-version default` — обратно.

**Риск аддона:** `poser`, `symlink-project`, `phpcs`/`phpstan` без своих конфигов
**скачивают и исполняют PHP из gitlab_templates** (ветка по умолчанию, версия не закреплена) —
сетевой код при каждом вызове. Держать в модуле свои `phpcs.xml.dist` и `phpstan.neon`;
перед установкой аддона просмотреть, что он кладёт в `.ddev/`.

## Обязательные файлы модуля

`.gitlab-ci.yml` (шаблон gitlab_templates), `phpcs.xml.dist` (Drupal + DrupalPractice),
`phpstan.neon` (уровень ≥ 2, phpstan-drupal, deprecation rules, `phpVersion` нижней
поддерживаемой PHP), `.cspell-project-words.txt`, `composer.json`, `<name>.api.php` для своих
хуков/событий, `README.md` по шаблону drupal.org, переводы в `translations/<name>.<lang>.po`.

`.gitlab-ci.yml`: `OPT_IN_TEST_PREVIOUS_MAJOR: 1`, `OPT_IN_TEST_NEXT_MINOR: 1`, при
необходимости `_CSPELL_WORDS`, `_CSPELL_IGNORE_PATHS: 'translations/*'`.
**Задания previous major / next minor остаются ручными (manual/skipped) даже с OPT_IN_*** —
их запускают кнопкой в пайплайне; «skipped» не значит «прошло».

## Ловушки, на которых уже падали

- **Base path `/web`.** CI открывает сайт по `http://localhost/web`
  (`SIMPLETEST_BASE_URL=http://localhost/$_WEB_ROOT`):
  - ссылки и редиректы — только через `Url::fromRoute()` / `Url::fromUserInput()`, не
    строкой `'/user/login'`; в JS — `drupalSettings.path.baseUrl`;
  - `?destination=` уже содержит base path (`/web/user/1`) — не приклеивать его повторно и
    не сравнивать с путём без него;
  - путь cookie = base path (`$request->getBasePath() ?: '/'`), а не `/`;
  - проверка заголовка `Origin` — со `scheme://host[:port]` (`$request->getSchemeAndHttpHost()`),
    без base path.
  Локальная проверка: nginx-конфиг в `.ddev/nginx/` стенда, отдающий `web/` ещё и по `/web/`
  (`location ^~ /web/ { alias /var/www/html/web/; … fastcgi с SCRIPT_NAME /web/$1 … }`), затем
  `ddev restart` и `ddev exec 'SIMPLETEST_BASE_URL=http://web/web phpunit --bootstrap $PWD/web/core/tests/bootstrap.php web/modules/custom/<name>/tests/src/Functional'`.
- **cspell.** `e-mail` — флаг-слово, писать `email` (и в названиях, и в переводах исходных
  строк); также `grey`, `queuing`, `whitelist`/`blacklist`. Свои термины —
  `.cspell-project-words.txt`. Конфиг ядра `web/core/.cspell.json` строже CI (запрещает
  `Please`) — мерить `contrib-cspell.sh`, окончательно — заданием cspell в CI.
- **`.po` модуля без строк ядра.** Импорт перевода модуля перезаписывает перевод ядра на всём
  сайте; ревьюеры это замечают. В `.po` — только собственные msgid модуля (сверять с
  `core.<lang>.po` или проверкой в тесте).
- **Хуки.** Для `^10.3 || ^11` — процедурные хуки или `#[Hook]` + `#[LegacyHook]`-шим
  (см. `d11-practices.md`). Голый `#[Hook]` на 10.3 не вызывается.

## Результаты CI без входа — `scripts/ci-artifacts.sh`

Лог задания (trace) требует входа, а артефакты публичны (junit, phpstan, codequality,
html-вывод браузерных тестов):

```
https://git.drupalcode.org/api/v4/projects/project%2F<name>          → id
…/projects/<id>/pipelines?sha=<sha>                                    → пайплайны коммита
…/projects/<id>/pipelines/<pipeline_id>/jobs?per_page=100              → задания и типы артефактов
…/projects/<id>/jobs/<job_id>/artifacts                                → zip (curl -L)
…/projects/<id>/jobs/<job_id>/artifacts/<path>                         → один файл
```

```bash
ci-artifacts.sh <name>                 # пайплайн HEAD и его задания
ci-artifacts.sh <name> <sha> --get     # артефакты всех упавших заданий + выжимка junit
ci-artifacts.sh <name> --get phpstan --out /путь/вне/проекта
```

Архивы — чужие данные: распаковывать в отдельный каталог, читать, не исполнять.

## Публикация

1. **Имя.** Свободно ли: `https://www.drupal.org/api-d7/node.json?field_project_machine_name=<name>`
   (пустой список) и `https://updates.drupal.org/release-history/<name>/current` (нет проекта).
   Анонимный `git.drupalcode.org/project/<name>` редиректит на вход и для несуществующих имён —
   ничего не доказывает. Окончательно проверяет владелец в браузере. **Страницы drupal.org
   за бот-проверкой — не обходить, не пытаться автоматизировать.**
2. **Похожие проекты** — тем же API (`api-d7/node.json`, `release-history`); сравнение по
   описаниям, честно указывать, что прочитано, а что нет.
3. **Учётка владельца**: git-доступ на drupal.org, SSH-ключ в git.drupalcode.org. Создание
   проекта (`node/add/project-module`), релизы, заявка на security coverage — руками владельца;
   агент готовит текст и чек-лист.
4. **Свежий репозиторий с одним чистым первым коммитом**, а не `git subtree split` сайта:
   в истории сайта имя клиента, сайтовый код, сообщения на другом языке.
   ```bash
   mkdir <новый каталог> && cd <новый каталог> && git init -b 1.0.x
   rsync -a --exclude .git <модуль в сайте>/ ./
   # убрать сайтовые страховочные тесты; grep -rniE '<имя сайта|клиента>' . — пусто
   git add -A && git commit -m "Initial commit: <Name> 1.0.x"
   git remote add origin git@git.drupal.org:project/<name>.git
   git push -u origin 1.0.x
   ```
   **Первый push в пустой репозиторий задаёт ветку по умолчанию** — пушить сначала `1.0.x`,
   никаких временных веток. Затем на странице проекта Default branch = `1.0.x`.
5. Дождаться зелёного пайплайна; вручную запустить previous major / next minor. Упало на
   нижней версии ядра — чинить или поднимать `core_version_requirement`.
6. Тег `1.0.0-alpha1` → релиз через `node/add/project-release/<nid>`.
7. Security advisory coverage — заявка в очередь `projectapplications`; ревьюеры смотрят
   phpcs, формы, вывод, CSRF, доступ (для модулей входа — state/PKCE, привязку по почте).
8. Перевод — после первого релиза загрузить `.po` на localize.drupal.org.
9. Сайт, где модуль родился, переходит на `composer require drupal/<name>`; сайтовая
   надстройка остаётся отдельным модулем.

## Текст страницы проекта

Пишется на английском, HTML ограниченный, превью перед сохранением обязательно:

- два `<a>` в одном `<li>` ломали разметку списка — одна ссылка на пункт или ссылки в абзаце;
- экранированный тег (`&lt;dialog&gt;`) показывался буквально, с сущностями — писать словами («the dialog element»);
- структура: что делает → чем отличается от похожих проектов → требования → установка и
  настройка → безопасность → поддержка.
