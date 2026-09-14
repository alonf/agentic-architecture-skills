# Construct Map

**Traces**: FR-018, FR-022

Twelve mechanism-to-construct rows, one per live beat the H08/W20 demo material actually stages, in
the order the material teaches them. Each row states the construct at the level of concept and name
only — no method signature, namespace or package version; verify those against
`maf-surface.md` and live documentation before generating code (see the currency rule in `SKILL.md`).

A row here presumes the routing decision (deterministic / bounded AI / single agent / multi-agent) was
already made by `agentic-architecture-router`. This file never re-derives that decision; it only names
the construct that carries it out once made.

## When the decision was not an agent

The router's two most frequent outcomes are not an agent at all, and mapping them honestly means
saying so rather than reaching for the twelve rows below anyway. A mapping that always lands on an
agent construct — even when the router said deterministic or bounded AI — inverts the router's own
thesis: least autonomy that satisfies the requirement.

- **Deterministic → no MAF construct for that responsibility.** Map its computation to plain code.
  A workflow the router separately decided on axis 2 still maps to row 8's graph with deterministic
  activities; likewise, a bounded-AI activity does not erase an independently approved workflow.
- **Bounded AI → a direct model call, not an agent.** If the routed mechanism is a bounded AI
  capability, the construct is a direct, structured-output model call — the current chat-client-shaped
  surface, named and dated only in `maf-surface.md`, never asserted here — with no agent loop, no
  session construct, and no hosted agent runtime. A fixed-shape call does not need any of
  the machinery rows 1–12 exist to support.

## The twelve rows

| # | Mechanism (what the responsibility needs) | MAF construct | Architectural property that justifies it |
| --- | --- | --- | --- |
| 1 | A single agent that decides at run time what to check next | `AIAgent`, with a C# method bound as its tool (the client-to-agent adapter that creates it is named and dated only in `maf-surface.md`) | This is axis-1 tier 3 in the router's model: the mechanism itself must decide, from its own intermediate findings, what to examine next — the bounded-AI challenge must already have failed for a bounded call. |
| 2 | Conversational state persisting across turns, within one interaction | `AgentSession` (dated naming confirmation and creation signature in `maf-surface.md`) | Turn-to-turn continuity is a narrower property than durable memory: it must not survive the interaction ending, and it must not be conflated with recall across sessions (row 4). |
| 3 | Read access to an external evidence corpus the agent must cite, not memorise | `AIContextProvider` backed by a search source (e.g. `TextSearchProvider`) | Retrieval is a context-injection concern, separate from the agent's own reasoning loop, so that what was retrieved stays attributable and citable rather than absorbed as if the agent already knew it. |
| 4 | Recall of the agent's own prior findings across sessions | A custom `AIContextProvider` that recalls prior outcomes | Distinct from row 3 by origin: content here comes from the agent's own history, not an external corpus, and must be surfaced as a *hypothesis to re-verify*, not an asserted fact, because memory is fallible in a way fresh evidence is not. |
| 5 | Procedural knowledge loaded only when relevant, not held in context permanently | `AgentSkillsProvider` + a `SKILL.md` | Progressive disclosure is the property: the procedure must not cost context when the responsibility it describes is not in play, and it must stay declarative content, never executable code the agent runs directly. |
| 6 | A tool surface owned by another service or team, **for which the router recorded an MCP-specific property** (FR-008) | `McpClient` discovery against an MCP server | Ownership alone does not earn this row: the router's decision must state why MCP is preferred to the existing API — the contract is discovered at run time because the caller does not own it and it changes independently, or several agents and hosts consume it through one protocol boundary, or the provider only exposes it as MCP. Without that recorded property, the existing typed API is bound as a function tool (the row below the table) and the existing API boundary is preserved. |
| 7 | An already-justified MCP tool call that must pause for a human answer mid-call | MCP elicitation | The pause-and-resume contract belongs to the protocol layer, not to the agent's own control flow. The MCP boundary must already pass FR-008; needing a human answer alone does not justify replacing an existing API with MCP. |
| 8 | A separately approved fixed step sequence | Workflow graph; human gate only when the router's authority chain names an explicit human-sign-off policy | Workflow is axis 2, independent of each activity's autonomy; apply the gate rule below. Package details stay in `maf-surface.md`. |
| 9 | A specific, consequential tool call that needs human sign-off before it runs | `ApprovalRequiredAIFunction` | This is per-call authorization, not per-stage: it differs from row 8's workflow gate in that the approval boundary sits on one function invocation, not on a graph transition, and it is the mechanism the five-stage authority chain (`evidence-and-authority.md`) resolves to at the tool layer. |
| 10 | A second agent consulted as a bounded capability, not a peer conversation | A second agent exposed as a tool over its existing callable API (agent-as-tool); MCP only with a separately approved MCP-specific property | The router's agent-boundary test must first justify the second agent (specialisation, model, ownership). This does not choose transport: retain the existing callable API when the router records no MCP boundary; use the MCP variant only after the same FR-008 test as row 6 passes. The caller consults a bounded capability, unlike open-ended peer delegation (row 11). |
| 11 | A peer agent, owned elsewhere, that receives a task description rather than a function call | Agent-card discovery and task delegation (A2A protocol) | The caller has no function signature to invoke, only a task and an eventual result — this is what distinguishes delegation from row 10's tool consultation, and it presumes a real deployment/ownership boundary, not merely "a different service". |
| 12 | Where the agent executes, independent of what it decides | A hosted runtime (e.g. Foundry's hosted agent runtime) | Hosting is an operational/deployment decision, not a mechanism decision — it changes isolation, session lifecycle, identity and cost (see `runtime-and-control.md`), never what was already decided about autonomy. |

Row 8 gate rule: without an explicit human-sign-off policy in the router's authority chain, the graph
carries no human gate and the record states "unknown - governance decision required".

## The row that is not MCP: an existing API without an MCP-specific property

A tool the agent needs that already has a typed API the team can call — even one owned by another
team — maps to a **function tool over that existing API**, not to row 6. Reaching for `McpClient`
because "another team owns it" inverts FR-008: MCP is a boundary the router must justify, not the
default shape of any cross-team call. Say which applies in the output.

## Constructs the material names but does not demonstrate

The H08/W20 material marks these as slide-only or not implemented. They are recorded here so this map
does not imply coverage it cannot back with a staged demonstration, per FR-022:

- **Handoff and group chat** — two of the four multi-agent composition modes the material compares;
  only agent-as-tool (row 10) and A2A delegation (row 11) are actually staged. Both are workflow
  orchestrations; dated handoff builder confirmation is in `maf-surface.md`. The group-chat C#
  builder name remains unasserted until read from a documentation page.
- **A harness agent** — named on a slide, not implemented in the demo material.
- **Governance middleware** — not implemented as middleware; the demonstrated authority mechanisms are
  rows 8 and 9 above, plus the delegated-access consent flow in `runtime-and-control.md`.
- **Protocols, as a standalone topic** — the material treats this as decision documents (see
  `runtime-and-control.md`), not a separate runtime construct.
