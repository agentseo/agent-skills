# agent-skills

Source of truth for a set of Claude Code / OMP agent skills, plus fail-closed tooling for
updating both the skills kept here and third-party ones pinned by commit.

The skills are written for one person's workflow: every account-specific value (GitHub owner,
project board ids, repository lists) is a placeholder you fill in your own `CLAUDE.md`.

## Layout

```
skills/<name>/SKILL.md   my own skills — edited here, symlinked into the agent dirs
bin/skill-link           bootstrap: symlink skills into ~/.claude/skills; OMP-only ones into ~/.omp/agent/skills
bin/skill-sync           fail-closed updater (external skills + any git repo, incl. this one)
bin/uptool               updater across omp, npm globals, grok, herdr (+integrations), rtk, skills
external-skills.tsv       third-party skills — only their reviewed/pinned commit is tracked
hooks/<name>             shared hook scripts, one logic for Claude/Codex/OMP (linked into ~/.local/bin)
adapters/omp/*.ts        OMP extensions calling hooks/* (linked into ~/.omp/agent/extensions)
```

Skills are the **source of truth in this repo** and are **symlinked** into the agent dirs —
never copied. Edit here, commit, push. On a new machine:

```bash
git clone git@github.com:agentseo/agent-skills.git ~/skills
~/skills/bin/skill-link          # or --check to preview
```

`skill-link` is idempotent and does everything a new machine needs: symlinks each skill into
`~/.claude/skills`, the OMP-only ones (`OMP_ONLY`: `omp-ruki-agenty`, `orchestrating-work`)
into `~/.omp/agent/skills` instead, and Claude variants (`CLAUDE_AS`, e.g.
`orchestrating-work-claude` → `~/.claude/skills/orchestrating-work`) under their Claude name; symlinks `skill-sync`,
`skill-link`, and `uptool` into `~/.local/bin` (repo stays the single source of truth), and
clones each external skill into its target at its pinned commit. Ensure `~/.local/bin` is on
`PATH`.

## Own vs external

- **Own skills** (`skills/`): authored/maintained by me. `ceo-council`, `claude-md-writer`,
  `manager`, `weekly-planning`, `weekly-retro` originated in my public
  `serejaris/personal-corp-skills`; the rest are OMP/personal. `drupal-dev` (shared by all Drupal projects) ships
  executable helper scripts in `scripts/` — the skill-sync object inspector flags new
  executables, so expect a reviewer override on first sync. Update = edit + commit + push.
- **External skills** (`external-skills.tsv`): third-party repos (`humanizer-ru`,
  `threads-carousel`). Content is **not** vendored — only a reviewed, pinned commit. They live
  as read-only clones in `~/.claude/skills/<name>` and are **never edited in place**.

## Fail-closed updates — security review before ANY update

Skills are executable instructions (supply-chain surface). No update — own repo or third-party
— is applied without a reviewed, hash-bound approval. `skill-sync` never blesses a diff; its
heuristic text gate and object inspector only **block**. An update applies only when a reviewer
report containing `verdict: approved` plus an approval artifact — bound to the exact baseline
SHA, candidate SHA, and SHA-256 of both the diff and the object inventory — exists and still
matches at apply time. `apply` also enforces: origin matches, `HEAD == baseline`, clean working
tree, and `baseline` is an ancestor of `candidate` (fast-forward only).

### Third-party skills (by name, from the manifest)

```bash
skill-sync check [name]                       # fetch (no checkout) -> bundle (.diff/.objects) + gates
# an independent reviewer reads the .diff and .objects (decoding any IMAGE-flagged binary),
# writes a report file containing a line `verdict: approved`
# (a BLOCKED bundle also needs a line `override-blocked: <candidate8>`)
skill-sync approve <name> <reviewer-id> <report-file>
skill-sync apply   <name>                     # verify + ff-only + re-pin manifest (commit the pin)
```

### Own repo / any git repo (by directory)

```bash
skill-sync inspect      <dir>                  # same review bundle + gates for HEAD..origin (current branch)
skill-sync approve-repo <dir> <reviewer-id> <report-file>
skill-sync apply-repo   <dir>                 # verify + ff-only pull (no manifest re-pin)
```

The object inspector fails closed on newly-added **symlinks** (mode 120000), **submodules**
(160000), **executable** files, and non-image **binaries**; images are surfaced for the reviewer
to decode. Every `apply`/`apply-repo` requires an interactive confirmation and is never
auto-approved.

## Status overview / auto-updates

`bin/uptool` is the single entry point for keeping the toolchain current. Two tiers:

**Auto tier — installed without prompting** (vendor self-updaters and npm, i.e. code paths the
vendor already owns): omp (`omp update` + `omp update -l`), npm globals (claude, codex),
grok (`grok update`, gated on `grok update --check --json`), herdr (`herdr update`, gated on
`herdr.dev/latest.json`), and **herdr integrations** — `herdr update` does not refresh the
agent-side hooks, so `uptool` reinstalls every integration reported `outdated` by
`herdr integration status`. Integrations marked `not installed` are never added.

**Exec / review tier — never automatic:** rtk (pinned + SHA-256-verified `curl | sh`, only under
`-a`), this repo (via `skill-sync inspect`, never auto-pulled), and external skills (via
`skill-sync check`). herdr is also skipped while the shell is inside a herdr session
(`HERDR_PANE_ID` set) — detach and run `herdr update` manually.

`uptool --check` reports only and installs nothing; `-y` is a no-op kept for scripts;
`-a` additionally reinstalls rtk.
