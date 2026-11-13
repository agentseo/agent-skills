#!/usr/bin/env bash
# Параллельный прогон тестов Drupal (core/scripts/run-tests.sh) в ddev-проекте.
#
#   test.sh [ЦЕЛЬ ...] [опции]
#
# Запускать с хоста из каталога ddev-проекта (где .ddev/) или любого его подкаталога;
# скрипт сам уходит в web-контейнер ЭТОГО проекта (стенд — свой проект, свой контейнер).
#
# ЦЕЛЬ: имя модуля/темы, каталог или файл *Test.php (путь от корня ddev-проекта).
#       Без целей — все <docroot>/{modules,themes,profiles}/custom.
#       Иное имя считается группой тестов (#[Group]), например модуль ядра: user.
#
#   -c, --concurrency N  потоков (по умолчанию 8, или $TEST_CONCURRENCY)
#   --full               + Functional (полный набор: один раз в конце работы)
#   --js                 + FunctionalJavascript (нужен selenium в ddev)
#   --types LIST         свой список: PHPUnit-Unit,PHPUnit-Kernel,PHPUnit-Functional,...
#   --sqlite             тестовые сайты в SQLite (/tmp контейнера) вместо БД phpunit
#   --url URL            базовый адрес для Functional (по умолчанию http://localhost)
#   --repeat N           повторить каждый тест N раз (поиск плавающих падений)
#   --clean              убрать хвосты прерванных прогонов (таблицы test*, sites/simpletest)
#   --list               только показать, какие файлы пойдут в прогон
#   -v, --verbose        полный вывод run-tests.sh
#
# По умолчанию быстрые типы: PHPUnit-Unit,PHPUnit-Kernel.
# Лог и junit последнего прогона: <ddev-проект>/.test-results/ (добавьте в .gitignore).
# БД сайта не трогается: тестовые сайты ставятся в отдельную БД phpunit db-контейнера.
set -euo pipefail

usage() { sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------- хост
if [[ ${IS_DDEV_PROJECT:-} != true ]]; then
  for a in "$@"; do [[ $a == -h || $a == --help ]] && { usage; exit 0; }; done
  root=$PWD
  while [[ $root != / && ! -f $root/.ddev/config.yaml ]]; do root=$(dirname "$root"); done
  [[ -f $root/.ddev/config.yaml ]] || { echo "test.sh: не найден .ddev/config.yaml выше $PWD" >&2; exit 2; }
  cd "$root"
  # ddev exec склеивает аргументы в строку для bash -c, поэтому аргументы едут в base64,
  # а сам скрипт — через stdin (каталог скрипта в контейнер не смонтирован).
  b64=$(if [[ $# -gt 0 ]]; then printf '%s\0' "$@"; fi | base64 -w0)
  exec ddev exec -s web -d /var/www/html -- bash -s -- --b64args "${b64:-none}" <"${BASH_SOURCE[0]}"
fi

# ---------------------------------------------------------------- контейнер
main() {
  if [[ ${1:-} == --b64args ]]; then
    local enc=$2; shift 2
    if [[ $enc != none ]]; then mapfile -d '' -t _args < <(printf '%s' "$enc" | base64 -d); set -- "${_args[@]}"; fi
  fi
  cd /var/www/html
  local docroot
  docroot=$(sed -n 's/^docroot:[[:space:]]*["'\'']\{0,1\}\([^"'\'' ]*\).*/\1/p' .ddev/config.yaml | head -1)
  docroot=${docroot:-web}
  [[ -f $docroot/core/scripts/run-tests.sh ]] || { echo "test.sh: нет $docroot/core/scripts/run-tests.sh" >&2; exit 2; }

  local CONC=${TEST_CONCURRENCY:-8} TYPES="PHPUnit-Unit,PHPUnit-Kernel"
  local SQLITE=0 URL=${TEST_BASE_URL:-http://localhost} REPEAT=1 VERBOSE=0 LIST=0 CLEAN=0
  local -a TARGETS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--concurrency) CONC=$2; shift 2 ;;
      --full) TYPES="$TYPES,PHPUnit-Functional"; shift ;;
      --js) TYPES="$TYPES,PHPUnit-FunctionalJavascript"; shift ;;
      --types) TYPES=$2; shift 2 ;;
      --sqlite) SQLITE=1; shift ;;
      --url) URL=$2; shift 2 ;;
      --repeat) REPEAT=$2; shift 2 ;;
      --clean) CLEAN=1; shift ;;
      --list) LIST=1; shift ;;
      -v|--verbose) VERBOSE=1; shift ;;
      -*) echo "test.sh: неизвестная опция $1" >&2; exit 2 ;;
      *) TARGETS+=("$1"); shift ;;
    esac
  done

  local RUN_ID OUT LOG RESULTS_DB DBURL
  RUN_ID=$(date +%Y%m%d-%H%M%S)-$$
  OUT=/var/www/html/.test-results
  rm -rf "$OUT/junit"; mkdir -p "$OUT/junit"
  LOG="$OUT/last.log"
  RESULTS_DB="/tmp/run-tests-$RUN_ID.sqlite"   # служебная БД раннера, не БД сайта
  export BROWSERTEST_OUTPUT_DIRECTORY=${BROWSERTEST_OUTPUT_DIRECTORY:-/tmp/browser_output}
  mkdir -p "$BROWSERTEST_OUTPUT_DIRECTORY"

  SQLITE_DIR=
  if [[ $SQLITE == 1 ]]; then
    SQLITE_DIR="/tmp/test-sqlite-$RUN_ID"; mkdir -p "$SQLITE_DIR"
    DBURL="sqlite://localhost/$SQLITE_DIR/db.sqlite"
  else
    # Отдельная БД phpunit в db-контейнере этого ddev-проекта; БД сайта (db) не трогается.
    mysql -uroot -proot -hdb -e "CREATE DATABASE IF NOT EXISTS phpunit; GRANT ALL ON phpunit.* TO 'db'@'%';" 2>/dev/null </dev/null
    DBURL="mysql://db:db@db/phpunit"
  fi
  RESULTS_DB_CLEAN=$RESULTS_DB
  trap 'rm -f "$RESULTS_DB_CLEAN"; [[ -n $SQLITE_DIR ]] && rm -rf "$SQLITE_DIR"; true' EXIT

  # Без IS_DDEV_PROJECT settings.php не подключает settings.ddev.php: раннер не грузит
  # установленный сайт (иначе ищет его таблицы, например locales_source, в БД phpunit).
  local -a RT=(env -u IS_DDEV_PROJECT php core/scripts/run-tests.sh --sqlite "$RESULTS_DB"
    --dburl "$DBURL" --url "$URL" --non-html --suppress-deprecations)

  if [[ $CLEAN == 1 ]]; then
    (cd "$docroot" && "${RT[@]}" --clean </dev/null)
    exit 0
  fi

  # Подкаталоги tests/src/ для выбранных типов.
  local -a type_dirs=() _types=() files=() groups=()
  local t m f
  IFS=, read -ra _types <<<"$TYPES"
  for t in "${_types[@]}"; do type_dirs+=("${t#PHPUnit-}"); done

  add_dir() {
    local d=${1%/} td x
    for td in "${type_dirs[@]}"; do
      # -L: модуль ddev-drupal-contrib — симлинк на корень проекта; его web/ и vendor/ отсекаем.
      while IFS= read -r x; do files+=("$x"); done < <(
        find -L "$d" \( -name vendor -o -name node_modules -o -name .git -o -path "$d/$docroot" \) -prune \
          -o -path "*/tests/src/$td/*" -name '*Test.php' -type f -print 2>/dev/null | sort)
    done
  }
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    for t in modules themes profiles; do [[ -d $docroot/$t/custom ]] && TARGETS+=("$docroot/$t/custom"); done
  fi
  for t in "${TARGETS[@]}"; do
    t=${t%/}
    if [[ -f $t ]]; then files+=("$t")
    elif [[ -d $t ]]; then add_dir "$t"
    else
      m=$(find "$docroot/modules" "$docroot/themes" "$docroot/profiles" -maxdepth 3 \( -type d -o -type l \) \
            -name "$t" -not -path '*/tests/*' 2>/dev/null | sort | head -1)
      if [[ -n $m ]]; then add_dir "$m"; else groups+=("$t"); fi
    fi
  done

  local -a args=() rel=()
  if [[ ${#groups[@]} -gt 0 ]]; then
    [[ ${#files[@]} -gt 0 ]] && { echo "test.sh: нельзя смешивать группы (${groups[*]}) с путями/модулями" >&2; exit 2; }
    args=(--types "$TYPES" "$(IFS=,; echo "${groups[*]}")")
    [[ $LIST == 1 ]] && { echo "группы: ${groups[*]}, типы $TYPES"; exit 0; }
  else
    [[ ${#files[@]} -eq 0 ]] && { echo "test.sh: нет тестов типов $TYPES в: ${TARGETS[*]}" >&2; exit 1; }
    # Пути от docroot (run-tests.sh работает из него).
    for f in "${files[@]}"; do
      if [[ $f == "$docroot"/* ]]; then rel+=("${f#"$docroot"/}"); else rel+=("../$f"); fi
    done
    args=(--file "$(IFS=,; echo "${rel[*]}")")
    if [[ $LIST == 1 ]]; then printf '%s\n' "${files[@]}"; echo "${#files[@]} файлов, типы $TYPES"; exit 0; fi
  fi

  local dbname=mysql/phpunit what="${#files[@]} файлов" start rc dur
  [[ $SQLITE == 1 ]] && dbname=sqlite
  [[ ${#groups[@]} -gt 0 ]] && what="группы ${groups[*]}"
  echo "test.sh: $TYPES, потоков $CONC, БД $dbname, $what"
  start=$(date +%s)
  set +e
  (cd "$docroot" && "${RT[@]}" --concurrency "$CONC" --repeat "$REPEAT" --xml "$OUT/junit" "${args[@]}" \
     </dev/null >"$LOG" 2>&1)
  rc=$?
  set -e
  dur=$(( $(date +%s) - start ))

  if [[ $VERBOSE == 1 ]]; then
    cat "$LOG"
  else
    # Итоги по классам и общий итог run-tests.sh, без заголовков и списка файлов.
    grep -E '^(Drupal\\|Test run duration|Detailed test results|ERROR|PHP (Fatal|Parse))|passed|failed|exception' "$LOG" \
      | grep -vE '^\s*$' | tail -n 200 || true
  fi

  # Падения по junit: класс::метод и первые строки сообщения.
  # shellcheck disable=SC2016  # PHP-код, $ не для bash
  php -r '
$n = 0;
foreach (glob($argv[1] . "/*.xml") as $f) {
  $x = @simplexml_load_file($f); if (!$x) continue;
  foreach ($x->xpath("//testcase[failure or error]") as $tc) {
    $n++;
    $msg = (string) ($tc->failure ?: $tc->error);
    $msg = implode("\n      ", array_slice(explode("\n", trim($msg)), 0, 12));
    $cls = (string) ($tc["class"] ?: $tc["classname"]);
    echo "  FAIL " . ($cls !== "" ? "$cls::" : "") . "{$tc["name"]}\n      $msg\n";
  }
}
if ($n) echo "-- упавших тест-методов: $n\n";
' "$OUT/junit" </dev/null

  echo "test.sh: код $rc, $dur с; лог .test-results/last.log"
  exit "$rc"
}

main "$@"
