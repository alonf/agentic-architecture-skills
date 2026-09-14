# Frontmatter hook evidence — 2026-09-12

**Outcome**: PASS with advisory fallback  
**Host**: Windows 11, PowerShell 7.5.3; static package harness  
**Scope**: T207, active-skill firing and inactive-skill non-firing  
**Fallback**: The repository does not contain a standalone host hook runner. Host
activation evidence therefore uses the existing dated Claude Code and Copilot
CLI trigger harness transcripts; the local check verifies the shipped
frontmatter contract mechanically and does not claim stronger host enforcement.

## Mechanical frontmatter check

Command:

```powershell
pwsh -File ./eng/Test-Skills.ps1
```

Result: PASS. Both shipped `SKILL.md` files parsed successfully. The router's
`when_to_use` and `DO NOT USE FOR` corpus fired in the positive/negative trigger
corpus; the inactive cases did not produce a router terminal line in the
recorded transcripts. `disallowed-tools` was present only on the router and
was parsed as `Write`, `Edit`, and `NotebookEdit`.

## Existing host evidence

| Host | Active-skill firing | Inactive-skill non-firing | Enforcement outcome |
| --- | --- | --- | --- |
| Claude Code 2.1.268 | Observed in the valid SC-003/SC-004 repetitions; invalid no-activation repetitions were excluded | Negative corpus and no-activation repetitions recorded in `2026-09-11-behavioural-claude.md` | Advisory: `disallowed-tools` failed 2/4 valid SC-004 repetitions |
| GitHub Copilot CLI 1.0.83 | Observed in the corpus; competing-skill activation also occurred | Five SC-003 writes opened directly through `microsoft-foundry`, with no router activation; this is non-activation, not a router hook firing | Advisory under elevated permissions; default-permission container run refused writes via host gate |

The result is dated, names both hosts, records active and inactive observations,
and preserves the fallback: consumers needing a hard stop must add a host-level
approval/tool-permission gate rather than relying on skill frontmatter.
