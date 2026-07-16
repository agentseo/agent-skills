# agent-skills

Private source of truth for my own Claude Code / OMP agent skills.

## Layout

```
skills/<name>/SKILL.md      my own skills (edited here, symlinked into the agent dirs)
bin/skill-link              bootstrap: symlink every skill into ~/.claude/skills (+ ~/.omp/agent/skills)
bin/skill-sync              fail-closed updater for third-party skills
external-skills.tsv         third-party skills — only their reviewed/pinned commit is tracked here
```

Skills are the **source of truth in this repo** and are **symlinked** into the agent
directories — never copied. Edit here, commit, push. On a new machine:

```bash
git clone git@github.com:agentseo/agent-skills.git ~/skills
~/skills/bin/skill-link          # or --check to preview
```

## Own vs external

- **Own skills** (`skills/`): authored/maintained by me. `ceo-council`, `claude-md-writer`,
  `manager`, `weekly-planning`, `weekly-retro` originated in my public
  `serejaris/personal-corp-skills`; the rest are OMP/personal. Update = edit + commit + push.
- **External skills** (`external-skills.tsv`): third-party repos (e.g. `humanizer-ru`,
  `threads-carousel`). Their content is **not** vendored here — only a reviewed, pinned commit.
  They live as read-only clones in `~/.claude/skills/<name>` and are **never edited in place**.

## Updating external skills — fail-closed

Third-party skills are executable instructions (supply-chain surface), so updates never
auto-apply:

1. `skill-sync check` — fetch (no checkout), emit an immutable review bundle:
   `pinned..candidate` diff, new URLs/domains, new/changed executables, and a heuristic
   HIGH-RISK gate.
2. An **independent reviewer** reads the bundle. The heuristic gate can only *block*, never approve.
3. `skill-sync apply <name>` — after review, fast-forward to the reviewed SHA and re-pin the
   manifest. Interactive confirmation required; a HIGH-RISK bundle demands an explicit
   `reviewed-ok`. Never bypassed by any `-y`.

## Status / updates overview

`~/.local/bin/uptool` reports update status across omp, npm globals, rtk, this repo, and
external skills in one place. It routes external-skill updates through `skill-sync`.
