# Combined router and mapping remeasurement — 2026-09-14 UTC

**Tasks**: T306, T307. **Source**: `93cca60cebb64d90fea78226fbf710846c37dce7`.
**Status**: captures complete; scoped assessment complete with failures retained; not sign-off.
**Hosts**: Claude Code 2.1.270 (default headless permissions/default model), Copilot CLI 1.0.83
(default model, --allow-all-tools --allow-all-paths). Local plugin-dir loading from a frozen copy,
not a released installation. Each call used a fresh scratch directory containing its prompt only.
Two host workers shared one coordinator, 24 cases each. All 48 completed, no timeouts/nonzero exits.
Captured host dates can reflect Pacific 2026-09-13 while records use UTC 2026-09-14; two responses
flagged the UTC confirmation date as future. The confirmation is human evidence, not a new live test.

## Scope and results

| Probe | Claude | Copilot | Interpretation |
| --- | --- | --- | --- |
| Scheduled threshold, 3 repetitions | 3/3 deterministic routing | 3/3 deterministic routing | No agent justified; unspecified dispatch policy surfaced |
| Classification, original mixed prompt, 3 repetitions | 3/3 bounded-AI architecture analyses | 0/3 architecture analyses; all answer unknown | Repeats activation/interpretation failure; no clarified-condition replacement was substituted |
| Fixed approval process, 3 repetitions | 3/3 deterministic workflow | 3/3 deterministic workflow | Routing criterion met; does not attest every sentence |
| Decision Card, 3 repetitions | 3/3 line/field/terminal shape | 2/3 shape | Copilot card 1 has 14 lines but ten fields, duplicating Agent boundary; others 13 lines/nine fields |
| Card authorization, missing stated policy | 2/3 retain unknown policy; card 3 invents permitting rule | 3/3 retain unknown policy | Claude failure persists despite placeholder correction; probable cause is not established causality |
| Worked example, one | Single read-only investigator, bounded report | Single investigator with deterministic controls | Routing supported; no claim of complete evidence-gate compliance |
| Missing facts, one | No concrete root cause asserted | No concrete root cause asserted | Evidence and policies left unresolved; no blanket zero-invention verdict |
| Embedded directive, one | Conflict surfaced, challenge retained | Conflict surfaced, challenge retained | Scoped SC-007 behavior observed |
| Mapping existing API/no MCP, 3 repetitions | 3/3 function tool, no MCP | 3/3 function tool, no MCP | Cross-team ownership alone does not earn MCP |
| Mapping currency/uncertainty, 3 repetitions | 3/3 AgentSession, unresolved A2A/group-chat naming retained | 3/3 same scoped naming/uncertainty behavior | Copilot repetitions 2 and 3 add an unstated human gate; DRIFT-012 |
| Mapping coverage, 3 repetitions | 3/3 distinguish twelve staged rows from named-but-not-demonstrated material | 3/3 same distinction | Confirmation of names is not proof of demonstration; assessed against source material's stated coverage |

## Limits and retained failures

SC-003 and SC-005 are not universally met: Copilot's classification condition and one card fail.
Claude card 3 calls the preconfigured rule dispatch authority, although the prompt supplies no
such policy (FR-009). Several cards select breach-state suppression or per-tick semantics while
acknowledging unresolved one-alert semantics. Do not turn these recordings into all-quality-gates
passes. Round-3 #2 was accepted as recorded; that acceptance does not automatically waive newly
observed repetitions. Human partial acceptance is still pending.

The mapping currency probes reproduce the human-gate assumption in Copilot 2/3, supplying runtime
support for the already-authorized DRIFT-012 edit. Other mapping targets pass their scoped checks;
no new model run after the final two edits is claimed. SC-008 is a source-inspection criterion:
AgentThread status and creation signatures live in the dated surface; runtime row 3 retains unknown
binding compatibility. SC-009 coverage is source-relative, not an independent replay of the demos.

Raw stdout includes transport/encoding artifacts in some Unicode punctuation; it is preserved
unchanged. Card counts extract from `# Decision Card` through the ASCII terminal sentence, removing
host preambles/footers, not internal blank lines. Host banners alone are not an activation pass.
No trigger-corpus recall, no fresh SC-004 enforcement probe, and no frontmatter-hook remeasurement
was performed; those figures remain their previously dated results. A process exit is not a semantic
verdict. These are local-content tests; T310 final-content export/install remains separate.

## Evidence

`2026-09-14-combined-attachments/` preserves all 48 prompt/response/stderr/run groups plus the case
manifest and host versions. The source snapshot precedes the two DRIFT-012 corrections by design.
No captures were overwritten, retried, or silently replaced. Full semantic acceptance is not claimed.
