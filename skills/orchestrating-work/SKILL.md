---
name: orchestrating-work
description: Use when a user asks for any non-trivial task that may involve research, planning, external URLs, multiple files, multiple subsystems, audits, migrations, SEO, design, debugging, or implementation. Especially use when work can split into independent investigation, execution, review, or verification streams.
alwaysApply: true
---

# Orchestrating Work

## Core principle

The main model is the coordinator, not the default worker.

For non-trivial work, first decide whether the task has independent streams. If yes, delegate discovery, checking, review, and verification to subagents. Reserve the main model for coordination, tradeoffs, synthesis, and final decisions.

## Required start gate

Before doing meaningful work, classify the task:

| Classification | Meaning | Action |
|---|---|---|
| Trivial | One short answer or one obvious operation | Handle inline. |
| Single-stream | One coherent path where delegation would add overhead | Handle inline, then verify normally. |
| Multi-stream | Independent research, implementation, review, verification, or planning streams exist | Use `task` subagents before synthesis. |

A task is multi-stream by default when it includes external research with multiple URLs, multiple categories, a site migration, product/catalog extraction, documents/certificates, multi-file code changes, cross-subsystem debugging, SEO audits, UI redesigns, or implementation plus testing/review.

If a task is non-trivial and you skip subagents, state the reason before doing the work.

## Large-track escalation

If work is a large GitHub-backed track with multiple independently executable issues, multi-session execution, Project tracking, multiple repositories, multiple executors, or a scout → spec → execution → independent verification pipeline, read `skill://omp-ruki-agenty` before proceeding. Do not apply its issue-first workflow to ordinary multi-file work or one-report research tasks.


## When to dispatch subagents

Use `task` subagents when two or more are true:

- The task has multiple independent workstreams.
- The task includes external URLs, websites, competitors, documents, source material, or crawling/parsing.
- The user asks for a plan, audit, migration, research, structure, parsing, scraping, review, implementation, debugging, SEO, or design.
- The task spans multiple categories, files, modules, systems, user flows, or pages.
- One agent can gather facts while another checks structure, risks, tests, UI, SEO, or documentation.
- A separate reviewer/tester would materially reduce missed issues.
- The user says “parallel”, “parallelize”, “orchestrate”, “agents”, “subagents”, or “do not do this with one model”.

Dispatch independent agents in the same tool call or same assistant turn so they run in parallel. Keep each assignment narrow and self-contained.

## When not to dispatch

Do not spawn subagents for:

- a simple factual answer;
- a tiny single-file or one-line change;
- a clarification question;
- work where subagents would edit the same files and conflict;
- tasks the user explicitly wants handled inline;
- situations where required information is missing and the next step is asking the user.

## Default workflow

1. Classify the task: trivial, single-stream, or multi-stream.
2. For multi-stream tasks, identify independent streams.
3. Dispatch one focused subagent per independent stream.
4. Wait for results and read each summary.
5. Resolve conflicts, remove duplicates, and synthesize with the main model.
6. For non-trivial deliverables, run a review/spec-check phase before finalizing.
7. Final answer includes an orchestration audit.

## Subagent assignment contract

Each subagent assignment should include:

- Role: what expertise this agent embodies.
- Scope: exact target and explicit non-goals.
- Output: what facts, decisions, or artifacts to return.
- Constraints: no broad rewrites, no unrelated cleanup, no project-wide tests unless explicitly assigned.

Prefer read-only scouts for discovery. Prefer a separate reviewer/tester for final checks.

## Common roles

| Role | Use for | Non-goal |
|---|---|---|
| SourceScout | Source facts, URLs, categories, entities, page structure | Final strategy writing |
| ProductDataScout | Product variants, attributes, data model | Site architecture decisions |
| DocsScout | Certificates, passports, manuals, standards | Inventing missing docs |
| StructurePlanner | Categories, IA, filters, page structure | Raw scraping |
| ExploreAgent | Existing code architecture and call paths | Editing code |
| ImplementationAgent | Scoped implementation | Broad redesign |
| Tester | High-signal behavior tests | Plumbing-only assertions |
| Reviewer | Spec alignment, omissions, risks, regressions | Re-implementing the work |
| Designer | UX, hierarchy, visual system | Backend/data work |
| SeoScout | Technical/content/schema/performance SEO findings | Non-SEO product decisions |

## Choosing the agent (deterministic)

The role names above are labels for the assignment, not agent types. What actually runs is the
`agent` field of the `task` tool: it selects the system prompt, tool set, and write permission of
the child. Its model is resolved from that agent's definition (`model:`, possibly a role alias
like `@task`/`@slow`), falling back to `modelRoles.task`.

One stream gets exactly one agent. Walk the ladder top-down and stop at the first match — never
"one of these three":

| # | Condition on the stream | `agent` | Model it resolves to |
|---|---|---|---|
| 1 | Answers a question about a third-party library/API by reading its source | `librarian` | `@task` |
| 2 | Gathers facts, maps code, crawls URLs, inspects documents — changes nothing | `scout` | `@task` |
| 3 | Judges security only, and must not write | `security-reviewer` | `@slow` |
| 4 | Checks a finished step against the plan it was supposed to follow | `code-reviewer` | `@slow` |
| 5 | Reviews quality/risks/regressions where no written plan exists | `reviewer` | `@slow` |
| 6 | Produces a plan document and must not touch source | `plan-fable` | `@plan` |
| 7 | Implements a plan that already exists as a file under `.planning/quick/*/N-PLAN.md` | `exec-plan` | `@task` |
| 8 | Edits UI/UX, visual hierarchy, design system | `designer` | `@designer` |
| 9 | Applies a purely mechanical change with no decisions (rename, bulk substitution, data collection) | `sonic` | `@tiny` |
| 10 | Anything else that writes code, tests, or config | `task` | `@task` |

Ties are resolved by the ladder, not by taste: a security review of a finished step is row 3, not
row 4, because "must not write" is the stronger constraint. A test-writing stream is row 10 —
there is no bundled tester agent, so state the test scope in the assignment instead.

The model column is not advice: it is pinned in `task.agentModelOverrides`, which resolves before
an agent's own default. Judgement streams (rows 3–5) run on `@slow` because a cheap reviewer
approves broken work; gathering and mechanical rows run on subscription-cheap models.

Model roles (`default`, `smol`, `tiny`, `slow`, `plan`, `designer`, `task`, `commit`, `advisor`,
`vision`, `video`) are a routing table, not agent identities: they say *which model* answers, not
*what job* it does. The `task` tool takes no model argument, so never name a role in an
assignment — pick the row above; the override table resolves the model.

## Required reviewer/spec-check phase

For non-trivial deliverables, include one final review pass. The reviewer checks:

- original user request and acceptance criteria;
- missing required outputs;
- unsupported claims or invented facts;
- whether independent streams were delegated;
- contradictions between subagent findings;
- verification evidence.

If no reviewer is used, explain why the task did not need one.

## Final orchestration audit

For non-trivial tasks, include this compact section in the final answer:

```text
Orchestration:
- Agents used: <ids/roles> or none
- Contributions: <one line each>
- Review/spec check: <done by whom, or why skipped>
```

If no subagents were used on a non-trivial task:

```text
Orchestration: no subagents used because <specific reason>.
```

## Strong example

User asks: “Prepare a plan to migrate product information from five external category URLs, including variants, documents, certificates, and a new site structure.”

Correct orchestration:

- `SourceScout`: collect categories, product URLs, and source structure.
- `ProductDataScout`: extract variants, characteristics, and entity model.
- `DocsScout`: find passports, certificates, manuals, and standards.
- `StructurePlanner`: propose target categories, filters, product page model, and document pages.
- `Reviewer`: check final plan against the original request and scout findings.

The main model coordinates and synthesizes; it does not perform all source exploration itself.

## Red flags

Stop and re-evaluate if you catch yourself thinking:

| Rationalization | Reality |
|---|---|
| “I can just do this myself.” | If independent streams exist, delegation is the default. |
| “The user did not explicitly ask for agents.” | This skill exists so the user does not need to repeat that. |
| “It is only a plan.” | Plans often require separate source, structure, docs, and review streams. |
| “I will review it myself.” | For non-trivial work, use a separate reviewer unless there is a clear reason not to. |
| “Subagents are overhead.” | For multi-stream work, missed facts and expensive main-model exploration are the overhead. |

## Quick reference

- External site + multiple URLs/categories → multi-stream → subagents.
- Code across multiple files/subsystems → explore + implementation + tests/review.
- SEO/audit/research → specialist scouts + synthesis.
- Design/build → designer + implementation + accessibility/review.
- Non-trivial final output → reviewer/spec-check phase.
