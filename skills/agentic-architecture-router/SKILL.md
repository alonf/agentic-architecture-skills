---
name: agentic-architecture-router
description: USE FOR - agentic architecture decisions before implementation - should this be an agent, deterministic vs agentic, do we need AI, single agent or multi-agent, should we expose MCP, architecture decision for an AI feature, whether a workflow or an agent owns control, whether a capability needs an MCP boundary, reviewing an agentic design before code is written. Decomposes a requirement into responsibilities and routes each to the least autonomous mechanism that satisfies it. DO NOT USE FOR - writing implementation code (use the language or framework skill), Azure provisioning or deployment (use an Azure provisioning skill), Foundry API syntax (use your platform's Foundry skill), mapping a decision to Agent Framework constructs in .NET (use maf-architecture-mapping), framework tutorials.
license: MIT
metadata:
  author: Alon Fliess
  version: 1.0.0
  homepage: https://github.com/alonf/agentic-architecture-skills
when_to_use:
  - should this be an agent?
  - do we need AI for this at all?
  - deterministic vs agentic - which does this requirement need?
  - single agent or multi-agent here?
  - should we expose this as MCP?
  - add an AI agent that investigates X
  - review this agentic design before we build it
  - does this need a workflow or an agent?
disallowed-tools:
  - Write
  - Edit
  - NotebookEdit
---

# Agentic Architecture Router

> **Iteration 001 — body is a placeholder.** The frontmatter above is final and is what an install
> exercises: the trigger surface, the licence, the version, and the `disallowed-tools` declaration that
> makes the stop mechanical rather than advisory. The nine-step procedure, the routing table and the
> references land in iteration 002. Installing this today proves the distribution path works; it does
> not yet give you the decision procedure.

## Purpose

Decide **what kind of computation and control each responsibility needs, before choosing products or
writing code**.

> Use the least autonomy that satisfies the requirement. Add explicit orchestration where control
> matters.

Using a model does not make software agentic. It becomes agentic when AI receives authority to decide
part of what happens next — and that authority is what this skill exists to grant deliberately or
withhold.

## Planned structure (iteration 002)

- A nine-step procedure: establish facts, decompose into responsibilities, route each to the least
  autonomous mechanism, classify evidence, classify capability boundaries, preserve authority
  boundaries, select technology only afterwards, test the rejected alternatives, stop before
  implementation.
- `references/decision-framework.md` — the two-axis model and the routing table, stated once.
- `references/evidence-and-authority.md` — the evidence taxonomy and the seven-rung authority ladder.
- `references/quality-gates.md` — the ten gates.
- `references/worked-example.md` and `references/counter-examples.md` — the positive path and the
  rejection path, which is the behaviour that distinguishes this package.
- `assets/architecture-analysis-template.md` — the only place the output shape is defined.

## Provenance

Extracted from the VSLive San Diego 2026 sessions H08 and W20 and their companion material. The
demonstration application that motivated it is public at
<https://github.com/alonf/CaesariaAgenticArchitectureDemo>; no scenario in this package is traceable to
it, by design.

**Architecture review required before implementation.**
