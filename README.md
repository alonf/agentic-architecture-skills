# Agentic Architecture Skills

Two Agent Skills decide what kind of computation a requirement actually needs—
deterministic code, one bounded AI operation, a single agent, or several—and
then map an approved decision onto Microsoft Agent Framework constructs in .NET.
The package is intentionally willing to refuse an agent where deterministic code
is sufficient.

## Install matrix

| Host | Install | Scope |
| --- | --- | --- |
| Claude Code | `/plugin marketplace add alonf/agentic-architecture-skills`, then `/plugin install agentic-architecture@agentic-architecture-skills` | Marketplace plugin |
| GitHub Copilot CLI | The same marketplace/plugin commands | Marketplace plugin |
| skills CLI | `npx skills add alonf/agentic-architecture-skills` | Universal skills |

The 2026-09-10 clean-container run installed both skills on Claude Code
2.1.267, Copilot CLI 1.0.83, and skills CLI 1.5.25. Blocking paths completed
in under 60 seconds; the dated record is
`tests/results/2026-09-10-install-linux-container.md`.

An install record is bound to the revision it claims to verify. The hosts
clone the default branch and take no ref, so each recorded path names the
revision the host actually cloned (where it keeps git metadata) and a content
digest of the installed skills; a blocking path passes only when that digest
equals the digest of the tree the run started from and any exposed revision
equals the expected one (`eng/Test-Install.ps1 -ExpectedRevision`, which CI
sets to the triggering commit). A record without those columns predates the
binding and verified only that *some* default-branch content installed.

## Enforcement is host-dependent

`agentic-architecture-router` declares `disallowed-tools: [Write, Edit,
NotebookEdit]` while it is active. The declaration is a host-facing restriction,
not a universal safety boundary. The table reports the measured result rather
than a promise. SC-004 requires measured, per-host disclosure of this advisory
enforcement; the historical write failures below remain failures of the no-write
instruction and are not erased by that narrower acceptance contract:

| Host/configuration | Mechanism | Result | Evidence |
| --- | --- | --- | --- |
| Claude Code 2.1.268, default headless permissions | `disallowed-tools` | **Advisory; writes in 2/4 valid active-skill probes (50%)**: four same-prompt attempts plus one corroborating prompt; one non-activation excluded | [2026-09-11 measurement](tests/results/2026-09-11-behavioural-claude.md) |
| Copilot CLI 1.0.83, `--allow-all-tools --allow-all-paths` | `disallowed-tools` | **No writes in 3/3 corrected active-skill probes**. Separately, 5/9 counter-example probes wrote after competing-skill non-activation; one router hand-off produced no write. Advisory, not a universal guarantee | [2026-09-11 measurement](tests/results/2026-09-11-behavioural-copilot.md) |
| Copilot CLI 1.0.83, default permissions, marketplace install | Host write-permission gate | **No writes in either of two probes** (one corrected write-code prompt, one counter-example); tool permissions refused writes. This does not establish `disallowed-tools` enforcement; reference reads unverified | [2026-09-11 measurement](tests/results/2026-09-11-behavioural-copilot.md) |

If a host does not enforce the declaration, treat the skill output as advice
and add an independent approval or tool-permission boundary. The frontmatter
hook/activation evidence and its fallback are recorded in
`tests/results/2026-09-12-frontmatter-hooks.md`.

## The two skills

| Skill | What it does | Recommended use |
| --- | --- | --- |
| `agentic-architecture-router` | Decomposes a requirement and routes each responsibility to the least-autonomous mechanism | Use first when a requirement may involve AI, agents, MCP, or workflow |
| `maf-architecture-mapping` | Maps an approved mechanism to Agent Framework hosting, governance, and assurance choices | Use after the router decision is approved |

The router names no products and writes no code. The mapping skill keeps dated
version, signature, and availability claims in `references/maf-surface.md` and
asks the user to confirm live documentation before code generation. The mapping
skill is a recommendation after approval, not a prerequisite for the router.

### Measured cost and recall

Dated results, not aspirational targets. The 2026-09-13 router measurements record prompt-sensitive activation and incomplete semantic compliance. A focused correction improves observed-source classification; Copilot still produced compliant card shapes in only 1/3 unnamed requests, versus 3/3 requests explicitly naming the skill. Those are separate conditions, not a new recall percentage. See `tests/results/2026-09-13-evidence-correction.md` for remaining authorization and fact-grounding gaps. The recall rows below remain the historical 2026-09-11 corpus results:

| Measurement | Result | Source |
| --- | --- | --- |
| Context cost (always-on, both local skills; Claude Code 2.1.270) | ~807 tokens; per-skill and on-invoke host estimates in the dated record | `tests/results/2026-09-13-router-remeasurement.md` |
| Positive-trigger recall — Claude Code 2.1.267 | 13/15 = 86.7% (SC-002 target 90%, **below target**) | `tests/results/2026-09-11-behavioural-claude.md` |
| Positive-trigger recall — GitHub Copilot CLI 1.0.83 | 12/15 = 80% (SC-002 target 90%, **below target**) | `tests/results/2026-09-11-behavioural-copilot.md` |

Token counts are estimates reported by the host's own skill inventory, not
measured runtime usage; recall figures are observed pass/fail counts against
the dated 15-case trigger corpus for each host. Neither host currently meets
the 90% recall target — treat this as a known limitation until a corpus/prompt
revision closes the gap and is re-measured.

### Abridged worked example

For “investigate a failed nightly batch job and return a likely-cause report,”
intermediate findings determine which dependency logs to request next. The
complete evidence bundle cannot be supplied in advance, so one read-only
investigator is justified. Drafting the final report from collected evidence
is a bounded AI operation; returning it is deterministic delivery. No paging,
operational writes, second agent, or MCP boundary is justified by the requirement.
Access limits, run budget, and stopping policy remain unresolved. If a complete
fixed evidence bundle becomes available, reconsider a bounded call instead.
See the [full worked example](skills/agentic-architecture-router/references/worked-example.md).

## Pinning, provenance, and release scope

An unpinned install tracks the default branch. Use a release tag when the
decision procedure must be fixed. The package is MIT licensed and its source
provenance, dated platform surface, and behavioural records are linked from
the two skills’ `## Provenance` sections.

Version `1.0.0` is exactly the committed package scope: skills, manifests,
tests, validation scripts, and documentation. Lifecycle scaffolding and
workshop records are not exported. Releases are created from matching
`vMAJOR.MINOR.PATCH` tags; the workflow attaches one archive for each skill and
uses the matching section in `CHANGELOG.md`. Stretch work belongs in a later
minor release with its own evidence.

## Validating and exporting

The single package validity command is:

```powershell
pwsh -File ./eng/Test-Skills.ps1
```

The clean export/parity check is:

```powershell
pwsh -File ./eng/Export-Package.ps1 -ExportPath ../package-export
```

`-ExportPath` must be outside the package source tree (not the source itself, not an ancestor or
descendant of it, and not a filesystem root) — the script refuses those destinations before
changing the filesystem. Source and destination paths must also have no junction or symbolic-link
ancestors, including existing ancestors of a new destination; use direct filesystem paths for staging.
It copies only the published allowlist, compares every relative path and
SHA-256 hash with the build directory (including hidden payload paths such as `.claude-plugin` and
`.github`), and fails on missing or extra files.
Before the 1.0.0 tag, clone that exported tree into a fresh directory and run
the documented host installs; the committed install record demonstrates the
same clean-install contract.

## Development tooling

The published package has zero dependencies. Development tooling is pinned:

| Tool | Version | Used by |
| --- | --- | --- |
| markdownlint-cli | 0.49.1 | `eng/Test-Skills.ps1` and package Markdown |
| Docker | current engine | `eng/Test-Install.ps1` |
| Node | 22.23.2-bookworm-slim | clean install harness |
| Claude Code | 2.1.267 | clean install and behaviour harness |
| GitHub Copilot CLI | 1.0.83 | clean install and behaviour harness |
| skills CLI | 1.5.25 | clean install harness |

## Licence

MIT — see [LICENSE](LICENSE).

The 2026-09-14 UTC local-content remeasurement is recorded in
[combined results](tests/results/2026-09-14-combined-measurement.md). For 1.0.0, SC-003,
SC-005 and the FR-009 card-3 result are measured, per-host, disclosed results by maintainer
decision. The limitations below carry to feature 002 with the book alignment.

| Measured condition | Claude Code 2.1.270 | Copilot CLI 1.0.83 | 1.0.0 limitation |
| --- | --- | --- | --- |
| Mixed classification prompt: architecture analysis (SC-003) | 3/3 | 0/3 | Copilot activation miss; no architecture analysis returned |
| Decision Card shape (SC-005) | 3/3 | 2/3 | Copilot card 1 has ten fields, including duplicate Agent boundary |
| Decision Card authorization (FR-009) | 2/3 preserve unknown policy | 3/3 preserve unknown policy | Claude card 3 invents dispatch authorization |
| Existing API without MCP-specific need | 3/3 | 3/3 | Scoped mapping probes only |

These are scoped measurements, not new trigger-corpus recall or enforcement figures, and
do not erase earlier failures. The authorization invention grants no actual authority;
the authority-chain and card-shape targets remain unchanged in the skills.
