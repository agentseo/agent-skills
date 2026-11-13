# Код под Drupal 10.3+ / 11

Целевая совместимость contrib — `core_version_requirement: ^10.3 || ^11`; сайты — текущий 11.x.
Перед использованием API проверить, с какой версии ядра он есть (change records на drupal.org,
`git log -S` по ядру в `vendor`/`web/core`).

## Хуки

- `#[Hook('form_alter')]` на методах класса в `src/Hook/` — ядро **11.1+**. На 10.3 такой хук
  не вызывается.
- Модулю `^10.3 || ^11`: либо процедурные хуки в `.module` (работают везде), либо OOP-класс +
  процедурный шим, помеченный `#[LegacyHook]`, который зовёт сервис:
  ```php
  #[LegacyHook]
  function mymodule_form_alter(&$form, FormStateInterface $form_state, $form_id): void {
    \Drupal::service(MymoduleHooks::class)->formAlter($form, $form_state, $form_id);
  }
  ```
  Класс хуков зарегистрировать в `mymodule.services.yml` (autowire) — на 10.3 автопоиска нет.
- Остаются процедурными: `hook_install/uninstall/schema/update_N/requirements` (`.install`),
  `hook_post_update_NAME`; хуки тем — смотреть версию ядра.
- Не делать в `hook_*_presave` того, что должно случиться один раз (смена автора и т. п.) —
  проверять `$entity->isNew()` / изменённые поля.

## Файлы (валидаторы D10.2+, `file_validate_*` удалены в 11.0)

```php
'#upload_validators' => [
  'FileExtension' => ['extensions' => 'pdf jpg png'],
  'FileSizeLimit' => ['fileLimit' => 5 * 1024 * 1024],
  'FileImageDimensions' => ['maxDimensions' => '4000x4000'],
],
// вне формы: \Drupal::service('file.validator')->validate($file, $validators) → ConstraintViolationList
```

`FileExtensionSecure` ядро применяет само (переименование `.php` и т. п.); не отключать
`allow_insecure_uploads`. Приватные данные — схема `private://`, доступ через `hook_file_download`.

## Маршруты, доступ, CSRF

- Действие по GET-ссылке (удалить, отвязать, переключить) — `requirements: _csrf_token: 'TRUE'`;
  ссылку строить `Url::fromRoute()` — токен добавится сам. Формы Form API защищены токеном формы.
- `AccessResult` всегда с кэшируемостью: `allowedIfHasPermission()` (кэш по правам сам),
  `->cachePerUser()` при проверке владельца, `->addCacheableDependency($entity)` при
  зависимости от сущности; `orIf()/andIf()` её объединяют. Забытая кэшируемость = чужая
  страница из кэша.
- Свой access-checker — сервис с тегом `access_check`; не проверять доступ только в контроллере.

## Рендер и вывод

- `#markup` проходит `Xss::filterAdmin`; ограничить теги — `#allowed_tags`; простой текст —
  `#plain_text`. **Не** оборачивать пользовательский ввод в `Markup::create()` — это снимает
  фильтрацию. В Twig `|raw` на пользовательских данных — XSS.
- `#lazy_builder`, `#pre_render`, `#post_render` колбэки — класс с `TrustedCallbackInterface`
  (`trustedCallbacks()`), иначе исключение.
- Переводы: `$this->t('… @name …', ['@name' => $x])` — `@` экранирует, `%` экранирует и
  выделяет, `:url` — для URL в атрибутах.

## Кэш

- `CacheableMetadata::createFromRenderArray()/->applyTo()`, `addCacheableDependency()`;
  контексты (`user.permissions`, `url.query_args:x`, `languages:language_interface`), теги,
  max-age. JSON-ответ с кэшем — `CacheableJsonResponse`.
- Списки сущностей — тег `node_list` (сбрасывается при сохранении любой ноды); точнее —
  `node_list:<bundle>`.
- **Internal Page Cache для анонимов игнорирует max-age** (кэширует до сброса по тегам).
  Страница, которая анониму должна быть свежей/персональной, — `page_cache_kill_switch`
  (`->trigger()`) или сессия; `#cache max-age 0` не спасает.
- Персональное в блоке на общей странице — lazy builder / BigPipe placeholder, а не
  `cachePerUser()` всей страницы.

## Формы

- Конфиг-формы: `#config_target` (10.2+) вместо ручного `submitForm` для простых полей.
- AJAX: `#ajax` + колбэк возвращает часть формы или `AjaxResponse`;
  `$form_state->getTriggeringElement()` — какая кнопка; `#limit_validation_errors` у кнопок,
  которым не нужна валидация всей формы.
- Синтаксис Drush 12/13 (`drush generate`, `drush php:eval`), команды Drush — сервисы с
  атрибутами `#[CLI\Command]`.

## Плагины

Атрибуты (`#[Block(...)]`, свои `#[MyPlugin(...)]`) — ядро 10.2+, годятся для `^10.3`.
Аннотации для новых плагинов не писать.

## JavaScript

`Drupal.behaviors.x = { attach(context, settings) { once('x', '.sel', context).forEach(…) } }`;
данные — `drupalSettings`; пути — `drupalSettings.path.baseUrl` (сайт может жить в подкаталоге).
