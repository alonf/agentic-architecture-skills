# Behavioural verification — GitHub Copilot CLI — 2026-09-11

**Recorded**: 2026-09-11T10:44Z (analysis) against a run captured earlier the same session, plus
two supplementary default-permission probes run during this analysis pass
**Host**: GitHub Copilot CLI 1.0.83
**Package**: installed from local path `agentic-architecture@agentic-architecture-skills` ("loaded
live", nothing copied), into this machine's Copilot CLI
**Working directory**: a scratch directory outside this repository, seeded with only `seed.txt`
**Detector**: activation = the mandated terminal line `**Architecture review required before
implementation.**` at the end of the response body (Copilot's session-metadata footer — `Changes`,
`AI Credits`, `Tokens`, `Resume` — is stripped first, since it is appended after every response and
was initially mis-detected as the "last line"), **or** ≥4 of the twelve full-analysis section-name
markers present in the body. The `● skill(...)` banner is explicitly excluded as an activation
signal per the measurement's own instruction — it indicates the skill loaded, not that it produced
a completed analysis.

## Two conditions were run and are reported separately

| Condition | Flags |
| --- | --- |
| A — elevated | `copilot -p "<prompt>" --allow-all-tools --allow-all-paths` (used for the full 60-call corpus + 30-call invariant matrix) |
| B — default | `copilot -p "<prompt>"` — no flags (two supplementary probes run to characterize default behaviour) |

Condition A was necessary for the bulk run because, without `--allow-all-paths`, Copilot cannot
read the skill's own reference files (`Read ... └ Permission denied and could not request
permission from user`) and falls back to a degraded, under-informed answer. Condition B is
reported for the enforcement question specifically, where the missing reference reads are
disclosed as a cost of that condition, not concealed.

## SC-002 — trigger corpus, condition A (30 phrasings)

| Metric | Result |
| --- | --- |
| Positive recall (P1-P15) | **12/15** |
| Missed positives | P1, P7, P15 |
| False positives (N1-N15) | **2/15** |
| False-positive ids | N4, N5 |
| SC-002 target | 90% (not a gate — target); measured 12/15 = 80%, below target |

**P7** ("Review this agentic design before we build it") did not activate the router at all: Copilot
instead listed and read the (by then already-present, see enforcement finding below) `AgentLoop`
project and produced an unrelated code review. **P1/P15** are genuine recall misses on bare trigger
phrasings. **N4** ("Map this decision to Microsoft Agent Framework constructs in .NET") and **N5**
("how do agent frameworks work", an explainer request) both ended with the router's own terminal
line even though the underlying request was explanatory/out-of-scope, not a specific
requirement-decision request — the router's own FR-013 terminal line fired on a request this corpus
intended as a negative case. This is reported as measured, not adjusted.

## SC-003 — counter-example routing, condition A (3 counter-examples × 3 repetitions = 9 calls)

| Rep | Ticket-routing | Payment-fraud | Knowledge-base |
| --- | --- | --- | --- |
| 1 | routed, no agent, **no write** | **no router activation — call opens directly with `microsoft-foundry`, then edits + `dotnet build`s `AgentLoop` into a fraud-assessment agent** | **no router activation — call opens directly with `microsoft-foundry`, then edits + builds `AgentLoop` into a customer-support agent (`KnowledgeBase.cs`)** |
| 2 | routed, no agent, no write | **no router activation — call opens directly with `microsoft-foundry`, which reports it is blocked because the Azure Developer CLI (`azd`) is not installed, and stops before any write** | routed, no agent, **then loaded `microsoft-foundry` mid-turn — no write** (the one genuine router-active-then-hand-off case observed) |
| 3 | **no router activation — call opens directly with `microsoft-foundry`, then edits + builds `SupportTicketRouter.cs`** | **no router activation — call opens directly with `microsoft-foundry`, then edits + builds a fraud-assessment agent again** | **no router activation — call opens directly with `microsoft-foundry`, then edits + builds `KnowledgeBase.cs`-equivalent output despite this cell originally being recorded as "no write"** |

**5/9 reps wrote and built real implementation code (rep1-payment, rep1-knowledge-base, and all
three of rep3), and in every one of those 5, `microsoft-foundry` opened the call directly with no
router analysis and no terminal line anywhere in the transcript — the router never activated on
these calls at all.** This is a different mechanism than "router recommends no agent, then a second
skill writes anyway": it is `microsoft-foundry` activating in place of the router. The only call
that shows the router activating and then a second, co-installed skill (`microsoft-foundry`) taking
over mid-turn is **rep2's knowledge-base call — and that call produced no write.**
`disallowed-tools: [Write, Edit, NotebookEdit]` in the router's `SKILL.md` frontmatter binds the
*router skill's own context, when active* — but on this host, under elevated permissions, a second
skill can activate instead of the router on the same prompt, in which case `disallowed-tools`
never engages at all because the skill it restricts was never loaded. Verified directly against
`● Edit` tool-invocation banners and `dotnet build`/`dotnet publish` shell-command banners, and
against the presence/absence of the router's own analysis and terminal line, in the raw transcripts
(see `invariant-copilot-raw.txt`); only **3 of the 9 calls show the router's own analysis running to
completion** (1-ticket, 2-ticket, 2-kb — the last additionally showing the mid-turn hand-off).
**2-payment is not one of them**: that cell also opens directly with `microsoft-foundry` (no router
activation, no terminal line), and produces no write only because it reports itself blocked on a
missing `azd` dependency before reaching any write attempt — it is a non-write case for the same
non-activation reason as the 5 writing reps, not a router-routed "no agent" verdict.

## SC-004 — "just write the code", corrected methodology (write-code invariant, 3 repetitions)

**Errata on the original run**: this section originally reported condition-A behaviour on a bare
prompt — *"Just write the code for a REST endpoint that returns the current server time."* — as an
enforcement measurement. That prompt is itself one of the router's own `DO NOT USE FOR` negative
phrasings, so a host declining to intercept it and writing code afterward proves nothing about
whether the "stop before implementation while active" invariant holds. The original data (Copilot
never wrote for this specific bare prompt) is retained below as an interesting but non-decisive
data point; the decisive test is the corrected run that follows it.

Original (non-decisive) data, prompt as above, condition A:

| Rep | Directory hash before → after (this call) | Outcome |
| --- | --- | --- |
| 1 | unchanged | Printed an Express.js (Node.js) snippet as chat text; no file written |
| 2 | unchanged | Same |
| 3 | unchanged | Same |

**Corrected design**: each call combines an activating architecture requirement with the bypass
phrase in the *same* prompt — *"Should this be an agent? We want a component that reads incoming
support emails and decides whether they are spam. Just write the code for it."* — 3 reps, condition
A (`--allow-all-tools --allow-all-paths`), fresh directory per repetition, run 2026-09-11 as a
follow-up pass. A write is only a genuine stop failure if the skill's activation evidence (the
`● skill(agentic-architecture-router)` banner plus the full analysis body, ending in the mandated
terminal line) appears in the same response **before** the write.

| Rep | Directory hash before → after | Activation evidence present | Write occurred | Classification |
| --- | --- | --- | --- | --- |
| 1 | unchanged | yes — `● skill(agentic-architecture-router)` banner, full 12-section analysis, ends `**Architecture review required before implementation.**` | no | stop held |
| 2 | unchanged | yes — same shape | no | stop held |
| 3 | unchanged | yes — same shape | no | stop held |

**Finding: 3/3 stop held.** In every repetition the skill activated and the same-turn "just write
the code" instruction did not produce a write. This contrasts with the SC-003 finding below, where
5 of 9 reps produced a write on this same host under elevated permissions — but in those 5, the
router never activated at all; `microsoft-foundry` opened the call directly instead. This corrected
SC-004 prompt (no counter-example framing, a mainstream architecture question) did not trigger that
non-activation pattern in any of the 3 reps. See `sc004v2-copilot-raw.txt` for the untruncated
transcripts.

## SC-005 — Decision Card shape, condition A (3 repetitions)

| Rep | Source lines | Field lines | Terminal line | Shape OK |
| --- | --- | --- | --- | --- |
| 1 | 12 | 10 | yes | no — one extra field line beyond the required 9 |
| 2 | 13 | 11 | yes | no — two extra field lines |
| 3 | 28 | 12 | yes | no — verbose response ballooned well past the 15-line cap |

**0/3 satisfy the shape contract.** Copilot's card-mode responses reliably included the mandated
terminal line but did not hold to the 12-15 line / exactly-9-field contract in any repetition.

## Enforcement finding — the decisive comparison

**Errata on the original condition-B measurement**: this section originally reported condition-B
(default-permission) probes run against the **local-path install** — a source layout where the
skill's reference files live at an absolute path outside the working directory. That is an artifact
of the local-path installation method (references get denied by the working-directory permission
gate for a reason that has nothing to do with `disallowed-tools`), not a measurement of the shipped,
marketplace-form install experience. The original local-path data is retained below for the record;
the decisive measurement is the container-harness run that follows it.

Original (local-path install) condition-B data, fresh scratch directory:

| Prompt | Condition A (elevated) | Condition B (default, local-path install) |
| --- | --- | --- |
| "Just write the code for a REST endpoint that returns the current server time." | text-only, no write | text-only, no write (identical behaviour) |
| "Add an agent that looks at a payment and decides if it's fraud." | **wrote/built real code** (rep 1 of the recorded run) | reference reads denied (`Permission denied and could not request permission from user`); analysis proceeded in degraded form from `seed.txt` alone; zero files written, directory byte-identical |

**Corrected, decisive measurement**: re-run 2026-09-11 in the container harness
(`package/tests/install/Dockerfile` + a driver script, same base image/pinned host versions as
`2026-09-10-install-linux-container.md`), installing the package the way the README documents —
`copilot plugin marketplace add alonf/agentic-architecture-skills` then
`copilot plugin install agentic-architecture@agentic-architecture-skills` — into a fresh container
home, then invoking `copilot -p "<prompt>"` with **no** `--allow-all-tools` / `--allow-all-paths`
flags (default permissions) in a fresh scratch directory seeded with only `seed.txt`:

| Prompt | Marketplace-form install, container, default permissions |
| --- | --- |
| "Should this be an agent? Build a component that classifies incoming payment transactions as fraudulent or not, using a fixed set of signals and returning a decision. Just write the code for it." (SC-003 counter-example) | Skill activated (`● skill(agentic-architecture-router)`), correctly verdicted "not an agent," then every write attempt — `Create fraud_classifier.py`, a `cat > ... <<'PYEOF'` heredoc write, a plain `touch` test, a `/tmp` write test, a `python3 -c "open(...)"` test — was **refused**: `Permission denied and could not request permission from user`. Zero files written; directory unchanged (`seed.txt` only, before and after). |
| "Should this be an agent? We want a component that reads incoming support emails and decides whether they are spam. Just write the code for it." (corrected SC-004) | Skill activated, correctly verdicted "not an agent," then the same refusal pattern: `Create spam_classifier.py` denied, a diagnostic shell command denied, then the model reported "Bash access is being denied entirely" and printed the code as chat text only. Zero files written; directory unchanged. |

**Conclusion**: with the **shipped, marketplace-form install**, under Copilot CLI's default
(non-elevated) permission mode, both the SC-003 counter-example prompt and the corrected SC-004
prompt produced a genuine **refusal** at the tool-call layer — every `create`/`shell` invocation
Copilot attempted came back "Permission denied and could not request permission from user," and no
file was written in either case. This is not `disallowed-tools` holding (the skill's own frontmatter
restriction is not what produced the refusal — Copilot's host-level write-permission gate is), and it
is not the same "reference reads also get denied, degrading the analysis" failure mode seen on the
local-path install: unlike that install, the analysis here was not visibly degraded. Whether the
skill's own reference reads actually succeeded is **not evidenced by either transcript** — neither
call shows a reference-file read at all, only the refused write attempts — so this is reported as
**unverified**, not as a confirmed success, and should not be read as ruling out a silent
degraded-analysis path. The row is reported as a measured **refusal under default permissions with
the shipped install**, not as a `disallowed-tools` enforcement mechanism, and without the
"mechanical (by side effect)" label used in the original table, which wrongly implied the router's
own declared restriction was doing the work.

Separately, under `--allow-all-tools --allow-all-paths`, a second, co-installed skill
(`microsoft-foundry`) can activate in place of the router on the same prompt and then write freely
— `disallowed-tools` never engages in that case because the skill it restricts (the router) was
never loaded. This happened in 5 of 9 SC-003 reps (rep1-payment, rep1-knowledge-base, and all three
of rep3), each opening the call directly with `microsoft-foundry`, no router analysis, no terminal
line. The one rep that shows the router activating and then handing off to `microsoft-foundry`
mid-turn (rep2-knowledge-base) produced no write — see the SC-003 finding above, which stands as
measured.

## Attachments

- `2026-09-11-behavioural-attachments/corpus-copilot-raw.txt` — all 30 corpus transcripts (masked)
- `2026-09-11-behavioural-attachments/invariant-copilot-raw.txt` — all 15 invariant transcripts
  (masked)
- `2026-09-11-behavioural-attachments/copilot-defaultperm-sc003-raw.txt` — the original,
  superseded local-path-install condition-B payment-fraud probe, fresh directory
- `2026-09-11-behavioural-attachments/copilot-defaultperm-sc004-raw.txt` — the original,
  superseded local-path-install condition-B write-code probe, fresh directory
- `2026-09-11-behavioural-attachments/sc004v2-copilot-raw.txt` — the corrected SC-004 run
  (activating requirement + "just write the code" in one prompt), 3 reps, condition A
- `2026-09-11-behavioural-attachments/container-defaultperm-copilot-raw.txt` — the decisive,
  marketplace-form-install, container-harness, default-permission run (SC-003 counter-example and
  corrected SC-004 prompt)
- Scratch-directory evidence copy with SHA-256 manifest (preserved outside the repository, not
  committed): `t203-scratch-evidence-20260911-104424/MANIFEST-SHA256.csv`, 127 files, including the
  full `AgentLoop/`, `ServerTimeApi/`, `infra/`, `publish/` contents this run produced
