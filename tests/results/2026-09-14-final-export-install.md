# Install verification - 2026-09-14

**Outcome**: PASS
**Recorded**: 2026-09-14 06:30:44Z
**Source**: `alonf/agentic-architecture-skills` (installed from GitHub, as the README documents)
**Expected revision**: `d05168405f06d276057fe1658c277455f449c063` (given by the caller)
**Expected content digest**: `58b9df1ca12d5a494ede3a29481eec6ca43c1445524440239089c5238e5a693f` (skills/ under the tree this run was started from; see tests/install/digest-skills.sh)
**Machine**: clean container, linux/x86_64 engine 29.4.0, base image `node:22.23.2-bookworm-slim`, fresh non-root user
**Hosts**: Claude Code 2.1.267, GitHub Copilot CLI 1.0.83, skills CLI 1.5.25
**Limit**: 60 s per host (SC-001); both skills on disk in the install location AND named by the host's own inventory
**Binding**: a blocking path passes only when its installed content digest equals the expected digest and any revision the host exposed equals the expected revision

| Path | Blocking | Status | Reason | Install time | Skills on disk | Host inventory | Installed revision | Installed digest |
| ---- | -------- | ------ | ------ | ------------ | -------------- | -------------- | ------------------ | ---------------- |
| claude-code | yes | pass | - | 10.4 s | 2/2 | 2/2 | d051684 | 58b9df1ca12d |
| copilot-cli | yes | pass | - | 3.6 s | 2/2 | 2/2 | d051684 | 58b9df1ca12d |
| copilot-cli-direct | no | pass | - | 6.1 s | 2/2 | 2/2 | d051684 | 58b9df1ca12d |
| skills-cli | no | pass | - | 8.1 s | 2/2 | 2/2 | unknown | 58b9df1ca12d |

## Log

```text

=== environment
node v22.23.2 | claude 2.1.267 (Claude Code) | copilot GitHub Copilot CLI 1.0.83. | skills 1.5.25
source alonf/agentic-architecture-skills | plugin agentic-architecture@agentic-architecture-skills | HOME /home/tester (fresh) | expected revision d05168405f06d276057fe1658c277455f449c063

=== claude-code: /plugin marketplace add + /plugin install
Adding marketplace…SSH not configured, cloning via HTTPS: https://github.com/alonf/agentic-architecture-skills.git
Refreshing marketplace cache (timeout: 120s)…
Cloning repository (timeout: 120s): https://github.com/alonf/agentic-architecture-skills.git
Clone complete, validating marketplace…
Cleaning up old marketplace cache…
✔ Successfully added marketplace: agentic-architecture-skills (declared in user settings)
Installing plugin "agentic-architecture@agentic-architecture-skills"...✔ Successfully installed plugin: agentic-architecture@agentic-architecture-skills (scope: user)
  list: Installed plugins:
  list:
  list:   ❯ agentic-architecture@agentic-architecture-skills
  list:     Version: 1.0.0
  list:     Scope: user
  list:     Status: ✔ enabled
  list:
  details: agentic-architecture 1.0.0
  details:   Description: Two skills: agentic-architecture-router and maf-architecture-mapping.
  details:   Source: agentic-architecture@agentic-architecture-skills
  details:
  details: Component inventory
  details:   Skills (2)  agentic-architecture-router, maf-architecture-mapping
  details:   Agents (0)
  details:   Hooks (0)
  details:   MCP servers (0)
  details:   LSP servers (0)
  details:
  details: Projected token cost
  details:   Always-on:   ~600 tok   added to every session
  details:
  details: Per-component (rounded)
  details:   component                    always-on  on-invoke
  details:   agentic-architecture-router       ~290      ~1.5k
  details:   maf-architecture-mapping          ~310      ~1.3k
  details:
  details:   On-invoke cost is paid each time a skill or agent fires.
  details:   Token counts are estimates and may differ from actual usage.
RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=10404 skills=2/2 inventory=2/2 revision=d05168405f06d276057fe1658c277455f449c063 digest=58b9df1ca12d5a494ede3a29481eec6ca43c1445524440239089c5238e5a693f

=== copilot-cli: plugin marketplace add + plugin install
Marketplace "agentic-architecture-skills" added successfully.
Plugin "agentic-architecture" installed successfully. Installed 2 skills.
  list: Installed plugins:
  list:   • agentic-architecture@agentic-architecture-skills (v1.0.0)
RESULT path=copilot-cli blocking=yes status=pass reason=- elapsed_ms=3644 skills=2/2 inventory=2/2 revision=d05168405f06d276057fe1658c277455f449c063 digest=58b9df1ca12d5a494ede3a29481eec6ca43c1445524440239089c5238e5a693f

=== copilot-cli-direct: plugin install owner/repo into a second clean home
Plugin "agentic-architecture" installed successfully. Installed 2 skills.

Warning: Direct plugin installs (repos, URLs, local paths) are deprecated. Only plugin@marketplace installs will be supported in a future release.
  list: Installed plugins:
  list:   • agentic-architecture (v1.0.0)
RESULT path=copilot-cli-direct blocking=no status=pass reason=- elapsed_ms=6079 skills=2/2 inventory=2/2 revision=d05168405f06d276057fe1658c277455f449c063 digest=58b9df1ca12d5a494ede3a29481eec6ca43c1445524440239089c5238e5a693f

=== skills-cli: npx skills add (--all, global) into a third clean home

███████╗██╗  ██╗██╗██╗     ██╗     ███████╗
██╔════╝██║ ██╔╝██║██║     ██║     ██╔════╝
███████╗█████╔╝ ██║██║     ██║     ███████╗
╚════██║██╔═██╗ ██║██║     ██║     ╚════██║
███████║██║  ██╗██║███████╗███████╗███████║
╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝

┌   skills
│
│  Tip: use the --yes (-y) and --global (-g) flags to install without prompts.
│
◇  Source: https://github.com/alonf/agentic-architecture-skills.git
│
│
◇  Found 2 skills
│
●  Installing all 2 skills
│
●  Installing to all 79 agents

│
◇  Installation Summary ─────────────────────────────────────────────────────╮
│                                                                            │
│  ~/.agents/skills/agentic-architecture-router                              │
│    universal: Amp, Antigravity, Antigravity CLI, Cline, Codex +17 more     │
│    symlink → AiderDesk, AstrBot, Autohand Code CLI, Augment, IBM Bob +52   │
│  more                                                                      │
│                                                                            │
│  ~/.agents/skills/maf-architecture-mapping                                 │
│    universal: Amp, Antigravity, Antigravity CLI, Cline, Codex +17 more     │
│    symlink → AiderDesk, AstrBot, Autohand Code CLI, Augment, IBM Bob +52   │
│  more                                                                      │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────╯
│
◇  Security Risk Assessments ─────────────────────────────────────────────────╮
│                                                                             │
│                               Gen               Socket            Snyk      │
│  agentic-architecture-router  --                --                Low Risk  │
│  maf-architecture-mapping     Safe              --                Low Risk  │
│                                                                             │
│  Details: https://skills.sh/alonf/agentic-architecture-skills               │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────╯
│

│
◇  Installed 2 skills ────────────────────────────────────────────────────────╮
│                                                                             │
│  ✓ ~/.agents/skills/agentic-architecture-router                             │
│    universal: Amp, Antigravity, Antigravity CLI, Cline, Codex +17 more      │
│    symlinked: AiderDesk, AstrBot, Autohand Code CLI, Augment, IBM Bob +51   │
│  more                                                                       │
│  ✓ ~/.agents/skills/maf-architecture-mapping                                │
│    universal: Amp, Antigravity, Antigravity CLI, Cline, Codex +17 more      │
│    symlinked: AiderDesk, AstrBot, Autohand Code CLI, Augment, IBM Bob +51   │
│  more                                                                       │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────╯

│
■  Failed to install 4
│
│    ✗ agentic-architecture-router → Eve: Eve does not support global skill installation
│
│    ✗ agentic-architecture-router → PromptScript: PromptScript does not support global skill installation
│
│    ✗ maf-architecture-mapping → Eve: Eve does not support global skill installation
│
│    ✗ maf-architecture-mapping → PromptScript: PromptScript does not support global skill installation

│
└  Done!  Review skills before use; they run with full agent permissions.

  list: Global Skills
  list:
  list: agentic-architecture-router ~/.agents/skills/agentic-architecture-router
  list:   Agents: AiderDesk, AstrBot, Autohand Code CLI, Augment, IBM Bob +51 more  Source: alonf/agentic-architecture-skills
  list: maf-architecture-mapping    ~/.agents/skills/maf-architecture-mapping
  list:   Agents: AiderDesk, AstrBot, Autohand Code CLI, Augment, IBM Bob +51 more  Source: alonf/agentic-architecture-skills
RESULT path=skills-cli blocking=no status=pass reason=- elapsed_ms=8102 skills=2/2 inventory=2/2 revision=unknown digest=58b9df1ca12d5a494ede3a29481eec6ca43c1445524440239089c5238e5a693f

=== summary
install verification: PASS (blocking paths all under 60000ms with 2/2 skills)
```
