# Mapping Trigger Corpus

**Traces**: FR-041 (at least 25 phrasings, positives and negatives, executable as a recorded manual
run), FR-042 (behavioral verification recorded in a dated results file — see
`package/tests/results/`), SC-008 (volatile surface facts stay in `maf-surface.md`), SC-009
(construct-map rows stay tied to demonstrated or explicitly not-demonstrated constructs).

This file is the corpus only: the phrasings and their expected outcome. It is authored without
requiring a live host — it is a fixed list, evaluated the same way regardless of which host runs it.
Running this corpus against a host and recording what actually happened is a separate, dated results
file under `package/tests/results/` (FR-042); that run has not yet been performed and is intentionally
not represented here. `expected` below is a prediction to be confirmed by that run, not an observed
result.

**Skill under test**: `maf-architecture-mapping`
**Corpus size**: 30 phrasings (15 positive, 15 negative) — exceeds the FR-041 minimum of 25.

## How to run this corpus

For each phrasing below, open a fresh conversation on the host under test, send the phrasing verbatim
as the entire message, and record whether `maf-architecture-mapping` loaded (`load`) or did not load
(`no-load`). A positive phrasing that does not load is a miss; a negative phrasing that loads is a
false positive. FR-041's recall figure is `positive loads / 15`; the false-positive count is negative
phrasings that loaded.

The positive/negative boundary here is intentionally different from the router's corpus: this skill
should activate only when the prompt already supplies or references an existing mechanism decision to
map. Requirement-only prompts belong to `agentic-architecture-router`; coding, provisioning, portal,
and tutorial prompts belong elsewhere or nowhere.

## Positive corpus (expected: load)

Each positive phrasing either supplies the approved mechanism decision directly or makes it explicit
that the routing decision already exists, then asks for Microsoft Agent Framework mapping.

| # | Phrasing | Rationale |
| - | -------- | --------- |
| P1 | The architecture decision is: bounded AI capability for invoice extraction. How do I build this with Agent Framework in C#? | Verbatim `when_to_use` phrase with an explicit existing decision |
| P2 | Approved decision: deterministic code for a scheduled threshold alert. Map this to Microsoft Agent Framework constructs in .NET and say plainly if there is no construct. | Exercises the "when the decision was not an agent" preface, deterministic branch |
| P3 | The routing decision is already made: single agent for a diagnostic responsibility where intermediate findings decide what to inspect next. Which MAF construct owns this responsibility? | Verbatim `when_to_use` phrase with a row-1 decision supplied |
| P4 | We already approved a fixed step sequence with one human authorization boundary. Where does the human approval go in Agent Framework? | Verbatim `when_to_use` phrase, row 8 mapping |
| P5 | Approved mechanism: conversational continuity across turns within one interaction only. Session, memory or knowledge — which one is this? | Verbatim `when_to_use` phrase, row 2 mapping |
| P6 | The router already decided the agent must cite an external evidence corpus rather than memorize it. Which MAF construct owns this responsibility? | Exercises row 3 retrieval mapping |
| P7 | Approved decision: recall the agent's own prior findings across sessions as a hypothesis to re-check. Session, memory or knowledge — which one is this? | Exercises row 4 memory mapping with the file's caution |
| P8 | The architecture decision is already approved: load procedural guidance only when relevant, not in permanent context. How do I build this with Agent Framework in C#? | Exercises row 5 `AgentSkillsProvider` + `SKILL.md` |
| P9 | We already decided this capability is owned by another team and should be discovered across a real ownership boundary. Do I need an MCP client or an MCP server here? | Verbatim `when_to_use` phrase, row 6 mapping |
| P10 | Approved decision: a tool call must pause mid-call for a human answer, then resume. Map that to MAF constructs in .NET. | Exercises row 7 MCP elicitation |
| P11 | The approved design is a specific consequential tool call that needs human sign-off before execution. Which MAF construct owns this responsibility? | Exercises row 9 approval mapping |
| P12 | Existing decision: consult a second agent as a bounded capability, not a peer delegation. Map this to Agent Framework constructs. | Exercises row 10 agent-as-tool mapping |
| P13 | Existing decision: delegate a task to a peer agent owned elsewhere; the caller has a task and a result, not a function signature. Map this to A2A/agent-card constructs. | Exercises row 11 A2A/agent-card mapping |
| P14 | Hosting has already been decided separately: the agent runs in a hosted runtime for operational reasons, independent of the autonomy decision. How do I host this agent? | Verbatim `when_to_use` phrase, row 12 / runtime-control mapping |
| P15 | Approved decision: bounded AI for customer-sentiment scoring, no agent loop. Should this be an AIAgent or a function tool? | Verbatim `when_to_use` phrase, tests the "not an agent" mapping honesty |

## Negative corpus (expected: no-load)

These probe the boundary the skill's own `DO NOT USE FOR` clause draws: prompts that sound adjacent
but do not supply an existing mechanism decision to map, or that ask for coding, provisioning, portal,
tutorial, or volatile-surface answers instead.

| # | Phrasing | Rationale |
| - | -------- | --------- |
| N1 | Should this be an agent for support-ticket routing? | Requirement-only routing question; belongs to `agentic-architecture-router` |
| N2 | Deterministic vs agentic — which does this fraud-scoring requirement need? | Requirement-only routing question; router domain |
| N3 | Do we need AI for this at all? The feature reads invoices and tags them. | Requirement-only routing question; router domain |
| N4 | Single agent or multi-agent here for an incident response assistant? | Requirement-only routing question; router domain |
| N5 | Should we expose this as MCP for our existing billing API? | Requirement-only boundary question; router domain |
| N6 | Add an AI agent that investigates failed batch jobs. | Requirement-only + implementation preference; router domain |
| N7 | Review this agentic design before we build it. | Requirement-only architecture review; router domain |
| N8 | Does this need a workflow or an agent? It reads tickets and assigns severity. | Requirement-only routing question; router domain |
| N9 | Map this new support-ticket-priority requirement to Microsoft Agent Framework constructs in .NET. | Mapping phrasing without an approved mechanism decision |
| N10 | Which MAF construct should I use for a component that summarizes meeting notes? | Requirement-only mapping phrasing, no prior decision |
| N11 | Write the C# code for an AIAgent tool-calling loop. | Pure coding request; explicit `DO NOT USE FOR` boundary |
| N12 | Provision the Azure Container App and Foundry resources for this hosted agent. | Azure provisioning/deployment; explicit `DO NOT USE FOR` boundary |
| N13 | Walk me through the Foundry portal clicks to deploy an agent. | Foundry portal walkthrough; explicit `DO NOT USE FOR` boundary |
| N14 | Give me a tutorial on Microsoft Agent Framework sessions vs memory vs knowledge. | Framework tutorial/explainer; explicit `DO NOT USE FOR` boundary |
| N15 | What's the exact package version, namespace, and method signature for AgentThread right now? | Volatile API-surface request; the skill must not answer this from memory |

## Notes

- P1, P3, P4, P5, P9, P14, and P15 deliberately exercise the verbatim `when_to_use` phrasings, but
  only after a decision is already supplied; P2 and P6–P13 extend recall beyond the exact list.
- P2 and P15 specifically exercise the construct map's "when the decision was not an agent" preface,
  so the skill is tested on honestly naming **no MAF construct** / **direct model call** outcomes
  rather than force-fitting everything into an agent construct.
- N1–N10 are the positive/negative boundary for this skill: adjacent architecture prompts that do
  **not** supply an approved mechanism decision and therefore should not trigger the mapping skill.
- N11–N15 cover the frontmatter `DO NOT USE FOR` categories directly: code generation, Azure
  provisioning/deployment, Foundry portal walkthroughs, framework tutorials, and volatile
  version/signature/availability requests.
