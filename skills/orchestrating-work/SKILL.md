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
