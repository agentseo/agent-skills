# Decisions

## 2026-09-21 — uptool: auto-install tier for vendor self-updaters

**Problem.** `uptool` prompted per group, so routine updates needed a human keystroke each time,
and `herdr update` left the agent-side integration hooks stale (`omp v6 < v10`, `claude v7 < v10`,
…) with no follow-up check anywhere — the warning was printed once by herdr and never again,
while stale hooks silently degrade pane/agent state detection.

**Decision.** Split `uptool` into two tiers.

- *Auto tier*, installed without prompting in the default run: omp, npm globals
  (claude, codex), grok, herdr, and outdated herdr integrations. Criterion: the update path is
  a vendor-owned self-updater or npm — no third-party shell script is fetched and executed.
- *Exec / review tier*, unchanged: rtk (`curl | sh`, pinned + SHA-256-verified, `-a` only),
  own repo and external skills (`skill-sync`, always reviewed).

`ask()` removed, replaced by `auto()`, which only logs and is stopped solely by `--check`.
`-y` becomes a no-op kept for scripts. New `grok` section gated on `grok update --check --json`;
new `herdr integrations` section reinstalls only entries reported `outdated` by
`herdr integration status` — `not installed` is never added, so the 18 supported agents do not
get hooks the user never asked for.

**Risks.** Unattended installs can pull a broken vendor release; accepted, because all five
updaters are already trusted to run on demand and each is version-gated before it fires.
Every check fails closed: unreadable manifest/JSON, non-zero rc, or timeout skips the group
without installing. herdr is still refused inside a herdr session (`HERDR_PANE_ID`), since
replacing the binary under the running server breaks live panes.

**Verification.** `bash -n` clean; `uptool -c` reported grok 1.0.30 → 1.0.34 and installed
nothing; bare `uptool` printed `auto: grok update`, installed 1.0.34 (`grok --version` confirms),
and reported all herdr integrations up to date after the five were refreshed
(`herdr integration status --outdated-only` empty).
