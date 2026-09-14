# Decision Framework

**Traces**: FR-001, FR-003, FR-004, FR-005, FR-006, FR-010, FR-011, FR-012

The router decomposes a requirement into responsibilities, then routes each responsibility along two
independent axes. Getting the axes right — and keeping them independent — is what prevents an agent
being chosen because it is available rather than because the responsibility needs one.

## Axis 1 — autonomy (the control axis)

Ordered from least to most autonomous. Route each responsibility to the **least** autonomous mechanism
that satisfies it (FR-004):

1. **Deterministic code** — the response is a fixed rule, lookup, or computation. Nothing about the
   decision changes based on content the code has not already been given.
2. **Bounded AI capability** — a single model call with a fixed input and a fixed output shape: a
   classification, an extraction, a score, a single correlation. The steps taken to get there do not
   change based on what the model finds; only the fixed output does.
3. **Single agent** — the mechanism decides, at run time, what to examine next, in what order, or
   whether another step is needed at all, based on its own intermediate findings. FR-005: this MUST be
   demonstrated, not assumed — the bounded-AI challenge below is the demonstration.
4. **Multi-agent** — more than one agent, each with a distinct boundary (see below). Never the default
   shape for "more than one responsibility"; each additional agent needs its own justification.

**The bounded-AI challenge (FR-005, mandatory before any agent is selected).** State explicitly: "could a
single bounded call with a fixed input/output shape satisfy this responsibility?" Record the answer and
the reasoning. An agent is permitted only when the honest answer is no — because intermediate findings
materially determine what to examine next, in what order, or whether another step is needed at all. A
responsibility that is merely complex, or merely involves natural language, is not by itself a reason the
challenge fails.

**Agent boundaries (FR-006).** A separate agent is never derived from a service boundary, a hub boundary,
a bounded context, a team boundary, or a domain boundary — those are organisational or deployment
concerns, not decision-authority concerns. A separate agent requires one of: a distinct security
boundary, a distinct context boundary, a distinct deployment boundary, a distinct ownership boundary, a
distinct model boundary, or a distinct specialisation boundary — named in one sentence. "These two things
are in different services" is not that sentence; "this agent must not see data the other agent holds
under a stricter data-residency rule" is.

## Axis 2 — workflow (orthogonal)

Workflow — whether steps run in a fixed sequence, in parallel, with retries, or under a saga — is
evaluated **independently** of the autonomy axis. A deterministic step and an agentic step can both live
inside the same workflow; choosing a workflow engine says nothing about how autonomous any one step is,
and choosing an agent says nothing about whether a workflow is needed around it. Conflating the two axes
is a common source of over-agentic designs: "this needs orchestration" is not evidence that any given
step in that orchestration needs to be an agent.

## Boundary outcomes after routing (FR-008, FR-009)

The decision map records two further outcomes independently of the autonomy and workflow axes:

| Decision | Required outcome |
| --- | --- |
| Does the capability require MCP? | **MCP boundary** with an approved MCP-specific property, or **no MCP boundary** with the existing API/service/tool retained. Apply the justification test in `evidence-and-authority.md`. |
| Can the responsibility change state or cause an external effect? | **Deterministic control boundary** with the authorization-to-audit chain from `evidence-and-authority.md`, or **no consequential action** with the read-only scope stated. |

Neither boundary is a fifth autonomy rung. An agent may propose an action; fixed control decides
whether that proposal may reach the authoritative service. A workflow may host this control, but
choosing a workflow does not establish its authorization policy.

## Product naming order (FR-010, FR-011)

The generic mechanism — "bounded AI capability", "single agent", "deterministic rule" — MUST be stated
before any product name appears. Product mapping (a specific SDK, a specific hosting construct) is
delegated to `maf-architecture-mapping` or to whatever platform-specific skill is installed. Where no
platform skill is installed, this router states the mechanism generically and stops; it MUST NOT
supply product detail from memory, because unverified product detail is exactly the kind of claim this
package exists to keep out of a skill body (see `evidence-and-authority.md`).

## Rejected-alternatives evaluation (FR-012)

Every analysis MUST evaluate the same five alternatives against the chosen routing, each in one
sentence stating whether it would have been sufficient:

- **All-deterministic** — would fixed rules alone have covered every responsibility?
- **Bounded-AI-only** — would fixed-shape model calls alone have covered every responsibility, with no
  agent anywhere?
- **Agent-everywhere** — would treating every responsibility as agentic have been sufficient, and if so,
  at what unnecessary cost?
- **Multi-agent** — does any responsibility actually need a second agent, under the boundary test above?
- **Workflow-only** — would an orchestration layer alone, with no agentic step, have been sufficient?

A rejected alternative that is dismissed with no reasoning is indistinguishable from a rejected
alternative that was never actually considered; the one-sentence sufficiency verdict is what makes the
rejection auditable.

## Atomicity (FR-003)

The output MUST contain at least two responsibilities unless the requirement is genuinely atomic — a
single responsibility that cannot be usefully decomposed further. When it is atomic, the output states
that explicitly rather than inventing a second responsibility to satisfy an expected shape.
