---
name: maf-architecture-mapping
description: USE FOR - mapping an approved architecture decision onto Microsoft Agent Framework constructs in .NET and C# - how do I build this with Agent Framework, which MAF construct owns this responsibility, agent framework hosting options, where does the human approval go, agent session vs memory vs knowledge, MCP client or MCP server in MAF, workflow with a human gate, multi-agent as agent-as-tool or handoff or group chat, A2A with agent cards, how do I prove this agent behaves. Maps a mechanism decision to the construct that owns it, with the architectural property that justifies each choice. DO NOT USE FOR - deciding WHETHER something should be an agent (use agentic-architecture-router first), Azure provisioning or deployment, Foundry portal walkthroughs, or any request that needs an API signature or package version asserted from memory.
license: MIT
metadata:
  author: Alon Fliess
  version: 1.0.0
  homepage: https://github.com/alonf/agentic-architecture-skills
when_to_use:
  - how do I build this with Agent Framework in C#?
  - which MAF construct owns this responsibility?
  - should this be an AIAgent or a function tool?
  - where does the human approval go in Agent Framework?
  - session, memory or knowledge - which one is this?
  - do I need an MCP client or an MCP server here?
  - how do I host this agent?
  - how do I prove this agent behaves correctly?
disallowed-tools:
  - Write
  - Edit
  - NotebookEdit
---

# MAF Architecture Mapping

> **Iteration 001 — body is a placeholder.** The frontmatter above is final. The construct map and its
> references land in iteration 002.

## Purpose

Map an **already-approved** mechanism decision onto the Microsoft Agent Framework construct that owns
it — at the level of concept and construct name, never an asserted method signature.

## This skill refuses to substitute for the decision

If you arrive here without a mechanism decision, this skill does not guess one. It produces or requests
the architecture decision first, using `agentic-architecture-router`. Choosing a construct before
deciding whether the responsibility needs an agent at all is the mistake this package exists to prevent,
and it is not made less of a mistake by being made in a framework.

## The currency rule

No package version, method signature, namespace or availability claim appears in this skill's body.
Every such fact lives in `references/maf-surface.md`, each carrying a verification date, and the skill
instructs the agent to confirm against live documentation before generating code.

This is not fastidiousness. Both existing community options for this framework went stale on exactly
this axis — one pins a prerelease version, the other still describes the framework as public preview
after it reached general availability. A skill that bakes in SDK syntax is wrong within a month and
confidently so.

## Planned structure (iteration 002)

- `references/construct-map.md` — mechanism to construct, each row carrying the architectural property
  that justifies it, covering every runtime construct the companion sessions demonstrate.
- `references/runtime-and-control.md` — hosting placement, ingress contract, isolation, runtime control,
  estate control, human authority.
- `references/assurance.md` — observe, evaluate, verify behaviour, regress.
- `references/maf-surface.md` — the dated facts, and the only file permitted to carry them.

## Provenance

Extracted from the VSLive San Diego 2026 sessions H08 and W20 and their companion material. Preferred
current-syntax sources are the framework repository's .NET samples and its `samples/AGENTS.md`; SDK
skills that teach the pre-Agent-Framework threads-and-runs model describe a superseded programming
model.

**Architecture review required before implementation.**
