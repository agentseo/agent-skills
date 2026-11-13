#!/usr/bin/env bash
# cspell как в задании drupal.org GitLab CI, локально в стенде ddev-drupal-contrib.
#
#   contrib-cspell.sh <каталог contrib-проекта со стендом ddev-drupal-contrib>
#
# Конфиг собирается здесь же по правилам gitlab_templates scripts/prepare-cspell.php
# (флаг-слова e-mail/grey/queuing/..., словари ядра drupal + dictionary, .cspell-project-words.txt,
# части машинного имени, _CSPELL_WORDS / _CSPELL_IGNORE_PATHS / _CSPELL_FLAGWORDS из
# .gitlab-ci.yml). Чужой код не скачивается и не исполняется. Нужен cspell ядра:
# `ddev exec "cd web/core && yarn install"`. Временный конфиг — .ddev/.cspell-ci.json.
# Это приближение: окончательный вердикт — задание cspell в CI.
set -euo pipefail
dir=$(cd "${1:?путь к contrib-проекту}" && pwd)
cd "$dir"
[[ -d .ddev ]] || { echo "в $dir нет .ddev — сначала стенд ddev-drupal-contrib" >&2; exit 1; }

python3 - "$dir" <<'PY'
import json, os, re, sys
root = sys.argv[1]
name = os.path.basename(root)
ci = open(os.path.join(root, '.gitlab-ci.yml')).read() if os.path.exists(os.path.join(root, '.gitlab-ci.yml')) else ''
def var(k):
    m = re.search(r'^\s+%s:\s*(.*)$' % k, ci, re.M)
    return m.group(1).strip().strip('\'"') if m else ''
skip = ['web', 'vendor', 'node_modules', '.git', 'recipes', '.ddev']
parts = name.split('_')
found = []
for dp, dns, fns in os.walk(root):
    rel = os.path.relpath(dp, root)
    if rel.split(os.sep)[0] in skip:
        dns[:] = []
        continue
    for f in fns:
        if f.endswith('.info.yml'):
            parts += f[:-9].split('_')
        if f.split('.')[0].lower() in ('license', 'copyright', 'maintainers', 'changelog', 'composer'):
            found.append(os.path.normpath(os.path.join(rel, f)))
words = [w for w in var('_CSPELL_WORDS').replace('"', '').replace("'", '').replace(' ', '').split(',') if w]
words += parts + ['lando', 'ddev', 'endapply', 'nightwatchjs', 'testgroup', 'testgroups', 'backlinks', 'mdhash',
    'uploaders', 'vocabs', 'curlopt', 'returntransfer', 'curle', 'customrequest', 'failonerror', 'postfields',
    'followlocation', 'blocklisted', 'flagwords', 'mkdocs', 'autorun', 'runtests', 'dcms', 'browsertest',
    'chromedriver', 'dockerhub', 'drupalorg', 'drush', 'simpletest', 'minwordlength', 'iid', 'xdg']
flag = ['blacklist', 'blacklists', "blacklist's", 'blacklisted', 'e-mail', 'grey', 'queuing',
        'whitelist', 'whitelists', "whitelist's", 'whitelisted']
for w in [w for w in var('_CSPELL_FLAGWORDS').replace('"', '').replace(' ', '').split(',') if w]:
    w = w.strip("'")
    if w.startswith('-'):
        flag = [f for f in flag if f != w[1:]]
    else:
        flag.append(w)
ignore = skip + ['*.patch', '*.svg', '*_ignore_*', 'build.env', '**/.*.json', 'package.json', 'yarn.lock',
                 'phpstan*', '.*ignore'] + found
ignore += [p for p in var('_CSPELL_IGNORE_PATHS').replace('"', '').replace("'", '').replace(' ', '').split(',') if p]
W = '/var/www/html'
defs = [{'name': 'drupal', 'path': W + '/web/core/misc/cspell/drupal-dictionary.txt'},
        {'name': 'dictionary', 'path': W + '/web/core/misc/cspell/dictionary.txt'}]
if os.path.exists(os.path.join(root, '.cspell-project-words.txt')):
    defs.append({'name': 'project-words', 'path': W + '/.cspell-project-words.txt'})
cfg = {
    'language': 'en-US', 'allowCompoundWords': False, 'globRoot': W,
    'minWordLength': int(var('_CSPELL_MINWORDLENGTH') or 4),
    'ignorePaths': ignore, 'words': sorted(set(words)), 'flagWords': flag,
    'dictionaryDefinitions': defs,
    'dictionaries': ['companies', 'fonts', 'html', 'php', 'softwareTerms', 'misc', 'typescript', 'node', 'css',
                     'bash', 'filetypes', 'npm', 'lorem-ipsum', 'sql', 'fullstack'] + [d['name'] for d in defs],
    'overrides': [{'filename': '**/{*.engine,*.inc,*.install,*.module,*.profile,*.theme}', 'languageId': 'php'}],
}
json.dump(cfg, open(os.path.join(root, '.ddev', '.cspell-ci.json'), 'w'), indent=1)
PY

ddev exec -- bash -c 'web/core/node_modules/.bin/cspell -c .ddev/.cspell-ci.json --show-suggestions --show-context --no-progress --no-must-find-files .'
