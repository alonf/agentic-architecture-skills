<!-- mode: decision-card -->
<!-- Hand-authored illustrative fixture, not captured host output. T303 proves five alternative
verdicts and all five authority stages as well as the card's line and field counts. -->

# Decision Card

Mode: Decision Card (illustrative scheduled-threshold requirement)
Requirement: Every five minutes compare the supplied numeric queue length with a configured threshold; alert the configured destination through the existing notification service if exceeded.
Known facts: Repository: none supplied; requirement: fixed schedule, numeric comparison, threshold, destination, and existing service.
Unknown / assumptions: Dispatch authorization and audit owner are unspecified; no assumptions are added.
Routed mechanism: Deterministic sampling, comparison, and conditional dispatch; bounded-AI challenge: unnecessary, fixed rules suffice; workflow axis: fixed scheduled sequence.
Agent boundary: No agent or additional agent boundary; no MCP boundary because no missing MCP-specific property is stated for the existing service.
Evidence classification: Illustrative requirement text is Documents (rung 4); queue data, configured rule, destination, and service responses are not observed — proposed sources; retrieved knowledge is evidence, not authority; no agent memory used.
Authority chain: Deterministic control boundary: reasoning: fixed-rule alert proposal → authorization: unknown — governance decision required, dispatch held until resolved → authoritative service: existing notification service → execution: send only after authorization → audit: record outcome, owner unknown.
Rejected alternatives: all-deterministic: sufficient, fixed rules cover every step; bounded-AI-only: unnecessary, adds uncertainty to numeric comparison; agent-everywhere: could compare but adds unjustified discretion; multi-agent: unnecessary, no distinct agent boundary; workflow-only: sufficient with deterministic comparison and dispatch activities.
Decision and trade-off: Deterministic scheduled rule using the existing API; predictable and cheaper than adaptive control, but needs a policy change for new alert criteria; no product selection needed.

**Architecture review required before implementation.**
