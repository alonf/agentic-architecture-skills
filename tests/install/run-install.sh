#!/usr/bin/env bash
# Runs inside the clean container built from the Dockerfile beside this file. Installs the package on
# each host exactly as the README documents, times it, and checks that both skills are present
# afterwards. Prints one RESULT line per path for eng/Test-Install.ps1 to record.
#
# Blocking (SC-001: under a minute per host, both skills listed): Claude Code, GitHub Copilot CLI.
# Advisory (recorded, never fails the run): the `npx skills add` form, a third-party installer whose
# interactive defaults are bypassed here with --all, so its number is indicative rather than the claim.
#
# Also answers the carried-forward packaging question "does Copilot CLI accept a whole-repository plugin
# as Claude Code does" by installing the repository directly (owner/repo) into a second clean home.

set -u

SOURCE="${PACKAGE_SOURCE:-alonf/agentic-architecture-skills}"
PLUGIN="${PLUGIN_NAME:-agentic-architecture}"
MARKETPLACE="${MARKETPLACE_NAME:-agentic-architecture-skills}"
LIMIT_MS=60000
SKILLS=(agentic-architecture-router maf-architecture-mapping)

# A private repository needs a token for git. It arrives at run time and lives only in this container.
if [ -n "${GH_TOKEN:-}" ]; then
  git config --global url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
  export GITHUB_TOKEN="${GH_TOKEN}"
fi

now_ms() { date +%s%3N; }
failures=0

# skills_found <dir> : counts how many of the expected SKILL.md files exist under <dir>
skills_found() {
  local dir="$1" n=0 s
  for s in "${SKILLS[@]}"; do
    if find "$dir" -path "*/skills/${s}/SKILL.md" -print -quit 2>/dev/null | grep -q .; then n=$((n + 1)); fi
  done
  echo "$n"
}

# report <path> <blocking:yes|no> <rc> <elapsed_ms> <skills_found>
# Every RESULT field value is free of whitespace, so the line parses as plain key=value pairs on the
# other side; the failure reason is its own field rather than prose inside the status.
report() {
  local path="$1" blocking="$2" rc="$3" ms="$4" found="$5" status="pass" reason="-"
  if [ "$rc" -ne 0 ]; then status="fail"; reason="exit-code-${rc}"; fi
  if [ "$found" -ne "${#SKILLS[@]}" ]; then status="fail"; reason="skills-${found}-of-${#SKILLS[@]}"; fi
  if [ "$ms" -gt "$LIMIT_MS" ]; then status="fail"; reason="over-limit-${ms}ms-gt-${LIMIT_MS}ms"; fi
  if [ "$status" != "pass" ] && [ "$blocking" = "yes" ]; then failures=$((failures + 1)); fi
  echo "RESULT path=${path} blocking=${blocking} status=${status} reason=${reason} elapsed_ms=${ms} skills=${found}/${#SKILLS[@]}"
}

section() { echo; echo "=== $1"; }

section "environment"
echo "node $(node --version) | claude $(claude --version 2>&1 | head -1) | copilot $(copilot --version 2>&1 | head -1) | skills $(skills --version 2>&1 | head -1)"
echo "source ${SOURCE} | plugin ${PLUGIN}@${MARKETPLACE} | HOME ${HOME} (fresh)"

# --- Claude Code: the README's marketplace form ---------------------------------------------------
section "claude-code: /plugin marketplace add + /plugin install"
start=$(now_ms)
claude plugin marketplace add "$SOURCE" && claude plugin install --yes "${PLUGIN}@${MARKETPLACE}"
rc=$?
ms=$(( $(now_ms) - start ))
claude plugin list 2>&1 | sed 's/^/  list: /'
claude plugin details "${PLUGIN}@${MARKETPLACE}" 2>&1 | sed 's/^/  details: /'
report claude-code yes "$rc" "$ms" "$(skills_found "$HOME/.claude")"

# --- Copilot CLI: the README's marketplace form ---------------------------------------------------
section "copilot-cli: plugin marketplace add + plugin install"
start=$(now_ms)
copilot plugin marketplace add "$SOURCE" && copilot plugin install "${PLUGIN}@${MARKETPLACE}"
rc=$?
ms=$(( $(now_ms) - start ))
copilot plugin list 2>&1 | sed 's/^/  list: /'
report copilot-cli yes "$rc" "$ms" "$(skills_found "$HOME/.copilot")"

# --- Copilot CLI: whole repository as a plugin, no marketplace (carried-forward verification) -----
section "copilot-cli-direct: plugin install owner/repo into a second clean home"
DIRECT_HOME="$HOME/direct-home"; mkdir -p "$DIRECT_HOME"
# The token lives in the first home's git config; the second home must see the same credential, or a
# private repository fails for a reason that has nothing to do with the host.
[ -f "$HOME/.gitconfig" ] && cp "$HOME/.gitconfig" "$DIRECT_HOME/.gitconfig"
start=$(now_ms)
HOME="$DIRECT_HOME" copilot plugin install "$SOURCE"
rc=$?
ms=$(( $(now_ms) - start ))
HOME="$DIRECT_HOME" copilot plugin list 2>&1 | sed 's/^/  list: /'
report copilot-cli-direct no "$rc" "$ms" "$(skills_found "$DIRECT_HOME/.copilot")"

# --- skills CLI: the README's first form, non-interactive -------------------------------------------
# Its own clean home: by now the first home holds both SKILL.md files from the Claude and Copilot
# installs, and a presence check over that tree would pass even if this installer did nothing.
section "skills-cli: npx skills add (--all, global) into a third clean home"
SKILLS_HOME="$HOME/skills-home"; mkdir -p "$SKILLS_HOME"
[ -f "$HOME/.gitconfig" ] && cp "$HOME/.gitconfig" "$SKILLS_HOME/.gitconfig"
start=$(now_ms)
HOME="$SKILLS_HOME" skills add "$SOURCE" --all -g
rc=$?
ms=$(( $(now_ms) - start ))
HOME="$SKILLS_HOME" skills list -g 2>&1 | sed 's/^/  list: /'
report skills-cli no "$rc" "$ms" "$(skills_found "$SKILLS_HOME")"

section "summary"
if [ "$failures" -eq 0 ]; then echo "install verification: PASS (blocking paths all under ${LIMIT_MS}ms with ${#SKILLS[@]}/${#SKILLS[@]} skills)"; else echo "install verification: FAIL (${failures} blocking path(s))"; fi
exit "$failures"
