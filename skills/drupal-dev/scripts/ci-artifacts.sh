#!/usr/bin/env bash
# Статус пайплайна GitLab CI drupal.org и артефакты заданий — без входа, через публичный API.
# Лог задания (trace) требует входа (401), а артефакты (junit, phpstan, codequality,
# html-вывод браузерных тестов) публичны.
#
#   ci-artifacts.sh PROJECT [SHA|REF]            пайплайны коммита и их задания
#   ci-artifacts.sh PROJECT [SHA|REF] --get [JOB] скачать артефакты: JOB = id или имя задания;
#                                                без JOB — всех упавших заданий последнего пайплайна
#   опции: --out DIR (по умолчанию ./ci-artifacts), --pipeline ID (вместо поиска по SHA)
#
# PROJECT — машинное имя проекта drupal.org (my_module) или путь (project/x, issue/x-123).
# SHA|REF — по умолчанию HEAD текущего git-репозитория; имя ветки/тега разворачивается локально.
# Архивы распаковываются в DIR/<job_id>-<имя>/ — это чужие данные: читать, не исполнять.
# Сайты drupal.org (страницы проектов) за бот-проверкой: её не обходить, только этот API.
set -euo pipefail

API=https://git.drupalcode.org/api/v4
die() { echo "ci-artifacts.sh: $*" >&2; exit 1; }
usage() { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
need() { command -v "$1" >/dev/null || die "нужна утилита $1"; }
need curl; need jq

project='' rev='' get=0 job='' out=./ci-artifacts pipeline=''
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --get) get=1; if [[ ${2:-} != "" && ${2:-} != --* ]]; then job=$2; shift; fi; shift ;;
    --out) out=$2; shift 2 ;;
    --pipeline) pipeline=$2; shift 2 ;;
    -*) die "неизвестная опция $1" ;;
    *) if [[ -z $project ]]; then project=$1; elif [[ -z $rev ]]; then rev=$1; else die "лишний аргумент $1"; fi; shift ;;
  esac
done
[[ -n $project ]] || { usage; exit 2; }
[[ $project == */* ]] || project="project/$project"

api() { curl -fsS --retry 2 "$API/$1"; }

pid=$(api "projects/${project//\//%2F}" | jq -r .id) || die "проект $project не найден в git.drupalcode.org"

if [[ -z $pipeline ]]; then
  rev=${rev:-HEAD}
  if [[ ! $rev =~ ^[0-9a-f]{40}$ ]]; then
    sha=$(git rev-parse --verify -q "$rev^{commit}" 2>/dev/null) || die "не разворачивается в коммит: $rev (дайте полный SHA)"
  else
    sha=$rev
  fi
  pipes=$(api "projects/$pid/pipelines?sha=$sha&per_page=20")
  [[ $(jq length <<<"$pipes") -gt 0 ]] || die "пайплайнов для $sha нет (ещё не запущен или коммит не запушен)"
  echo "проект $project (id $pid), коммит ${sha:0:12}"
  jq -r '.[] | "  pipeline \(.id)  \(.status)  \(.ref)  \(.created_at)  \(.web_url)"' <<<"$pipes"
  pipeline=$(jq -r '.[0].id' <<<"$pipes")
fi

jobs=$(api "projects/$pid/pipelines/$pipeline/jobs?per_page=100")
echo "задания pipeline $pipeline:"
jq -r '.[] | [.id, .stage, .name, .status, ((.artifacts // []) | map(.file_type) | map(select(. != "trace" and . != "metadata")) | join(","))]
       | @tsv' <<<"$jobs" | sort -t$'\t' -k1,1n | awk -F'\t' '{printf "  %-10s %-9s %-28s %-9s %s\n", $1, $2, $3, $4, $5}'
echo "  (manual/skipped у previous major / next minor — норма: эти задания ручные даже с OPT_IN_*)"

[[ $get == 1 ]] || exit 0

if [[ -z $job ]]; then
  mapfile -t ids < <(jq -r '.[] | select(.status == "failed") | .id' <<<"$jobs")
  [[ ${#ids[@]} -gt 0 ]] || { echo "упавших заданий нет"; exit 0; }
elif [[ $job =~ ^[0-9]+$ ]]; then
  ids=("$job")
else
  mapfile -t ids < <(jq -r --arg n "$job" '.[] | select(.name == $n) | .id' <<<"$jobs")
  [[ ${#ids[@]} -gt 0 ]] || die "задания «$job» в pipeline $pipeline нет"
fi

mkdir -p "$out"
for id in "${ids[@]}"; do
  name=$(jq -r --argjson i "$id" '.[] | select(.id == $i) | .name' <<<"$jobs")
  name=${name//[^A-Za-z0-9._-]/_}
  dest="$out/$id-${name:-job}"; zip="$out/$id.zip"
  if ! curl -fsSL -o "$zip" "$API/projects/$pid/jobs/$id/artifacts"; then
    echo "  $id: артефактов нет или они истекли"; continue
  fi
  rm -rf "$dest"; mkdir -p "$dest"
  if command -v unzip >/dev/null; then
    unzip -qo "$zip" -d "$dest" && rm -f "$zip"
    echo "  $id → $dest"; (cd "$dest" && find . -type f | sort | sed 's/^/      /' | head -40)
  else
    echo "  $id → $zip (нет unzip)"
  fi
  # Короткая выжимка упавших тестов из junit.
  find "$dest" -name '*.xml' -size +0 2>/dev/null | while IFS= read -r x; do
    grep -q '<testsuite' "$x" || continue
    python3 -I - "$x" <<'PY' || true
import sys, xml.etree.ElementTree as ET
t = ET.parse(sys.argv[1])
bad = [tc for tc in t.iter('testcase') if tc.find('failure') is not None or tc.find('error') is not None]
for tc in bad[:30]:
    el = tc.find('failure') if tc.find('failure') is not None else tc.find('error')
    msg = ((el.get('message') or el.text or '').strip().splitlines() or [''])[0][:200]
    print(f"      FAIL {tc.get('classname') or tc.get('class') or ''}::{tc.get('name')}  {msg}")
if bad: print(f"      -- {len(bad)} упавших в {sys.argv[1]}")
PY
  done
done
