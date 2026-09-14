# Architecture Analysis Template

**Traces**: FR-001 through FR-016. The only place the full-analysis output shape is defined; both
output modes (full analysis and Decision Card) render from the same internal analysis this template
structures. See `SKILL.md` for when each mode activates.

Twelve sections, in this order. A section with nothing to report states that explicitly rather than
being omitted — an omitted section cannot be told apart from a forgotten one.

1. **Requirement** — the requirement as given, restated in one or two sentences.
2. **Fact table** — the three-column table: known from repository material, known from the
   requirement, unknown and not assumed. Illustrative content labelled *hypothesis* or *illustrative
   example* on the same line. (FR-002)
3. **Responsibilities** — at least two, or an explicit statement that the requirement is atomic. (FR-003)
4. **Routing decisions** — per responsibility, the mechanism chosen (deterministic code / bounded AI
   capability / single agent / multi-agent) and the reasoning, in routing-order preference. (FR-004)
5. **Bounded-AI challenge record** — for every responsibility routed to an agent, the challenge
   question and its answer, showing why a fixed-shape call was not sufficient. (FR-005)
6. **Agent boundary justification** — for every additional agent beyond the first, the one-sentence
   boundary (security / context / deployment / ownership / model / specialisation); states "n/a" when
   only one or zero agents are proposed. (FR-006)
7. **Evidence classification** — every fact used, tagged with its rung (1–7) from
   `references/evidence-and-authority.md`, with the agent-memory and retrieved-knowledge caveats where
   those rungs are used. (FR-007)
8. **MCP boundary justification** — for every proposed MCP boundary, the concrete property that
   justifies it over the existing boundary; states "none proposed" when no MCP boundary is suggested.
   (FR-008)
9. **Authority chain** — for every consequential operation, the five-stage chain (reasoning →
   authorization → authoritative service → execution → audit), with unspecified policy recorded as
   *unknown — governance decision required*; states "no consequential operation" when none exists.
   (FR-009)
10. **Generic mechanism and product delegation** — the mechanism stated generically; product mapping
    delegated to an installed platform skill, or the analysis stops at the generic mechanism when none
    is installed. (FR-010, FR-011)
11. **Rejected alternatives** — all five (all-deterministic, bounded-AI-only, agent-everywhere,
    multi-agent, workflow-only), each with a one-sentence sufficiency verdict. (FR-012)
12. **Decisions, evidence, trade-offs, assumptions, open questions** — presented in the open, no hidden
    chain-of-thought, followed immediately by the mandated terminal line. (FR-016)

The output ends with the exact line `**Architecture review required before implementation.**` (FR-013)
in both output modes.
