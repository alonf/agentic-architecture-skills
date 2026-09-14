# Quality Gates

**Traces**: FR-002 through FR-012

Ten gates, each traced to the requirement it enforces. An analysis that has not satisfied every gate it
applies to is not complete, regardless of how confident its prose reads.

1. **Fact-table discipline** (FR-002) — the three-column table exists, and the "unknown" column is
   genuinely empty of invented content. Any illustrative content is labelled *hypothesis* or
   *illustrative example* on the same line.
2. **Atomicity is stated, not implied** (FR-003) — at least two responsibilities are named, or the
   output states explicitly that the requirement is atomic.
3. **Routing order is followed** (FR-004) — each responsibility is routed deterministic code → bounded
   AI capability → single agent → multi-agent, in that order of preference, with workflow evaluated as
   a separate, orthogonal axis.
4. **The bounded-AI challenge ran before any agent was chosen** (FR-005) — the challenge and its answer
   are recorded, not skipped because the responsibility "obviously" needed an agent.
5. **Agent boundaries are justified, not organisational** (FR-006) — every additional agent names a
   distinct security, context, deployment, ownership, model, or specialisation boundary in one
   sentence; no agent boundary is derived from a service, hub, bounded-context, team, or domain
   boundary.
6. **Evidence is classified and caveated** (FR-007) — every piece of evidence used carries one of the
   seven rungs, and agent memory / retrieved knowledge caveats are stated wherever those rungs are
   used.
7. **Every MCP boundary answers "why MCP"** (FR-008) — a concrete property is named, or no MCP surface
   is proposed.
8. **Consequential operations carry the full authority chain** (FR-009) — reasoning → authorization →
   authoritative service → execution → audit is explicit, and unspecified policy is recorded as
   *unknown — governance decision required* rather than assumed.
9. **Generic mechanism precedes product naming** (FR-010, FR-011) — the mechanism is stated before any
   product name; where no platform skill is installed, the analysis stops at the generic mechanism
   rather than supplying product detail from memory.
10. **Rejected alternatives carry a sufficiency verdict** (FR-012) — all five alternatives
    (all-deterministic, bounded-AI-only, agent-everywhere, multi-agent, workflow-only) are evaluated,
    each with one sentence on whether it would have been sufficient.

## Applying the gates

Not every gate applies to every analysis at full weight — gate 5 has nothing to check when no
additional agent is proposed, and gate 7 has nothing to check when no MCP boundary is proposed. In
those cases the gate is satisfied by the analysis stating plainly that it does not apply, rather than
by silence. A gate that is silently skipped cannot be told apart from a gate that was forgotten.
