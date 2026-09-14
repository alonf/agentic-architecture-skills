# Router Trigger Corpus

**Traces**: FR-041 (at least 25 phrasings, positives and negatives, executable as a recorded manual
run), FR-042 (behavioral verification recorded in a dated results file — see
`package/tests/results/`), SC-002 (trigger recall measured on the positive corpus, published in
README).

This file is the corpus only: the phrasings and their expected outcome. It is authored without
requiring a live host — it is a fixed list, evaluated the same way regardless of which host runs it.
Running this corpus against a host and recording what actually happened is a separate, dated results
file under `package/tests/results/` (FR-042); that run has not yet been performed and is intentionally
not represented here. `expected` below is a prediction to be confirmed by that run, not an observed
result.

**Skill under test**: `agentic-architecture-router`
**Corpus size**: 30 phrasings (15 positive, 15 negative) — exceeds the FR-041 minimum of 25.

## How to run this corpus

For each phrasing below, open a fresh conversation on the host under test, send the phrasing verbatim
as the entire message, and record whether `agentic-architecture-router` loaded (`load`) or did not load
(`no-load`). A positive phrasing that does not load is a miss; a negative phrasing that loads is a false
positive. SC-002's recall figure is `positive loads / 15`; SC-002's false-positive count is negative
phrasings that loaded.

## Positive corpus (expected: load)

Each of these is worded independently of the mandated `when_to_use` phrases in `SKILL.md`'s frontmatter
— they test recall on the *description* and general architecture-decision framing, not just an exact
repeat of the trigger list.

| # | Phrasing | Rationale |
| - | -------- | --------- |
| P1 | Should this be an agent? | Verbatim mandated phrase (frontmatter `when_to_use`) |
| P2 | Deterministic vs agentic — which does this requirement need? | Verbatim mandated phrase |
| P3 | Do we need AI for this at all? | Verbatim mandated phrase |
| P4 | Single agent or multi-agent here? | Verbatim mandated phrase |
| P5 | Should we expose this as MCP? | Verbatim mandated phrase |
| P6 | Add an AI agent that investigates X | Verbatim mandated phrase |
| P7 | Review this agentic design before we build it | Verbatim mandated phrase |
| P8 | Does this need a workflow or an agent? | Verbatim mandated phrase |
| P9 | We're about to add an agent that reads support tickets and routes them — is that the right call? | Independent phrasing of an architecture-routing question, framed as a scenario |
| P10 | I want an architecture decision for this AI feature before anyone writes code | Independent phrasing, matches description's "architecture decision for an AI feature" |
| P11 | Help me decompose this requirement into responsibilities and figure out what each one actually needs | Independent phrasing of the core procedure, no agent/AI keyword |
| P12 | Is a bounded AI call enough here, or do we actually need an agent? | Independent phrasing, references the bounded-AI challenge concept without naming it |
| P13 | What's the least autonomous mechanism that satisfies this requirement? | Independent phrasing, quotes the skill's own stated principle |
| P14 | Before we pick a product for this, what's the generic architecture here — agent, workflow, or plain code? | Independent phrasing, tests the "technology only afterwards" framing |
| P15 | We keep calling everything an agent — can you sanity-check whether this one actually needs to be? | Independent phrasing, colloquial framing of the same underlying question |

## Negative corpus (expected: no-load)

These are chosen to probe the boundary the `DO NOT USE FOR` clause draws: adjacent-sounding requests
that must not load the router because they ask for implementation, provisioning, or platform-specific
work rather than an architecture decision.

| # | Phrasing | Rationale |
| - | -------- | --------- |
| N1 | Write the C# code for this agent's tool-calling loop | Implementation code — explicit `DO NOT USE FOR` |
| N2 | Provision the Azure Container App for this service | Azure provisioning/deployment — explicit `DO NOT USE FOR` |
| N3 | What's the exact Foundry API call to register this agent? | Foundry API syntax — explicit `DO NOT USE FOR` |
| N4 | Map this decision to Microsoft Agent Framework constructs in .NET | Belongs to `maf-architecture-mapping`, not this skill — explicit `DO NOT USE FOR` |
| N5 | Give me a tutorial on how agent frameworks work in general | Framework tutorial — explicit `DO NOT USE FOR` |
| N6 | Fix the null-reference exception in OrderProcessor.cs | Ordinary bug fix, no architecture-decision framing |
| N7 | Format this JSON file so it's easier to read | Mechanical formatting, unrelated to agentic architecture |
| N8 | What's today's date? | Unrelated general question |
| N9 | Summarize this PDF for me | Unrelated content task, no architecture decision |
| N10 | Add a unit test for the existing `ParseInvoice` function | Ordinary test-writing, no architecture decision |
| N11 | Refactor this class to use dependency injection | Ordinary code refactor, no agent/AI framing |
| N12 | Deploy the latest build to the staging slot | Deployment operation, explicit `DO NOT USE FOR` (provisioning/deployment) |
| N13 | What does this Kubernetes YAML do? | Infrastructure reading task, unrelated to architecture routing |
| N14 | Translate this error message into Japanese | Unrelated content task |
| N15 | Show me the git log for the last five commits | Ordinary repository inspection, no architecture decision |

## Notes

- P1–P8 exercise the mandated phrases the `router-trigger-phrases` mechanical check already enforces
  present verbatim in the frontmatter; P9–P15 exercise recall beyond the exact trigger list, which is
  what SC-002's recall figure is actually measuring.
- N1–N5 are deliberately adjacent to the skill's own domain (they mention agents, AI, or architecture)
  so that a false-positive here would be a meaningful signal, not a trivial one.
- This corpus is host-neutral; the same 30 phrasings are run unchanged on every demonstration host per
  FR-042, with the outcome recorded per host in the dated results file.
