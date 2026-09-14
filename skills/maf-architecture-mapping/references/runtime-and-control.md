# Runtime and Control

**Traces**: FR-018, FR-021

Seven rows answering one question each: **where does this run, and who controls it once it is
running** — folded together from what were separately "hosting" and "protocols" concerns in the
workshop record, because in practice a hosting choice and a protocol choice are made together and
constrain each other. This file stays at the level of architectural property; every dated fact,
version number, or availability claim belongs in `maf-surface.md` instead, verified live, never here.

*(Unsure note, applies to the whole file: exact current class/service names for hosting and identity
constructs are not repeated here on purpose — this file states the property; `maf-surface.md` and live
documentation are where a name gets attached, dated, so this file does not go stale when a name
changes.)*

## The seven rows

1. **Hosting placement** — does the agent run in-process with the caller, or in a separately hosted
   runtime? This is the first fork: in-process hosting has no isolation boundary between agent and
   caller; a hosted runtime introduces one, and everything else in this file follows from which side of
   that fork was chosen.

2. **Ingress contract** — what protocol does the endpoint actually accept? A hosted agent's primary
   ingress is its own request/response contract (dated protocol names belong in `maf-surface.md`);
   A2A delegation (`construct-map.md` row 11) is layered on top of that ingress, not an alternative to
   it — a peer cannot delegate a task to an agent whose ingress it cannot reach.

3. **Protocol negotiation and binding** — even where two hosted agents both speak A2A, they may not
   share a wire binding (for example JSON-RPC vs. HTTP+JSON) or a protocol version. This is why
   discovery (agent-card) exists as its own step before delegation: binding compatibility is not implied
   by both sides "supporting A2A".

4. **Isolation** — a hosted runtime's isolation model determines what one session can and cannot see or
   affect of another. The demo material's verified property is per-session isolation (each session gets
   its own sandbox), not a shared pool with a replica count — treat any claim of "scales like a web app
   replica set" as a platform fact to re-verify in `maf-surface.md`, not an architectural default.

5. **Runtime control (lifecycle)** — who decides when a session starts, idles out, and is reclaimed?
   This is a property of the hosting layer, independent of the agent's own reasoning: the agent does not
   control its own lifecycle, and a design must not assume a session persists past what the hosting
   layer's idle/reclaim policy allows.

6. **Estate control (identity propagation)** — how does the calling user's identity reach the running
   agent, and what does it actually prove? A propagated identifier is not the same guarantee as a
   propagated, verifiable credential — if a design needs the agent to act *as* the calling user against
   a downstream system, that needs an explicit delegated-access consent step, not an assumption that an
   identity header already grants it.

7. **Human authority (which layer holds it)** — this repository already distinguishes three separate
   authority mechanisms, each at a different layer, and a design must name which one applies rather than
   treating "there's a human in the loop" as one fact: the workflow-level gate (`construct-map.md` row
   8), the per-tool-call approval (`construct-map.md` row 9), and the delegated-access consent flow from
   row 6 above. A requirement that needs human sign-off must be routed to the one of these three whose
   granularity actually matches the operation — a workflow gate does not substitute for per-call
   approval, and neither substitutes for consent to act as the user.

## What this file is not

It does not state which SDK class implements a given property, which protocol version is current, or
whether a given capability is GA or preview — those are dated platform facts and belong in
`maf-surface.md`, checked against live documentation at the time they are used, never copied forward
from here.
