---
name: omp-ruki-agenty
description: Use for strict orchestration when a task is a large GitHub-backed track — multiple independently executable issues, multi-session execution, epic/backlog/Project tracking, multiple repositories, coordinating multiple executors, dispatching executors against a spec with vague or unfalsifiable DoD, or closing/syncing an issue after an executor claims success but before independent acceptance verification has run.
---

# OMP Ruki Agenty — Strict Issue-First Track Pipeline

This skill governs only large GitHub-backed tracks. It is not a model router
and does not replace OMP primitives — it composes `task` batch subagents,
`manager` for all GitHub/Project state, OMP model roles, and IRC/Agent Hub
follow-up into one disciplined pipeline: discovery → specification →
independent audit → execution → independent acceptance → close/sync.

`orchestrating-work` remains the default for everything else, including
ordinary bugs, ordinary multi-file features, and research whose deliverable
is a single report or plan — those explicitly stay outside this skill.
`manager` remains the sole GitHub process implementation; this skill decides
when and why to call it and never reimplements its read/write contract,
invariants, or Project sync — see `skill://manager`.

## Required primitives

Every workflow description this skill produces, and every actual execution
of that workflow, must name these three primitives explicitly and
literally — not describe their function in generic terms:

- `manager` — every GitHub/Project read and write. A step described only
  as "read the issues" or "check the Project" does not satisfy this;
  `manager` must be named as the thing doing it.
- a fresh `SpecAuditor` task agent, dispatched before any executor — never
  the authoring agent, another pass of the same planning flow, or a
  checklist section inside the specification itself.
- a fresh `AcceptanceVerifier` task agent, dispatched after implementation
  and before close — never the executor's own report, a "reviewer" step
  folded into the same session, or a self-check against the DoD.

A generic checklist, a self-review step, or a role restated in prose
without a distinct, freshly dispatched `task` agent does not satisfy the
Spec Auditor or Acceptance Verifier requirement, however thorough the
checklist looks.

`manager` read establishes existing issue, parent, label, and Project
state before any epic, Project, or issue is created. `manager` close/sync
writes happen only after the Acceptance Verifier returns `passed`.

## Activation gate

Activate automatically when **at least one** strong signal is present:

- work is explicitly expected to span multiple sessions;
- the user requests multiple GitHub issues, an epic, track, Project, or backlog management;
- the work spans multiple repositories;
- the request requires coordinating multiple executors;
- there are at least three independently executable tasks with separate acceptance;
- the requested flow explicitly names discovery, specification, execution, verification, and tracking;
- the user asks to decompose and operate a large implementation track.

**None of these trigger strict mode alone** (near-miss — stay in ordinary orchestration):

- multiple files;
- two subagents;
- multiple URLs;
- tests plus implementation;
- a substantial but single-cycle bug or feature;
- a research task whose deliverable is only one report or plan.

If classification is uncertain, default to the ordinary `orchestrating-work`
flow, not to issue creation. Strict mode must never impose GitHub process
overhead without a strong track signal, and ordinary multi-file work or
one-report research must never be routed through the issue-first pipeline
below.

## Preflight

Before creating or changing any issue, confirm:

- the current repository or repositories are known;
- GitHub access is available through `manager`;
- the target issue/Project scope is identifiable;
- existing issues are read (via `manager` read mode) before any new ones are created;
- the main and task model roles resolve to available models.

**Blocking rule:** if GitHub access, repository identity, or Project
ownership is unavailable, stop before issue creation and report the exact
missing prerequisite. Never silently replace the issue-first contract with
local files.

**Model-separation disclosure:** the Spec Auditor should resolve to a model
role different from the main author, and the Acceptance Verifier should
resolve to a model role different from the executor, when available. If
separation cannot be established, disclose it in the pipeline status and
require especially strong command/scenario evidence — never claim
independent-model review when it isn't independent.

## Pipeline

```text
manager read
→ batch scouts
→ main decisions and decomposition
→ issue specs
→ fresh Spec Auditor
→ executors
→ fresh Acceptance Verifier
→ rework or manager close/sync
```

1. Detect a large track (activation gate above).
2. `manager` read mode establishes existing issue, parent, label, and Project state — before any writes.
3. Dispatch independent scouts in a single `task` batch where possible.
4. Main agent resolves product and architecture decisions from grounded scout facts.
5. Main agent decomposes the track into independently executable issues.
6. Main agent writes a self-contained specification (Issue specification contract) into each executable issue.
7. A fresh Spec Auditor agent checks each specification before dispatch.
8. Failed specification audits return to the main agent for correction, then re-audit.
9. Passing specifications are dispatched to scoped executors, independent ones batched together.
10. A fresh Acceptance Verifier checks the implementation against the issue's acceptance criteria and DoD.
11. Failed acceptance enters the rework ladder.
12. Passing work is closed and synchronized through `manager`.
13. Blocked work records the exact missing prerequisite and observed evidence; it stays open.

**Hard gate 1:** no executor is dispatched against a specification that has
not received a Spec Auditor `pass`.

**Hard gate 2:** no issue closes — including via commit-message closing
keywords — before the Acceptance Verifier returns `passed`.

## Responsibility boundaries

### Main Agent

Owns judgment: product decisions, architecture decisions, task boundaries
and dependencies, priority, issue specification content, conflict
resolution between findings, and the `close` / `rework` / `blocked` call.
May use normal OMP tools directly — no legacy restriction on reading code,
running commands, or making edits applies here.

### Scouts

Gather evidence only. Prompts use operations such as find, list, measure,
quote, compare, run — and return `file:line`, URLs, numbers, or complete
enumerations. Scouts do not choose product direction, make architecture
decisions, or write the final strategy. When a choice is needed, a scout
returns all material options with objective attributes, not a
recommendation.

### Spec Auditor

A fresh agent, distinct from the main author, checks each specification for:

- coverage of the original request;
- self-contained context and contract;
- resolved product and architecture branches;
- explicit scope and non-goals;
- dependencies and execution order;
- falsifiable acceptance criteria and DoD;
- absence of placeholders and unsupported uncertainty;
- consistency with related issues and scout evidence.

Verdicts: `pass`; `fail` with exact corrections; `unverifiable` with the
missing prerequisite. Executors cannot start before `pass`.

### Executors

Use the issue body as the execution contract. Stay within the specified
scope; never introduce new product decisions. Stop and report when
repository reality contradicts the specification. Return changed files,
verification performed, deviations, and a `Noticed, not changed` section.
Independent tasks run in one batch; tasks that share files or depend on an
upstream contract are sequenced.

### Acceptance Verifier

A fresh verifier that does not trust the executor's report:

- runs the issue's DoD and acceptance scenarios itself;
- records the command or scenario and observed result per criterion;
- returns `passed`, `failed`, or `unverifiable`;
- never repairs the implementation;
- never closes the issue.
- `unverifiable` keeps the issue open and records the exact missing prerequisite; it never counts as pass.

## Issue specification contract

Every executable issue must contain all nine sections. Specification
uncertainty must be explicit evidence or a resolved decision — `probably`,
`likely`, `apparently`, `TBD`, and unresolved `TODO` are Spec Auditor
failures whenever they affect execution.

```markdown
## Goal
<user-visible outcome after completion>

## Context
<repository, files, symbols, contracts, dependencies, discovered traps>

## Contract
<signatures, schemas, fields, message formats, URLs, states, errors>

## Resolved Decisions
<chosen option — rejected alternatives — concise rationale>

## Changes
<specific affected areas and expected behavior changes>

## Boundaries
<explicit non-goals and forbidden scope expansion>

## Acceptance Criteria
<observable conditions that define success>

## DoD / Verification
<commands or scenarios that pass for a correct solution and fail for a broken one>

## Dependencies
<issues or contracts that must exist first>
```

Include a Mermaid diagram only when a real flow crosses at least two
components and the diagram improves understanding — never as decoration.

## Rework and escalation

Per issue, in order:

1. **First acceptance failure:** same executor receives an exact
   discrepancy list.
2. **Second acceptance failure:** same executor receives a second targeted
   rework request.
3. **Third attempt:** a fresh executor starts with clean context and the
   approved issue specification — never the failing executor's history.
4. **Fresh-executor failure:** mark the issue `blocked`.

A `blocked` record includes: the failed acceptance criterion, the observed
result, the attempts already made, and the precise missing prerequisite or
unresolved contradiction. No issue is ever closed by commit keywords before
independent verification passes.

## OMP-native mechanics

| Need | OMP primitive |
|---|---|
| Existing track state | `manager` read mode |
| Issue and Project writes | `manager` write mode |
| Parallel independent work | batch `task` call |
| Shared track context | batch `context` block: Goal, Constraints, Contract |
| Per-assignment scope | task item `assignment`: Target, Change, Acceptance |
| Specialist identity | task item `role` and a stable `id` |
| Existing agent follow-up | IRC, or Agent Hub revival |
| Agent transcript | `history://<id>` |
| Full agent output | `agent://<id>` |
| Post-mortem across subSessions | `/export` |
| Model routing | OMP model roles and agent definitions — never a hardcoded provider/model ID |
| Independent specification audit | fresh `task` agent, role/id `SpecAuditor` |
| Independent acceptance check | fresh `task` agent, role/id `AcceptanceVerifier` |

Batch `task` calls always follow the standard contract: shared `context`
carries Goal/Constraints/Contract, each `assignment` carries its own
Target/Change/Acceptance, independent tasks are dispatched together, and
formatting, unrelated cleanup, and project-wide tests stay excluded from
individual assignments unless explicitly required. Do not reproduce
`manager`'s read/write algorithm, invariants, or Project-sync logic here —
call `manager` and consume its result.

## Red flags

| Rationalization | Reality |
|---|---|
| "This is a big task, so every part needs an issue." | Only independently executable work does. |
| "Executor says it passed." | Executor evidence is not independent acceptance. |
| "Reviewer can fix it while reviewing." | The verifier reports; the executor repairs. |
| "The user did not ask for GitHub." | Automatic strict mode still requires a strong GitHub-track signal, not an explicit request. |
| "Use the named model from today's config." | This skill uses model roles, never concrete model IDs. |

## Quick reference

- Strong track signal (multi-session, epic/Project/backlog, multi-repo,
  multi-executor, 3+ independent tasks with separate acceptance, or an
  explicit discovery→spec→execution→verification ask) → strict mode.
- Uncertain, or only "multiple files/URLs/subagents" or a single-cycle
  bug/feature/report → stay in `orchestrating-work`; never create issues.
- Order is fixed: manager read → scouts → main decisions → issue specs →
  Spec Auditor → executors → Acceptance Verifier → rework or manager
  close/sync.
- Two hard gates: no executor before Spec Auditor `pass`; no close before
  Acceptance Verifier `passed`.
- Name primitives literally: `manager` for every GitHub/Project read and
  write, a fresh `SpecAuditor` task agent before dispatch, a fresh
  `AcceptanceVerifier` task agent before close — a checklist or self-review
  never substitutes for either.
- Rework ladder: same executor twice, then one fresh executor with clean
  context, then `blocked` with exact evidence — never more retries, never
  fewer.
- All GitHub reads/writes go through `manager`; this skill never talks to
  GitHub directly and never duplicates manager's invariants.
