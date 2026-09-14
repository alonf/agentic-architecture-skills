# Assurance

**Traces**: FR-018

The demo material's evaluation beat (H08 slide 49) is deliberately kept out of `construct-map.md`: it
is not a mechanism a requirement gets routed to, it is how any of the twelve routed mechanisms gets
checked once built. Four concerns, each answering a different question about a running agentic system.

## Observe

**Question**: what actually happened during a run, in enough detail to judge it later?

An agent's own summary of what it did is not observability — the execution evidence has to exist
independently of the agent's narration (tool calls made, arguments passed, intermediate results,
approvals requested and their outcome). Without this, "evaluate" below has nothing to check against
except the agent's self-report, which is exactly the thing under evaluation.

## Evaluate

**Question**: did the run satisfy the requirement it was built for — not "did it look reasonable", but
"did it do the specific thing the requirement asked for"?

This is requirement-derived, not generic: a fraud-scoring responsibility and a knowledge-base
responsibility are evaluated against different pass criteria, because they were routed for different
reasons. Evaluation reads the observed execution evidence from above; it does not re-run the agent and
grade the new run's prose output, and it does not substitute a transcript re-read for evidence that was
never captured in the first place.

## Verify behaviour

**Question**: does the *routing decision itself* still hold once real behaviour is observed, or did the
implementation quietly cross a line the architecture review drew?

Two directions matter here, and both are failures even though only one looks like one:

- A responsibility routed to bounded AI that, in practice, needs to decide what to check next has
  drifted into agent territory without a routing decision saying so.
- A responsibility routed to an agent that, in practice, never varies its next step has more autonomy
  than the requirement justified, and should be re-routed down, not left as-is because it "still works".

## Regress

**Question**: does a later change silently change what an earlier verified run already established?

A behavioural check that is not re-run after a change is not a regression check, it is a historical
record. This concern exists specifically so that the router's own bounded-AI challenge and the
mapping's construct choices stay tied to evidence that is re-checked, not evidence that was true once
and is now merely assumed still true.

## What this file does not cover

It does not define a specific test framework, harness name, or CI pipeline — those are implementation
choices for whoever builds the agent, made after this skill's mapping step, not before it. Naming a
concrete harness here would also be a dated platform fact, which belongs in `maf-surface.md` if it
belongs anywhere.
