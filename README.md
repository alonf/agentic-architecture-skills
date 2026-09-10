# Agentic Architecture Skills

Two Agent Skills that decide **what kind of computation a requirement actually needs** — deterministic
code, one bounded AI operation, a single agent, or several — and then map an approved decision onto
Microsoft Agent Framework constructs in .NET.

The point is the refusal as much as the recommendation. Most skills can propose an agent; this one is
built to say no where deterministic code suffices, and to say why.

> **Status: iteration 001, installable skeleton.** The frontmatter, packaging and validation are real.
> The skill bodies are placeholders and land in iteration 002. Installing today proves the distribution
> path works; it does not yet give you the decision procedure.

## Enforcement is host-dependent — read this before installing

This package blocks implementation while the router is active, but **how** that block is enforced
differs by host. `disallowed-tools` removes the file-mutation tools from the pool where the host honours
it, and degrades to instruction where it does not.

| Host | Mechanism | Enforcement | Verified |
| --- | --- | --- | --- |
| Claude Code | `disallowed-tools` | mechanical | *pending — iteration 001, T014* |
| Copilot CLI | `disallowed-tools` | *pending measurement* | *pending — iteration 001, T014* |
| skills CLI | inherits the host it installs into | varies | — |
| Microsoft Foundry | not supported at 1.0 | advisory | — |

"Mechanical" means the tools are removed and a write cannot occur. "Advisory" means the skill instructs
and the model may comply. This table reports what was measured, not what was hoped, and the dates are
filled in when the measurement happens.

## Install

```bash
npx skills add alonf/agentic-architecture-skills
npx skills add alonf/agentic-architecture-skills --skill agentic-architecture-router
```

```text
/plugin marketplace add alonf/agentic-architecture-skills
/plugin install agentic-architecture@agentic-architecture-skills
```

The second form works on both Claude Code and GitHub Copilot CLI.

**Pinning.** An unpinned install tracks the default branch, so the content that shapes your architecture
decisions can change under you. Releases are tagged; install from a tag when you want a fixed version.
The per-channel syntax is documented once it has been verified rather than asserted in advance.

## The two skills

| Skill | What it does | Loads when |
| --- | --- | --- |
| `agentic-architecture-router` | Decomposes a requirement into responsibilities and routes each to the least autonomous mechanism that satisfies it. Host- and vendor-neutral | A requirement may involve AI, agents, MCP or workflow — or a coding agent is about to introduce one |
| `maf-architecture-mapping` | Maps an approved mechanism decision to Agent Framework constructs, hosting, governance and assurance choices | After the router's decision is approved, or when asked how to realise a design in Agent Framework and C# |

The router names no products and writes no code. The mapping skill asserts no API signatures from
memory: every version, signature and availability claim lives in one dated reference file, and the skill
instructs the agent to confirm against live documentation before generating code.

## Validating the package

One command defines validity, and a reviewer should need no other:

```powershell
pwsh -File ./eng/Test-Skills.ps1
```

CI invokes exactly that and adds nothing of its own, so what fails in CI fails identically on your
machine.

## Development tooling

The published package has **zero dependencies** — nothing is installed by consuming it. CI uses one
external tool, pinned to an exact version: **markdownlint-cli 0.49.1**, run against the package's own
`.markdownlint.json`. That is the complete list; if it grows, this section grows with it. Install the
same version locally to make the lint check block on your machine as it does in CI:

```powershell
npm install --global markdownlint-cli@0.49.1
```

## Licence

MIT — see [LICENSE](LICENSE).
