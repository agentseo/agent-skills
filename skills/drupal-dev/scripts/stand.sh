#!/usr/bin/env bash
# Стенды для параллельных агентов: копия сайта Drupal как git worktree со своим
# ddev-проектом. У каждого агента свой стенд; два агента на одном стенде не работают.
#
#   stand.sh create N [--from REF] [--branch NAME] [--composer] [--no-start]
#   stand.sh list
#   stand.sh start N | stop N
#   stand.sh site N [--locale ru] [--profile standard] [--recipe PATH]...
#   stand.sh rm N [--force] [--delete-branch]
#
# Запускать из основного дерева проекта или из любого его стенда.
# Определяется само (переопределяется переменными окружения):
#   DDEV_REL     путь ddev-проекта (каталог с .ddev/) от корня git, "." или, например, "drupal"
#   STANDS_DIR   каталог стендов, по умолчанию <родитель репо>/<имя репо>-stands
#   STAND_PREFIX имя ddev-проекта стенда без -tN, по умолчанию name: из .ddev/config.yaml
#   STAND_COPY_DIRS  что копировать из основного дерева вместо composer install
#                    (через пробел, от корня ddev-проекта; по умолчанию vendor и contrib)
#   STAND_SITE_RECIPES  рецепты для `site` (через пробел, пути от корня ddev-проекта)
# Стенд N: каталог $STANDS_DIR/tN, ddev-проект $STAND_PREFIX-tN, ветка stand/tN.
set -euo pipefail

die() { echo "stand.sh: $*" >&2; exit 1; }
say() { echo "== $*"; }
usage() { sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

[[ ${1:-} == "" || ${1:-} == -h || ${1:-} == --help ]] && { usage; exit 0; }

# Основное дерево — первая запись git worktree list (работает и из самого стенда).
git rev-parse --show-toplevel >/dev/null 2>&1 || die "запускать внутри git-репозитория проекта"
CUR_TOP=$(git rev-parse --show-toplevel)
MAIN_REPO=$(git worktree list --porcelain | awk 'NR==1{print $2}')

if [[ -z ${DDEV_REL:-} ]]; then
  d=$PWD
  while [[ $d == "$CUR_TOP"* && ! -f $d/.ddev/config.yaml ]]; do d=$(dirname "$d"); done
  if [[ -f $d/.ddev/config.yaml && $d == "$CUR_TOP"* ]]; then
    DDEV_REL=${d#"$CUR_TOP"}; DDEV_REL=${DDEV_REL#/}; DDEV_REL=${DDEV_REL:-.}
  else
    mapfile -t cands < <(cd "$CUR_TOP" && find . -mindepth 2 -maxdepth 3 -path '*/.ddev/config.yaml' -not -path './vendor/*' | sort)
    [[ ${#cands[@]} -eq 1 ]] || die "не нашёл единственный .ddev/config.yaml (${#cands[@]}); задайте DDEV_REL"
    DDEV_REL=${cands[0]#./}; DDEV_REL=${DDEV_REL%/.ddev/config.yaml}
  fi
fi
MAIN_DDEV="$MAIN_REPO/$DDEV_REL"; MAIN_DDEV=${MAIN_DDEV%/.}
[[ -f $MAIN_DDEV/.ddev/config.yaml ]] || die "нет $MAIN_DDEV/.ddev/config.yaml"

yaml_val() { sed -n "s/^$1:[[:space:]]*[\"']\{0,1\}\([^\"' ]*\).*/\1/p" "$2" | head -1; }
DOCROOT=$(yaml_val docroot "$MAIN_DDEV/.ddev/config.yaml"); DOCROOT=${DOCROOT:-web}
MAIN_NAME=$(yaml_val name "$MAIN_DDEV/.ddev/config.yaml"); MAIN_NAME=${MAIN_NAME:-$(basename "$MAIN_DDEV")}
STAND_PREFIX=${STAND_PREFIX:-$MAIN_NAME}
STANDS_DIR=${STANDS_DIR:-$(dirname "$MAIN_REPO")/$(basename "$MAIN_REPO")-stands}

# Только код зависимостей composer, которого нет в git. Пользовательские файлы
# (sites/*/files, private), settings.local.php, дампы БД не копируются никогда.
if [[ -n ${STAND_COPY_DIRS:-} ]]; then
  read -ra COPY_DIRS <<<"$STAND_COPY_DIRS"
else
  COPY_DIRS=(vendor "$DOCROOT/core" "$DOCROOT/modules/contrib" "$DOCROOT/themes/contrib"
             "$DOCROOT/profiles/contrib" "$DOCROOT/libraries" drush/Commands/contrib)
fi
# Файлы, которые создаёт stand.sh в стенде (не коммитятся; rm их не считает правками).
STAND_FILES_RE='\.ddev/(config\.local\.yaml|docker-compose\.stand\.yaml|mysql/zz-stand-tests\.cnf)|\.test-results/'

stand_num() { [[ ${1:-} =~ ^[0-9]+$ ]] || die "нужен номер стенда (целое число), получено: '${1:-}'"; echo "$1"; }
stand_dir() { echo "$STANDS_DIR/t$1"; }
stand_ddev() { local p="$STANDS_DIR/t$1/$DDEV_REL"; echo "${p%/.}"; }
stand_project() { echo "$STAND_PREFIX-t$1"; }

cmd_create() {
  local n; n=$(stand_num "${1:-}"); shift
  local from=HEAD branch="stand/t$n" composer=0 start=1
  while [[ $# -gt 0 ]]; do
    case $1 in
      --from) from=$2; shift 2 ;;
      --branch) branch=$2; shift 2 ;;
      --composer) composer=1; shift ;;
      --no-start) start=0; shift ;;
      *) die "create: неизвестный аргумент $1" ;;
    esac
  done
  local dir proj d; dir=$(stand_dir "$n"); proj=$(stand_project "$n"); d=$(stand_ddev "$n")
  [[ -e $dir ]] && die "$dir уже существует"
  ddev describe "$proj" >/dev/null 2>&1 && die "ddev-проект $proj уже есть (ddev delete -Oy $proj)"
  mkdir -p "$STANDS_DIR"

  say "worktree $dir ($branch от $from)"
  if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$MAIN_REPO" worktree add "$dir" "$branch"
  else
    git -C "$MAIN_REPO" worktree add -b "$branch" "$dir" "$from"
  fi
  [[ -f $d/.ddev/config.yaml ]] || die "в ветке нет $DDEV_REL/.ddev/config.yaml"

  # Имя проекта и окружение тестов — в config.local.yaml (его игнорирует .gitignore ddev),
  # отслеживаемый config.yaml не трогаем.
  cat >"$d/.ddev/config.local.yaml" <<EOF
# Стенд t$n, создан stand.sh $(date +%F). Не коммитится.
name: $proj
web_environment:
  - DRUPAL_STAND=t$n
  - SIMPLETEST_BASE_URL=http://localhost
  - SIMPLETEST_DB=mysql://db:db@db/phpunit
  - BROWSERTEST_OUTPUT_DIRECTORY=/tmp/browser_output
hooks:
  post-start:
    # БД phpunit — каталог в tmpfs (docker-compose.stand.yaml); после рестарта она пустая.
    - exec: |
        mariadb -uroot -proot -e 'DROP DATABASE IF EXISTS phpunit' 2>/dev/null || true
        rm -rf /var/lib/mysql/phpunit
        mkdir -p /var/lib/mysql-tmpfs/phpunit
        ln -sfn /var/lib/mysql-tmpfs/phpunit /var/lib/mysql/phpunit
        mariadb -uroot -proot -e "GRANT ALL ON phpunit.* TO 'db'@'%'"
      service: db
EOF

  # Всё, что тесты пишут пачками (таблицы тестовых сайтов, sites/simpletest), — в память.
  # Без этого параллельный прогон на WSL упирается в диск, CPU простаивает.
  cat >"$d/.ddev/docker-compose.stand.yaml" <<EOF
# Стенд (stand.sh). Не коммитится.
services:
  db:
    tmpfs:
      - /var/lib/mysql-tmpfs:rw,mode=1777,size=8g
  web:
    tmpfs:
      - /var/www/html/$DOCROOT/sites/simpletest:rw,mode=1777,size=4g
EOF

  # БД стенда одноразовая: без fsync на каждую транзакцию, без doublewrite и binlog.
  mkdir -p "$d/.ddev/mysql"
  cat >"$d/.ddev/mysql/zz-stand-tests.cnf" <<'EOF'
# Стенд (stand.sh): БД одноразовая, надёжность записи не нужна.
[mysqld]
innodb_flush_log_at_trx_commit = 0
innodb_doublewrite = 0
sync_binlog = 0
skip-log-bin
EOF

  local lock_same=0 p
  [[ -f $d/composer.lock ]] && cmp -s "$MAIN_DDEV/composer.lock" "$d/composer.lock" && lock_same=1
  if [[ $composer == 0 && $lock_same == 1 ]]; then
    say "копирую зависимости из основного дерева (composer.lock совпадает)"
    for p in "${COPY_DIRS[@]}"; do
      if [[ -d $MAIN_DDEV/$p && ! -e $d/$p ]]; then
        mkdir -p "$(dirname "$d/$p")"
        cp -a "$MAIN_DDEV/$p" "$d/$p"
      fi
    done
  else
    [[ $lock_same == 0 ]] && say "composer.lock отличается от основного (или его нет) — нужен composer install"
    composer=1
  fi

  if [[ $start == 1 ]]; then
    (cd "$d" && ddev start -y >/dev/null) || die "ddev start не удался"
    if [[ $composer == 1 ]]; then
      say "ddev composer install"
      (cd "$d" && ddev composer install --no-interaction --no-progress)
    fi
    say "готов: $proj  https://$proj.ddev.site"
  else
    [[ $composer == 1 ]] && say "после ddev start выполнить: cd $d && ddev composer install"
  fi
  echo "   каталог:  $d"
  echo "   ветка:    $branch"
  echo "   тесты:    cd $d && test.sh [модуль|путь ...] [--full]"
}

cmd_list() {
  local found=0 line wt='' br='' n proj st
  while IFS= read -r line; do
    case $line in
      worktree\ *) wt=${line#worktree } ;;
      branch\ *) br=${line#branch refs/heads/} ;;
      "")
        if [[ $wt == "$STANDS_DIR"/t* ]]; then
          found=1; n=${wt##*/t}; proj=$(stand_project "$n")
          st=$(ddev describe "$proj" -j </dev/null 2>/dev/null \
               | python3 -c 'import json,sys;print(json.load(sys.stdin)["raw"]["status"])' 2>/dev/null || echo "нет проекта")
          printf '%-5s %-24s %-10s %-28s %s\n' "t$n" "$proj" "$st" "${br:-detached}" "$wt"
        fi
        wt=''; br='' ;;
    esac
  done < <(git -C "$MAIN_REPO" worktree list --porcelain; echo)
  [[ $found == 1 ]] || echo "стендов нет ($STANDS_DIR)"
}

cmd_start() { local n; n=$(stand_num "${1:-}"); (cd "$(stand_ddev "$n")" && ddev start -y); }
cmd_stop() { local n; n=$(stand_num "${1:-}"); ddev stop "$(stand_project "$n")"; }

cmd_site() {
  local n; n=$(stand_num "${1:-}"); shift
  local locale=en profile=standard r
  local -a recipes=()
  [[ -n ${STAND_SITE_RECIPES:-} ]] && read -ra recipes <<<"$STAND_SITE_RECIPES"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --locale) locale=$2; shift 2 ;;
      --profile) profile=$2; shift 2 ;;
      --recipe) recipes+=("$2"); shift 2 ;;
      *) die "site: неизвестный аргумент $1" ;;
    esac
  done
  local d; d=$(stand_ddev "$n")
  [[ -d $d ]] || die "нет стенда t$n"
  # Пустая установка: профиль + рецепты. Ни строки из боевой или dev-базы.
  (cd "$d" && ddev drush site:install "$profile" --locale="$locale" --account-name=admin \
      --account-pass=admin --site-name="Stand t$n" -y)
  for r in "${recipes[@]}"; do
    (cd "$d" && ddev drush recipe "/var/www/html/${r#./}" -y)
  done
  (cd "$d" && ddev drush cr)
  echo "сайт: https://$(stand_project "$n").ddev.site  (admin / admin, данных нет)"
}

cmd_rm() {
  local n; n=$(stand_num "${1:-}"); shift
  local force=0 delbranch=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --force) force=1; shift ;;
      --delete-branch) delbranch=1; shift ;;
      *) die "rm: неизвестный аргумент $1" ;;
    esac
  done
  local dir proj br='' dirty; dir=$(stand_dir "$n"); proj=$(stand_project "$n")
  if [[ -d $dir ]]; then
    br=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
    # vendor/ и прочие копии в .gitignore, git status их не видит; файлы стенда отсекаем.
    dirty=$(git -C "$dir" status --porcelain | grep -vE "$STAND_FILES_RE" || true)
    if [[ $force == 0 && -n $dirty ]]; then
      die "в $dir есть незакоммиченные изменения (закоммитьте или --force):"$'\n'"$dirty"
    fi
  fi
  ddev delete -Oy "$proj" >/dev/null 2>&1 || true
  [[ -d $dir ]] && git -C "$MAIN_REPO" worktree remove --force "$dir"
  git -C "$MAIN_REPO" worktree prune
  if [[ $delbranch == 1 && -n $br ]]; then
    git -C "$MAIN_REPO" branch -d "$br" || echo "ветка $br не слита — оставлена (git branch -D $br вручную)"
  elif [[ -n $br ]]; then
    echo "ветка $br оставлена"
  fi
  say "стенд t$n удалён"
}

case $1 in
  create) shift; cmd_create "$@" ;;
  list|ls) cmd_list ;;
  start) shift; cmd_start "$@" ;;
  stop) shift; cmd_stop "$@" ;;
  site) shift; cmd_site "$@" ;;
  rm|remove) shift; cmd_rm "$@" ;;
  *) usage; exit 1 ;;
esac
