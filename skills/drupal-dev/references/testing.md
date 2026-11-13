# Тесты Drupal

## Какие тесты писать

| Тип | Базовый класс | Для чего | Где обязателен |
| --- | --- | --- | --- |
| Unit | `UnitTestCase` | чистая логика без ядра | contrib и сайт |
| Kernel | `KernelTestBase` | сервисы, сущности, конфиг, доступ, БД — без HTTP | contrib и сайт, основной объём |
| Functional | `BrowserTestBase` | страницы, формы, маршруты, права через HTTP | contrib и сайт, ключевые сценарии |
| FunctionalJavascript | `WebDriverTestBase` | JS, AJAX, модальные окна | где без JS не проверить; нужен selenium |
| ExistingSite (DTT) | `weitzman/drupal-test-traits` | проверки на установленном сайте с его конфигом | **только сайт**, только локальная копия, никогда прод |

- drupal.org ждёт Unit/Kernel/Functional; ExistingSite в contrib не годится.
- Kernel в 11.x: **не** вызывать `installSchema('system', ['sequences'])` — таблицы нет с 11.0.
  Обычный набор: `installEntitySchema('user')`, `installConfig([...])`, `installSchema('модуль', [...])`.
- PHPUnit 10+ (ядро 11): опции `--verbose` нет; атрибуты `#[Group]`, `#[CoversClass]`,
  `#[RunTestsInSeparateProcesses]`. Модулю `^10.3 || ^11` держать и докблок `@group` —
  ядро 10 работает на PHPUnit 9, атрибутов не видит.
- Сайтовые «страховочные» тесты (в модуле нет имени клиента, кириллицы вне переводов, строк
  ядра в `.po`) полезны, пока модуль живёт в сайте; в публикуемый репозиторий не идут.

## Прогон — `scripts/test.sh`

С хоста, из каталога ddev-проекта (где `.ddev/`) или его подкаталога; скрипт сам уходит в
web-контейнер **этого** ddev-проекта, поэтому на стенде гоняет стенд.

```bash
test.sh                                   # все custom-модули/темы/профили, Unit+Kernel, 8 потоков
test.sh my_module other_module            # по модулям
test.sh web/modules/custom/my_module/tests/src/Kernel/FooTest.php
test.sh my_module --full                  # + Functional — один раз в конце
test.sh -c 12 --full                      # потоков больше (или TEST_CONCURRENCY)
test.sh user --types PHPUnit-Kernel       # группа ядра (не путь и не модуль)
test.sh my_module --list                  # что пойдёт в прогон
test.sh --clean                           # хвосты прерванного прогона
```

Ещё: `--js`, `--sqlite`, `--url`, `--repeat N`, `-v`. Код выхода — от run-tests.sh.
Вывод — строка на тест-класс, затем упавшие методы с первыми строками сообщения (из junit).
Лог и junit — `<ddev-проект>/.test-results/` (добавить в `.gitignore`).

Как устроено и почему:

- тестовые сайты ставятся в БД `phpunit` db-контейнера (скрипт создаёт её); у каждого
  тест-класса свой префикс таблиц, потоки не мешают; БД сайта `db` не трогается;
- служебная БД раннера — свой SQLite-файл в `/tmp` контейнера на прогон;
- run-tests.sh запускается **без `IS_DDEV_PROJECT`**: иначе подключается `settings.ddev.php`,
  раннер грузит установленный сайт и падает (ищет его таблицы, например `locales_source`,
  в БД `phpunit`);
- Functional ходят на `http://localhost` внутри контейнера;
- `--sqlite` работает, но медленнее MariaDB и даёт другие результаты на decimal
  (`'1550.5'` вместо `'1550.50'`) — по умолчанию не нужен.

Прямой `ddev exec vendor/bin/phpunit -c phpunit.xml <путь> --filter X` — последовательно,
для отладки одного теста.

## Скорость

Замер (WSL2, 18 ядер; 27 тест-классов, 211 методов, все типы):

| Как | Время |
| --- | --- |
| phpunit по модулям последовательно | 1022 с |
| run-tests, 8 потоков, MariaDB по умолчанию | 1237 с — хуже последовательного |
| + MariaDB без fsync | 671 с |
| + БД `phpunit` и `sites/simpletest` в tmpfs (стенд `stand.sh`) | **318 с** |
| то же, `-c 16` | 268 с |
| только Unit+Kernel, 8 потоков, tmpfs | 165 с |

- **Узкое место — диск WSL, а не CPU**: параллельные установки тестовых сайтов стоят в IO
  (`/proc/pressure/io` ~40 %, контейнеры по 5–20 % CPU). Параллельно гонять на стенде
  (`references/stands.md`), а не в основном ddev-проекте.
- Нижний предел — самый долгий тест-класс: run-tests.sh делит работу по классам. Тяжёлый
  класс разбить или пометить группой `#slow` (их запускают первыми).
- php-fpm в ddev: `pm.max_children = 8` — для Functional больше 8 потоков не помогает.

## Сайт в подкаталоге, как в CI drupal.org

CI drupal.org открывает сайт по `http://localhost/web` — ошибки base path видны только там
(см. `contrib-publishing.md`, «Подкаталог»). Перед публикацией модуля прогнать Functional
с `SIMPLETEST_BASE_URL=http://web/web`.

## FunctionalJavascript

Аддон `ddev/ddev-selenium-standalone-chrome` (контейнер selenium, ~1–2 ГБ памяти; требует
свежий DDEV — сверить с README аддона). Он выставляет `SIMPLETEST_DB` на БД сайта —
`test.sh` всё равно передаёт `--dburl` с БД `phpunit`, на стенде `config.local.yaml`
читается последним. Ставить только на стенд, где такие тесты нужны; прогон `test.sh <модуль> --js`.
