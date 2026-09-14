# MAF Surface

**Traces**: FR-019, FR-020, FR-021

This is the **only** file in this skill that carries version numbers, signatures, GA/preview status, or
any other claim that changes over time. Every claim below is dated to when it was checked. **Treat every
line here as possibly stale by the time you read it — verify against current, live Microsoft Agent
Framework / Foundry documentation before using any of it in an architecture write-up or in code.**
`construct-map.md` and `runtime-and-control.md` deliberately do not repeat these details; they cite
this file instead so a stale date here does not silently spread into the mechanism-level guidance.

## Platform facts checked against a running deployment

These were verified by compiling, deploying, or calling a live instance — not read off a slide — on
the dates shown. Re-verify before relying on any of them; a later platform change would not be caught
by this file automatically.

- **Isolation model** — as verified 2026-09-04/2026-09-05: hosted agent sessions are isolated
  per-session in a sandbox, not scaled by a replica count. *(Unsure: confirm current product docs still
  describe this the same way before citing it in a design — this was one spike's finding, not a
  standing SLA.)*
- **Identity propagation** — as verified 2026-09-05 by logging inbound headers on a deployed agent
  called by two different callers: a per-request caller identifier reaches the running agent. This was
  observed to be an identifier, not itself a delegated-access grant — acting *as* that caller against a
  downstream system was confirmed, on the same date, to additionally require an explicit consent step.
- **Protocol/binding note** — the deployed agent's ingress accepted its request/response contract as
  verified 2026-09-04; A2A binding compatibility (JSON-RPC vs. HTTP+JSON) between two hosted peers was
  not independently verified in this material and should be treated as **unverified** until checked
  against current documentation, not assumed compatible.
- **A known correlation-id limitation** was recorded against the deployed sandbox; the exact scope of
  the limitation is in the source spike notes, not repeated here — re-read the current platform's
  incident/tracing documentation rather than carrying this note forward as still-accurate.
- **A previously documented Bicep-based scaling description was found stale** (checked 2026-09-04/05
  against the running deployment) — do not cite a fixed replica-count IaC pattern for this hosting
  model without re-checking current provisioning guidance first.

## Non-agent construct surface (for the "not an agent" mapping outcomes)

- **Bounded AI call surface** — as checked 2026-09-11 (crew reading of the framework material, not a
  running deployment), .NET's `Microsoft.Extensions.AI` `IChatClient` abstraction (structured/typed
  output via its chat-completion surface) is the direct-call shape a bounded-AI routing decision maps
  to — not an `AIAgent`, not a session construct. *(Unsure: confirm this is still the current
  recommended surface, and its GA/preview status, against live Microsoft.Extensions.AI documentation
  before citing a namespace or package version in a design.)*

## Names and facts the skill bodies deliberately do not carry

Each of these was moved out of `SKILL.md` or `construct-map.md` so that the body states only the
property and this file states the fact, dated. The crew read them from live Microsoft Learn pages on
2026-09-13. **Maintainer confirmation: 2026-09-14**, checklist rows 1–9 and questions A–C; DRIFT-005
closed by that typed confirmation. Retained uncertainties below are not converted into verified facts.

- **Framework availability status** — the source sessions (2026) describe the framework as released;
  the crew did **not** find an availability statement for .NET on the framework overview page
  (2026-09-13), whose C# quick start still adds the Foundry package with a prerelease flag. Treat the
  status as **unverified** and check the current overview and package listing before citing it.
- **Client-to-agent adapter (row 1)** — the overview's C# quick start (2026-09-13) creates the agent
  with `AIProjectClient(...).AsAIAgent(...)` from the `Microsoft.Agents.AI` namespace.
- **Workflow package (row 8)** — the handoff orchestration page (2026-09-13) builds workflows from
  `Microsoft.Agents.AI.Workflows` via `AgentWorkflowBuilder`.
- **Per-call approval (row 9)** — `ApprovalRequiredAIFunction` is documented as a
  `Microsoft.Extensions.AI` type (API reference, 2026-09-13); a paused call surfaces as a
  `ToolApprovalRequestContent` request in the workflow docs of the same date.
- **Session wrapper (row 2)** — maintainer corrected 2026-09-14: the current C# type is
  `AgentSession`, created by `agent.CreateSessionAsync()`; `AgentThread` is superseded.
- **Handoff and group chat** — both are documented as workflow *orchestrations* (2026-09-13): handoff
  via `AgentWorkflowBuilder.CreateHandoffBuilderWith` in `Microsoft.Agents.AI.Workflows`, confirmed
  by the maintainer 2026-09-14. Group chat is a sibling orchestration; its C# builder name remains
  unasserted until read from a page.
- **MCP client (rows 6, 10)** — `McpClient` from the official MCP C# SDK, with `McpClientTool`
  deriving from `AIFunction` (MCP tools page, 2026-09-13).
- **Other names confirmed by the maintainer, 2026-09-14** — `AIAgent`,
  `AIProjectClient(...).AsAIAgent(...)`, `AIContextProvider`, `TextSearchProvider`,
  `AgentSkillsProvider`, `McpClient`, `ApprovalRequiredAIFunction`, and `Microsoft.Agents.AI.Workflows`.
- **A2A compatibility retained open, 2026-09-14** — two hosted peers' wire-binding compatibility
  is not established by the documentation read. Keep the ingress/binding observation unverified
  and check compatibility before delegation; confirmation of the checklist does not verify it.

## Relocated source-material claims — 2026-09-14

These claims were moved here by the independent-review ruling on 2026-09-14; relocation is not
live verification. The T305 confirmation above does not verify these broader source-material claims.

- **Programming-model status** — the former Provenance text called the pre-Agent-Framework
  threads-and-runs model a "superseded programming model". Treat this as an unverified source-material
  assessment; check the framework's migration guidance before repeating it as current status.
- **Ingress protocol name** — the source demonstration material calls its ingress "the Responses
  protocol". The earlier deployment observation is dated 2026-09-04; the current protocol name and
  binding still require verification. The architectural row requires a compatible ingress contract
  and makes no current protocol-name claim.

## Preview-status components

Where a design depends on a component this file (or live documentation) marks as preview rather than
GA, record two things explicitly in the output, not just the preview status itself: the risk that
carries (a preview surface can change or be withdrawn before the design ships) and a pinning strategy
(an exact version or SDK commit the design is validated against, so a later preview change is a known
diff, not a silent behavior change). No specific preview component is asserted stable here; check live
documentation each time this section is consulted.

## Constructs whose exact current name/signature is not asserted here

The group-chat C# builder name and exact MCP elicitation API surface remain unasserted rather than
guessed. Session naming and the handoff builder were confirmed above by the maintainer on 2026-09-14.
Confirm each against the live SDK/documentation at the time of use — do not copy a name from a prior
architecture write-up in this repository without re-checking it here first.

## How to use this file

1. Never write a version number, availability status, or class signature into `construct-map.md` or
   `runtime-and-control.md` — put it here instead, dated.
2. Before generating any code or a final design document from this skill's output, re-verify every
   claim in this file against current documentation; treat a mismatch as this file being out of date,
   not the documentation being wrong.
3. When a fact here cannot be re-verified in the time available, say so explicitly in the output rather
   than passing the old date off as current.
