# Behavioural verification — MAF mapping — Claude Code — 2026-09-11

**Recorded**: 2026-09-11T15:20Z (analysis) against the headless run captured earlier the same
session
**Host**: Claude Code 2.1.268, invoked headless as `claude -p "<prompt>" --output-format text`
**Package**: installed from local path `agentic-architecture@agentic-architecture-skills`, user
scope, into this machine's Claude Code
**Working directory**: a fresh scratch directory outside this repository, seeded with only
`seed.txt`
**Detector**: the router's terminal-line detector did **not** transfer cleanly to this skill. The
mapping corpus was first scored with a conservative body-marker detector and undercounted several
obvious compact-form mappings. Final corpus figures below are the corrected transcript-review
numbers: a load counts when the response actually performs a MAF construct mapping or a mapping-skill
request-for-decision; the raw transcript is the source of truth. Copilot-style session footers do
not exist on Claude's text output, so no footer stripping was needed here.

## FR-041 — trigger corpus (`package/tests/triggers/mapping-corpus.md`, 30 phrasings)

| Metric | Result |
| --- | --- |
| Positive recall (P1-P15) | **14/15** |
| Missed positives | P14 — Claude asked for the underlying mechanism decision before accepting a hosting-only prompt, so the row-12/hosting phrasing did not load the mapping skill as authored |
| False positives (N1-N15) | **2/15** |
| False-positive ids | N9, N10 |

**Correction on the first detector pass**: the initial marker-only pass undercounted compact
mapping answers such as P3, P4, P5, P9, P13, and P15 because Claude often answered in a short
"This maps to row X" form without the fuller heading set the draft detector expected. Those cases
were re-read from the raw transcript and are counted as loads in the final figures above. The raw
file is retained unchanged; only the measurement interpretation changed.

**Assessment**: Claude was strong on explicit approved-decision prompts and weak only on the
hosting-only positive. The two false positives crossed the intended boundary in the specific way the
corpus is meant to catch: requirement-only mapping phrasings without a prior router decision still
received a mapping answer.

## FR-017 — direct invocation without a prior decision (R1, 1 call)

| Rep | Prompt | Outcome |
| --- | --- | --- |
| R1 | `Map this to Microsoft Agent Framework constructs in .NET.` | **Held** — Claude did not guess a construct. It asked for the architecture/design or approved decision first, named example decision shapes, and stopped before mapping. No construct, runtime, or version claim was asserted. |

## FR-018 / FR-021 / FR-022 — direct mapping scenario (R2-R4, 3 activating reps)

| Rep | Decision supplied | Outcome |
| --- | --- | --- |
| R2 | bounded AI for fraud-scoring | **Held** — mapped honestly to a direct structured-output model call, explicitly *not* `AIAgent`/`AgentThread`, separated adjacent downstream approval concerns, and carried the current call-surface name only via `maf-surface.md` with a re-verify warning |
| R3 | single agent for run-time diagnostic branching | **Held** — mapped the loop to `AIAgent` (row 1), named `AgentThread` as the interaction-scoped continuity construct with the `AgentThread`/`AgentSession` uncertainty flagged, and carried runtime-control / assurance concerns without inventing hosting facts |
| R4 | human sign-off before one consequential tool call | **Held** — mapped to `ApprovalRequiredAIFunction` (row 9), explicitly distinguished it from row 8's workflow gate and row 7's elicitation pause, and recorded the live-doc re-verification requirement for current surface details |

## SC-008 — volatile-surface discipline (R2-R4)

| Rep | Evidence |
| --- | --- |
| R2 | `IChatClient` was named only as a dated surface carried from `maf-surface.md`, with explicit "re-verify before citing namespace/package version" language |
| R3 | No package version, method signature, or availability claim was asserted inline; the only volatile naming caveat was the unresolved `AgentThread` vs `AgentSession` question, flagged as uncertain rather than asserted |
| R4 | No version/signature claim was asserted; the response explicitly said the exact current surface for `ApprovalRequiredAIFunction` must be confirmed against live docs before code is written |

**Assessment**: the direct-invocation scenario held cleanly on Claude. The responses named constructs
and architectural properties, but volatile API/package/current-state facts were pushed back to
`maf-surface.md` or flagged as unconfirmed. No dated/platform claim was passed off as current from
memory.

## SC-009 — construct-map traceability (R2-R4)

| Rep | Constructs named | Traceability result |
| --- | --- | --- |
| R2 | direct structured-output model call; explicit non-use of `AIAgent` / `AgentThread` / hosted runtime | **Pass** — traces to the "when the decision was not an agent" preface in `construct-map.md` |
| R3 | `AIAgent`; `AgentThread` (uncertain current name flagged); conditional `AIContextProvider` / `McpClient` only as adjacent, separately-routed extensions | **Pass** — traces to rows 1, 2, 4, and 6 respectively; no slide-only construct was asserted as demonstrated |
| R4 | `ApprovalRequiredAIFunction`; explicit contrasts with workflow gate and MCP elicitation | **Pass** — traces to row 9, with rows 8 and 7 cited only as contrasts |

## Attachments

- `2026-09-11-behavioural-attachments/mapping-corpus-claude-raw.txt` — all 30 corpus transcripts
  (masked)
- `2026-09-11-behavioural-attachments/direct-mapping-claude-raw.txt` — the 4 direct-invocation
  transcripts (masked)
