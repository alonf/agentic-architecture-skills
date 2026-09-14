# Behavioural verification — MAF mapping — GitHub Copilot CLI — 2026-09-11

**Recorded**: 2026-09-11T15:20Z (analysis) against the headless run captured earlier the same
session
**Host**: GitHub Copilot CLI 1.0.83, invoked as
`copilot -p "<prompt>" --allow-all-tools --allow-all-paths`
**Package**: installed from local path `agentic-architecture@agentic-architecture-skills` ("loaded
live", nothing copied), into this machine's Copilot CLI
**Working directory**: a fresh scratch directory outside this repository, seeded with only
`seed.txt`
**Detector**: Copilot appends a session-metadata footer (`Changes`, `AI Credits`, `Tokens`,
`Resume`) after every response, so that footer was stripped before checking any "last line"
condition. The router's terminal-line detector still did **not** transfer to this skill: Copilot's
positive mapping answers frequently omitted the expected closing line and sometimes compacted the
mapping to one construct paragraph or overreached into code/tutorial form. Final corpus figures are
therefore transcript-review numbers keyed primarily to the explicit
`● skill(maf-architecture-mapping)` banner, with the body reviewed to distinguish mapping from plain
router or host behavior.

## FR-041 — trigger corpus (`package/tests/triggers/mapping-corpus.md`, 30 phrasings)

| Metric | Result |
| --- | --- |
| Positive recall (P1-P15) | **11/15** |
| Missed positives | P5, P7, P9, P15 — all routed to `agentic-architecture-router` instead of loading the mapping skill |
| False positives (N1-N15) | **4/15** |
| False-positive ids | N9, N10, N11, N14 |

**Assessment**: Copilot loaded the mapping skill reliably on straightforward approved-decision
mapping prompts, but it still missed several boundary cases that used "session/memory/knowledge,"
"MCP client or server," or "AIAgent or function tool" wording. The false positives are materially
worse than a simple wording miss: N11 is a pure code request that loaded the mapping skill and then
printed a runnable C# sample, and N14 is a tutorial request that loaded mapping and then drifted
into a concept explainer.

## FR-017 — direct invocation without a prior decision (R1, 1 call)

| Rep | Prompt | Outcome |
| --- | --- | --- |
| R1 | `Map this to Microsoft Agent Framework constructs in .NET.` | **Held, but with both skills active** — Copilot loaded `maf-architecture-mapping`, then `agentic-architecture-router`, explicitly refused to assume agent/workflow/MCP shape, asked for a requirement or approved decision first, and stopped before naming constructs. |

## FR-018 / FR-021 / FR-022 — direct mapping scenario (R2-R4, 3 activating reps)

| Rep | Decision supplied | Outcome |
| --- | --- | --- |
| R2 | bounded AI for fraud-scoring | **Held** — mapped to a direct structured-output model call, explicitly excluded `AIAgent`, `AgentThread`, workflow, MCP, and approval constructs, and carried dated call-surface facts via `maf-surface.md` |
| R3 | single agent for run-time diagnostic branching | **Held** — mapped the diagnostic loop to `AIAgent`, named `AgentThread` as the interaction-scoped continuity construct with the name uncertainty flagged, and treated MCP/context/approval constructs as conditional extensions rather than silently assumed parts of the loop |
| R4 | human sign-off before one consequential tool call | **Held** — mapped to `ApprovalRequiredAIFunction`, separated it from workflow-gate and delegated-consent concerns, and kept live API/package/current-state details out of the answer body |

## SC-008 — volatile-surface discipline (R2-R4, with corpus caveat)

| Rep | Evidence |
| --- | --- |
| R2 | `IChatClient` was named only inside a dated-facts section tied back to `maf-surface.md`, with explicit re-verification against live docs before code |
| R3 | No version or availability claim was asserted; dated hosted-runtime findings were cited as dated 2026-09-04/05 and explicitly marked for re-check |
| R4 | The response explicitly said no package version, method signature, namespace, or GA/preview claim was being asserted inline, and pushed the dated facts back to `references/maf-surface.md` |

**Corpus caveat**: positive corpus case **P1** overreached into web search plus inline C# shape, and
negative corpus case **N11** printed a full tool-calling example after the skill loaded. Neither call
invented a package version, but both stepped outside the mapping skill's intended non-code boundary
and are retained in the transcript as measured failures of behavioral discipline.

## SC-009 — construct-map traceability (R2-R4)

| Rep | Constructs named | Traceability result |
| --- | --- | --- |
| R2 | direct structured-output model call; explicit non-use of `AIAgent`, `AgentThread`, `AIContextProvider`, workflow graph, `ApprovalRequiredAIFunction` | **Pass** — traces to the "when the decision was not an agent" preface plus explicit non-applicability of rows 1–12 |
| R3 | `AIAgent`; `AgentThread`; conditional `AIContextProvider`; conditional `McpClient` | **Pass** — traces to rows 1, 2, 4, and 6; no undemonstrated construct was asserted as demonstrated |
| R4 | `ApprovalRequiredAIFunction` with explicit contrasts to workflow gate and delegated-access consent | **Pass** — traces to row 9, with row-8/row-7 contrasts stated as contrasts only |

## Attachments

- `2026-09-11-behavioural-attachments/mapping-corpus-copilot-raw.txt` — all 30 corpus transcripts
  (masked)
- `2026-09-11-behavioural-attachments/direct-mapping-copilot-raw.txt` — the 4 direct-invocation
  transcripts (masked)
