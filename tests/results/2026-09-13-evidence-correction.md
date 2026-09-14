# Evidence correction verification — 2026-09-13

**Status**: Captures complete; partial improvement with unresolved failures — not release acceptance.
**Source revision**: `9bdb2f7` (full SHA recorded with each capture).
**Scope**: DRIFT-008, FR-002, FR-007, FR-015; card shape SC-005.

The baseline is preserved in `2026-09-13-router-remeasurement.md`. The correction explicitly
separates sources actually supplied/read from runtime sources only described in the requirement.
It also requires an evidence-category name, not an invented category or only a future verification plan.

The original prompts and harness are reused in fresh scratch directories. Each host runs three
cards, one adaptive worked example, and one embedded-directive scenario, with a five-minute limit
per call and no silent replacement on failure. Hosts and permissions match the baseline. Source
content remains fixed throughout these probes; no earlier response is reused as model context.

For each result, verification examines whether the response classifies the available requirement
text as Documents (4), separates described live data/configuration/logs as unobserved or proposed,
avoids invented retrievals or performance measurements, preserves applicable caveats, and retains
the original routing and authority requirements. Cards must also retain 12–15 source lines, all
nine fields, five alternative verdicts, all five authority stages, and the exact terminal line.

This focused run does not remeasure trigger recall or SC-004 write enforcement. Those remain
the dated historical results. The original classification prompt's non-activation remains visible.

## Results

| Condition | Claude Code | Copilot CLI |
| --- | --- | --- |
| Original card prompt, three repetitions | 3/3 shape passes and corrected evidence classification; remaining semantics below | Only card 1 activates the router and classifies evidence correctly; cards 2 and 3 return generic summaries without required fields or terminal line |
| Adaptive worked example | Requirement text is the only observed evidence; runtime logs/API explicitly proposed; one investigating agent retained | Requirement text is the only evidence relied on; runtime logs/API are explicitly not observed; one investigating agent retained |
| Embedded directive | Documents (4) versus unobserved runtime sources is explicit; conflict, bounded-AI challenge, and unknown dispatch policy retained | Documents (4) versus unobserved runtime sources is explicit; directive conflict and bounded-AI challenge retained |
| Explicit skill-name card prompt, three repetitions | Not run | 3/3 activate and classify evidence correctly; authority/fact caveat below |

The explicit condition prepends `Use the agentic-architecture-router skill.` to the unchanged card
prompt. It tests content behavior when the skill is directly requested. It does not replace any
original prompt outcome, demonstrate reliable automatic activation, or improve a recall percentage.
The fresh original-condition Copilot card result is **1/3 activation**, not the baseline's 3/3.
No frontmatter changed between these runs; the captures demonstrate variability, not a causal claim
that the body correction caused non-activation.

Raw prompts, responses, and run metadata are in `2026-09-13-evidence-correction-attachments/`.

Card shape counts from the final card section (excluding tool output and introductory narration):
Claude original cards: 13/13/13 lines; Copilot original card 1: 12 lines; Copilot explicit cards:
13/12/13 lines. Each of these seven cards contains all nine fields and the exact terminal line.
Original Copilot cards 2 and 3 have no compliant card section. Five alternative labels and authority
stages appear in the seven structured cards, but their semantic sufficiency is not implied by shape.

## Remaining semantic failures

Explicit Copilot card 3 states "no repository files present" although the fresh directory contains
`prompt.txt` and the response shows no directory inspection. It also treats a "pre-configured rule
policy verdict" as authorization and omits the required unknown-policy phrase. The requirement
states a configured comparison rule and destination; it does not establish dispatch authorization.
Thus evidence-field improvement does not establish FR-002/FR-009/FR-015 compliance.

Some completed cards also adopt alert suppression state while acknowledging that one-per-tick
versus one-per-episode semantics are unresolved (Claude cards 1 and 3; explicit Copilot card 1).
Those implementation choices remain proposals needing confirmation, not facts established by the
requirement. No blanket all-quality-gates pass is claimed for these cards.

All 13 focused calls exited successfully without timeout. Successful process exit is distinct from
the failed activation/semantic outcomes above. T306 and DRIFT-008 remain open; no failed outcome is
waived by this record. Mechanical validation remains 13 blocking checks passed, one non-blocking
external-link warning. Governance validation passes with the existing 20 soft history warnings.
