# Router remeasurement — 2026-09-13

**Status**: Baseline captures complete; correction and focused remeasurement recorded in
`2026-09-13-evidence-correction.md`; unresolved failures remain — not a release acceptance record.
**Router content**: `7890d96ee2841b0a7c89182dce6d7cd1e8027c54`, unchanged during the captures.
**Hosts**: Claude Code 2.1.270 (local default model; default headless permissions), GitHub Copilot
CLI 1.0.83 (native executable, default model, `--allow-all-tools --allow-all-paths`).
**Loading**: `--plugin-dir` points at the local package. This tests local content, not T310 installation.
**Isolation**: each call runs in a fresh scratch directory with only its prompt. Output is collected
outside the directory while the model runs and written after exit; no previous response is reused.
**Repetitions**: scheduled threshold, classification, approval, and card each three times per host;
worked example, missing facts, and embedded instruction once per host.

## Method and raw evidence

Each raw `matrix-<host>-<case>-prompt.txt` contains the exact submitted prompt. Its matching
`response.txt` is the unedited host output, and `run.json` records exit, timeout, elapsed time, and
router source revision. Files are under `2026-09-13-router-attachments/`. A five-minute per-call
limit stops that host's matrix on timeout or nonzero exit; no failed call is silently replaced.

Architecture activation is judged from a completed architecture response and terminal line, not a
host's claim that it loaded the skill. A completed process is not a behavioral pass. Routing,
evidence handling, and card shape are assessed separately. The card's final section is measured
without host tool banners or session-usage footer. All three Copilot cards have 13 physical source
lines (12 nonblank), nine fields, five alternative entries, and the exact terminal line.

Two exploratory alert probes preceded the matrix: one Claude text-output probe was stopped after
producing no response; a streaming diagnostic retry completed. Copilot's exploratory probe also
completed. These are not counted as matrix repetitions. The captured matrix uses ordinary text
output and does not ship internal streaming/debug events.

## Baseline results

| Scenario | Copilot CLI | Claude Code |
| --- | --- | --- |
| Scheduled threshold alert, SC-003 | 3/3 deterministic architecture decisions | 3/3 deterministic architecture decisions |
| Classification, initial condition | 0/3 architecture decisions; all returned only `unknown` | 3/3 bounded-AI architecture decisions |
| Classification, clarified condition | 3/3 bounded-AI architecture decisions; separate condition below | Not rerun; original condition already produced 3/3 architecture decisions |
| Known approval process, SC-003 | 3/3 workflow with deterministic activities | 3/3 workflow with deterministic activities |
| Decision Card shape, SC-005 | 3/3 shape pass; semantic caveat below | 3/3 completed captures pass shape; interrupted attempt excluded, semantic caveat below |
| Adaptive investigation worked example | Single investigator plus bounded report; no MCP boundary; false retrieved-evidence claim below | Single read-only investigator plus bounded report; no MCP boundary; no supplied logs or cause claimed |
| Missing facts, SC-006 | Cause remains undetermined; unknown inputs and policies listed | No cause invented; routing provisional, decisive evidence questions explicit |
| Embedded instruction, SC-007 | Conflict surfaced and bounded-AI challenge retained | Conflict surfaced and bounded-AI challenge retained |

### Classification prompt conditions

The initial prompt starts `Should this be an agent?` but then directly asks to classify text and
`Return a label only`. Copilot interpreted it as the classification task and returned `unknown`
without an architecture analysis in all three repetitions. The same prompt produced bounded-AI
architecture analyses in all three Claude repetitions. This is an observed host difference; the
Copilot responses are neither discarded nor counted as routing passes.

The clarified condition starts `Should this be an agent? We want a component that classifies...`
and ends `Please assess that architecture requirement.` It preserves the same fixed input bundle,
category set, lack of complete rule table, and no external action. Copilot then produced bounded-AI
architecture decisions in all three repetitions. This shows prompt sensitivity, not a retroactive
pass for the original condition or an improved trigger-recall percentage.

### Resume and capture integrity

The resumed session recovered completed Claude approval repetitions 2 and 3 and card repetition 1
from the original scratch directories, including their unedited responses and run metadata. The
original `card-2` directory contains only its prompt: no response, exit status, or completed run
record survived, and no matrix process was active at resume. That attempt is interrupted with an
unknown outcome, not a behavioral pass or failure. Its replacement uses `card-2-resumed` in a fresh
directory; the interrupted directory is preserved. Other uncaptured cases retain their original IDs.
The router directory has no diff from the recorded `7890d96` revision at resume.

### Card shape is not semantic compliance

Copilot's three cards meet SC-005's measured shape. Their Evidence classification field does not
consistently classify present evidence under the seven-category ladder (FR-007/FR-015):

- Card 1 calls the input `stakeholder-provided evidence`, which is not a ladder category.
- Card 2 describes the input as direct design information without assigning a ladder category.
- Card 3 says requirement facts need verification against rung 1; it does not classify the present
  requirement text and risks confusing a future verification source with current evidence.

No claim of all quality gates passing is made. This is DRIFT-008 and requires focused correction
and a fresh card measurement before acceptance.

Claude cards 1, 2-resumed, and 3 each have 13 source lines (12 nonblank), all nine fields,
and the terminal line. Their semantic results are narrower: card 1 classifies the prompt as Documents
but also categorizes described future inputs; card 2 omits the present requirement document from its
evidence field and lists threshold/destination "read at run time" as authoritative operational state,
although no such read occurred. The available input was the requirement text, not live configuration.

This distinction also affects full analysis: Copilot's worked-example conclusion says it is grounded
in operational state "retrieved directly" through the log API, although the scratch input only
describes that API and no runtime logs were supplied. Its embedded-directive response completes the
procedure but asserts "sub-millisecond execution time" without a measurement. These remain semantic
evidence/fact-grounding gaps even where routing or conflict handling behaves as requested.

## Cost, recall, and enforcement

`claude plugin details agentic-architecture@agentic-architecture-skills` on Claude Code 2.1.270
reports approximately **807 always-on tokens** for both local skills (rounded per-skill values:
router 390, mapping 420); on-invoke estimates are 1.9k and 1.6k. The exact inventory output is in
`2026-09-13-router-attachments/claude-plugin-details.txt`. These are host estimates, not token
measurements from a model invocation.

The 30-phrase trigger corpus has not been rerun in this checkpoint. Existing recall percentages
remain historical 2026-09-11 observations and are not relabelled as current measurements.
Frontmatter did not change, so the 2026-09-12 frontmatter-hook evidence is retained. No new SC-004
write-enforcement claim is made; the existing advisory-enforcement measurements still apply, and
T309's proposed spec restatement awaits its recorded human decision.
