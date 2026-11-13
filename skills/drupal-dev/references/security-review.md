# Аудит безопасности Drupal-сайта

Сначала — какой доступ разрешён (`AGENTS.md` проекта). На проде и dev-сайте — **только
чтение**: никаких `drush cim/updb/en/pm:install`, установок модулей, правки файлов.
**Секреты не выводить**: проверять наличие/форму настройки (да/нет, число элементов), а не
печатать значение; `settings.php` грепом не читать.

## Чек-лист

| Что | Как | Норма |
| --- | --- | --- |
| уязвимые модули/ядро | `drush pm:security` | пусто |
| уязвимые PHP-зависимости | `composer audit` (в каталоге с `composer.lock`) | пусто |
| статус-отчёт | `drush core:requirements --severity=2` | нет ошибок |
| исполняемое в files | `find <docroot>/sites/*/files <private-path> -name '*.php*' -o -name '*.phar'` | `.php` нет; `.htaccess` ядра на месте |
| trusted hosts | `drush php:eval 'echo count((array) \Drupal\Core\Site\Settings::get("trusted_host_patterns"));'` | > 0 на проде |
| вывод ошибок | `drush config:get system.logging error_level` | `hide` на проде |
| файлы ядра наружу | `curl -sI <site>/core/install.php`, `/update.php`, `/sites/default/settings.php`, `/core/CHANGELOG.txt`, `/.git/HEAD`, `/composer.lock` | 403/404, ничего не отдаётся |
| 403 vs 404 | `curl -sI` закрытой страницы анонимом (`/admin`, `/node/<непубличная>`, `/user/1`) | 403/404 без утечки данных; страницы ошибок не раскрывают путь/версию |
| регистрация | `drush config:get user.settings register` | как задумано (`admin_only` / с одобрением) |
| права анонима/авторизованного | `drush role:list --format=yaml` (роли anonymous и authenticated) | ничего административного, нет `use PHP`, `administer *`, `bypass *` |
| приватные файлы | `file_private_path` задан и вне docroot; доступ через `hook_file_download` | да |
| текстовые форматы | у анонимов/пользователей нет `full_html`; фильтры html включены | да |
| свой код | `_csrf_token` на GET-действиях, кэшируемость `AccessResult`, `#markup` и фильтр Twig raw с пользовательским вводом, `Markup::create`, SQL без плейсхолдеров, `\Drupal::request()->query` без проверки | см. `d11-practices.md` |

## Отчёт

Находка → где (маршрут/файл/настройка) → чем опасно → как проверить → предложение правки.
Отдельно — что **не** проверено (нет доступа, нужен вход владельца). Ничего не чинить на
проде самому: правки идут через репозиторий и обычный деплой проекта.
