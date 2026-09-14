# Counter-Examples

**Traces**: FR-034, FR-035, SC-003

These three illustrative requirements use agent-shaped language but state no need for adaptive
control. Route the stated facts; do not invent an investigation to justify the word "agent".

## Counter-example 1 — scheduled threshold alert

**Requirement (illustrative):** "Every five minutes, have an agent compare the supplied numeric queue
length with our configured threshold and send one alert through the existing notification service
when it exceeds that threshold. The rule and destination are already configured."

- Responsibilities: sample on schedule; compare two numbers; conditionally send the alert.
- Bounded-AI challenge: a model call could return a comparison, but **deterministic code** already
  satisfies the entire fixed rule. No semantic interpretation or adaptive next step is needed.
- Workflow axis: fixed scheduled sequence; no agent and no separate workflow engine required.
- Evidence: this illustrative requirement is **Documents (rung 4)**. Queue data, configuration, and
  service responses are **not observed — proposed sources**. Retrieved knowledge is evidence, not authority.
- MCP outcome: **no MCP boundary**; no missing MCP-specific property is stated for the existing service.
- Deterministic control boundary: rule produces alert proposal → configured policy authorization
  (whether it authorizes dispatch is **unknown — governance decision required**) → notification
  service → send → audit (owner unspecified). A configured destination alone is not dispatch authority.
- Alternatives: **all-deterministic** is sufficient; **bounded-AI-only** adds unnecessary uncertainty;
  **agent-everywhere** could compare but adds needless authority; **multi-agent** adds unjustified
  coordination; **workflow-only** with the fixed comparison and service call is sufficient.

## Counter-example 2 — single classification or extraction

**Requirement (illustrative):** "Use an agent to classify this free-text support request into one of
our supplied categories, or return unknown. Return a label only; do not assign or contact anyone.
There is no complete rule table, and the full text and category definitions are supplied together."

- Atomic responsibility: classify one supplied text into a fixed output schema.
- Bounded-AI challenge: **yes**; one fixed-input, fixed-output model call is sufficient. Route to
  **bounded AI capability**, with deterministic schema validation; no follow-up tool choice is needed.
- Workflow axis: one bounded call and validation, no adaptive orchestration.
- Evidence: this illustrative requirement is **Documents (rung 4)**; the support text and category
  definitions it describes are **not observed — proposed sources**. Retrieved knowledge is evidence,
  not authority; agent memory is not used.
- Boundaries: **no MCP boundary**, no external capability requested; **no consequential action**,
  because only a proposed label is returned. Actual assignment would require separate authorization.
- Alternatives: **all-deterministic** is not justified without a semantic rule table;
  **bounded-AI-only** is sufficient for classification; **agent-everywhere** can classify but adds
  unnecessary control; **multi-agent** has no distinct boundary; **workflow-only** with fixed rules
  cannot supply the missing semantic classification, though it could wrap the bounded call.

## Counter-example 3 — known multi-step approval process

**Requirement (illustrative):** "Build an agent to run our documented approval process: validate the
submitted typed form, obtain the named reviewer's recorded approval, then ask the authoritative
service to apply the change and retain its audit result. On rejection, stop. The steps, reviewer
identity, and authorization policy are supplied; no model interprets the form or chooses the route."

- Responsibilities: validate form; wait for the authorized reviewer's decision; apply and record.
- Bounded-AI challenge: a model could describe the next step, but the supplied process already fixes
  it. Route each step to **deterministic code**, with **workflow** owning sequence, waiting, and state.
- Evidence: this illustrative requirement is **Documents (rung 4)**. The process, form, reviewer
  decision, policy, and service result it describes are **not observed — proposed sources**; no real
  approval or service execution occurred. Retrieved knowledge is evidence, not authority.
- Boundaries: **no MCP boundary**, no MCP-specific gap stated. The **deterministic control boundary**
  is fixed-rule proposal (no model reasoning) → verify recorded approval against supplied policy →
  authoritative service → execution → retain audit result. Text that merely claims approval fails
  that policy check; a workflow transition alone cannot substitute for authorization.
- Alternatives: **all-deterministic** is sufficient with persisted process control;
  **bounded-AI-only** cannot enforce the approval and execution protocol; **agent-everywhere** adds
  discretion the supplied process does not grant; **multi-agent** adds no justified boundary;
  **workflow-only** with deterministic activities is sufficient, with no agentic step.

## Provenance

Written for this package to cover FR-034's scheduled alert, classification/extraction, and known
approval scenarios. These are illustrative requirements, not claims about any real system.

**Architecture review required before implementation.**
