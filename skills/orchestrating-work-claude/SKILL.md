---
name: orchestrating-work
description: Use when a user asks for any non-trivial task that may involve research, planning, external URLs, multiple files, multiple subsystems, audits, migrations, SEO, design, debugging, or implementation. Especially use when work can split into independent investigation, execution, review, or verification streams.
---

# Orchestrating Work (Claude Code)

## Core principle

The main session is the head; subagents are eyes and hands. Delegate gathering, mechanical
work, execution of a ready spec, and verification. Keep for yourself: choosing between options,
priorities, synthesis of findings into conclusions, architecture, specs. A decision handed to a
cheaper model is not a saving — it replaces the most capable judge with the least capable one.

## Start gate

| Classification | Meaning | Action |
|---|---|---|
| Trivial | One short answer or one obvious operation | Inline. |
| Single-stream | One coherent path; delegation adds overhead | Inline, verify normally. |
| Multi-stream | Independent research / implementation / review / verification streams | Subagents before synthesis. |

Multi-stream by default: several external URLs or categories, migrations, catalog/document
extraction, multi-file code changes, cross-subsystem debugging, SEO audits, UI redesigns,
implementation plus testing/review, anything that means reading bulk (logs, transcripts, dumps,
an unknown tree) — bulk belongs in a subagent's context, not the main one.

If a task is non-trivial and you skip subagents, say why before doing the work.

Do not spawn for: a simple factual answer, a one-line change, a clarification question, streams
that would edit the same files, work the user wants inline, or when the next step is asking
the user.

## Routing: agent × model × effort

Every dispatch sets `model` and `effort` explicitly on the Agent tool — this skill is the
explicit instruction the tool requires. Walk top-down, take the first matching row.

| # | Stream | `subagent_type` | `model` | `effort` |
|---|---|---|---|---|
| 1 | Locate: find files/symbols, grep, list, count, extract fields — result fits in the reply | `Explore` | `haiku` | `low` |
| 1b | Collect: exhaustive list («every place where…»), data to a file, bulk logs by script | `general-purpose` | `haiku` | `low` |
| 2 | Understand: how a module works, summary of a document/site, compare sources, map a tree | `general-purpose` | `sonnet` | `medium` |
| 3 | Execute a ready spec: code, tests, config, mechanical edits, `gh` operations | `general-purpose` | `sonnet` | `medium` |
| 4 | Verify: run the DoD checks / scenario and report pass / fail / unverifiable | `general-purpose` | `sonnet` | `medium` |
| 5 | Debug across subsystems, root cause unknown | `general-purpose` | `sonnet` | `high` |
| 6 | Judge: code review, security review, plan review against the codebase | `general-purpose` | `opus` | `high` |
| 7 | Draft plan options for a large change, read-only | `Plan` | `opus` | `high` |

Escalation, not default:

- Row 3 returned twice by the verifier with diagnosis «under-thought» → same row at `high`.
- Row 5 failed twice → `opus`, `high`.
- `fable` only when the user asks for it.
- `xhigh` / `max` — never for subagents unless the user asks. The main session cannot raise its
  own effort: on a genuinely hard architectural fork, ask the user to raise it.

Failure ladder for an executor (row 3): verifier fails it → rework by `SendMessage` to the same
executor with the verifier's points (at most twice) → fresh executor with clean context plus the
verifier's diagnosis → stop that stream and report what was tried, where it fails, and a
hypothesis; independent streams continue.

Haiku notes: good at finding, weak at weighing. Its prompt uses only «find, list, count, quote,
extract, run»; never «decide, assess, suggest, which is better». For multi-MB logs it writes a
one-liner (grep/awk/jq/`python -c`) and returns numbers; it does not read the files.

`Explore` limits (official docs): it does not load CLAUDE.md / AGENTS.md or git status, reads
excerpts and picks its own depth, cannot write files, and cannot be resumed — a weak answer
means a new agent. So its prompt carries the project rules that matter for the search (secrets,
paths not to touch), and when completeness matters it must return the full list, the count and
the exact search used — or the stream goes to row 1b. Hooks from settings files still apply
inside every subagent. Full subagent transcripts stay in
`~/.claude/projects/<project>/<session>/subagents/` for 30 days.

Judgment rows (6–7) run on `opus` because a cheap reviewer approves broken work. The
verifier (row 4) is never the agent that did the work.

Specialised agent types (`gsd-*`, `vercel:*`, `claude-code-guide`) are used when their own
workflow or the user calls for them; they are outside this ladder — omit `model`/`effort`,
their definitions set them. For a review of the current diff, `/code-review` is an alternative
to row 6; it never sees the findings rule, so the main session triages its output per Findings
triage.

## Facts, not judgment

A scout returns facts: `file:line`, URLs, numbers, quotes, complete lists with objective
attributes (dates, sizes, metrics). When a choice among N things is needed, the scout returns all
N with attributes; the main session picks.

## Assignment contract

Each prompt is self-contained — the subagent sees nothing of this conversation:

- **Role and goal** — one line.
- **Scope** — exact targets and explicit non-goals; what was already ruled out.
- **Output** — the facts or artifact to return, and the length limit.
- **Report file** (agents that can write — `general-purpose`; `Explore` and `Plan` cannot and
  return the full digest inline) — «write the full report to `<scratchpad>/reports/<name>.md`; reply with a
  digest of ≤15 lines plus that path». The digest must carry everything needed to decide
  (quotes, numbers, verdicts) — deciding by pointer without seeing the fact is not allowed.
  Hand data between agents by that path, not through the main context.
- **Constraints** — no broad rewrites, no unrelated cleanup, no project-wide tests unless
  assigned; browser checks headless only (the user works in their own browser).
- **Findings rule**, verbatim in every assignment that edits or reviews code: «classify each
  problem you find as `introduced` (this task broke it: fix it), `surfaced` or `unrelated`
  (pre-existing: do NOT fix, report with likelihood + blast radius and let the coordinator
  decide)».
- **Surprise rule** for executors: «if reality contradicts the spec (file missing, contract
  differs, step impossible) — STOP and report the mismatch; do not improvise around it».

Dispatch independent agents in one message so they run in parallel. Streams that touch the same
files run sequentially; groups that do not overlap may run in parallel, each in its own worktree
(`isolation: "worktree"`).

## While agents run

Do not idle-wait: write the next spec, resolve forks, prepare synthesis. Never predict or
report a pending agent's result.

- Notification without a report → read its report file; if none, `SendMessage` asking it to
  resend the report.
- Agent died mid-task (session limit) → successor's prompt starts with auditing what the
  predecessor left (`git status`, `git log`, uncommitted files); accept correct partial work.

## Plans

A written plan is reviewed before anyone codes from it. A `Plan` agent (row 7) only drafts
options inline; the main session decides, saves the plan to a file, and that file is reviewed —
same for a plan you wrote or one that came from elsewhere. Review
with row 6 (read-only, checks named files and symbols against the repo). The verdict is advice:
disagree with a reason, fix the plan, then execute. Skip only for a single-step change with no
plan document.

## Large GitHub-backed tracks

Several independently executable issues, multi-session work, Project board: the issue body is
the spec (self-contained, with a DoD that a verifier can run and that fails on a broken
solution — mentally break it and confirm the check catches it; no «probably / likely» in a
spec), the executor gets a short
envelope pointing at it, a separate verifier (row 4) accepts, and only then the issue is
closed. Executors never write `closes #N` / `fixes #N` in commits — GitHub would close the issue
before acceptance. Status, labels and board sync go through the `manager` skill.

Synthesis tasks (guides, digests, summaries of sources) carry a «source of truth» path in the
spec, and the verifier diffs each claim against the source quote — agreement between two derived
copies is not truth; watch connectives added during compression («always», «after», «so»).

## Beads (`bd`) in repos that have `.beads/`

Only `general-purpose` subagents see the Beads rules (via AGENTS.md); `Explore` and `Plan` do
not, and SessionStart hook output (`bd prime`) is not documented to reach any subagent. Embedded
Dolt allows one writer, so parallel `bd` writes queue on the lock.

- The main session creates, claims and closes beads; the executor gets the bead id and its
  acceptance criterion in the prompt.
- Project memories (`bd remember`) reach the main session at start, not subagents: copy the
  ones that bear on the task (access paths, «don't touch», client rules) into the assignment.
- An executor may write progress only to its own bead: `bd update <id> --notes "<checkpoint>"`
  after each finished step — so if it hangs or dies, the next executor starts from the notes.
- Findings outside scope come back in the report («noticed, not touched»); the main session turns
  them into `discovered-from` beads. Close only after the verifier passes:
  `bd close <id> --reason "<what was checked>"`.

## Findings triage

| Category | Meaning | Action |
|---|---|---|
| `introduced` | This task broke it | Fix inside this task, no question. |
| `surfaced` | Pre-existing, observable only because of this task | Do NOT fix. Report and ask. |
| `unrelated` | Pre-existing, noticed in passing | Do NOT fix. Report and ask. |

For `surfaced` / `unrelated` give **likelihood** (`certain` / `likely` / `rare` /
`theoretical`, with the trigger) and **blast radius** (what breaks, reversible or not), then ask
one question: fix now, or record as debt and open a separate task. Severity changes urgency, not
authority.

Record two process signals: a fix in one module broke another (wrong boundary); more than one
`introduced` finding outside the assigned files (task should have been split).

## Review phase

Non-trivial deliverables get one final review (row 6): original request and acceptance
criteria, missing outputs, unsupported claims, contradictions between agents, verification
evidence. The reviewer reports, classified per triage, and never edits. If skipped, say why.

## Final orchestration audit

```text
Orchestration:
- Agents: <role → model/effort> or none
- Contributions: <one line each>
- Review/spec check: <by whom, or why skipped>
- Findings: <n introduced, fixed> / <n surfaced> / <n unrelated> — or none
```

Without subagents on a non-trivial task: `Orchestration: no subagents used because <reason>.`
