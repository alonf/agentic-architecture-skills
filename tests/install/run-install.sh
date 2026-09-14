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

# skills_found <dir> : counts how many of the expected SKILL.md files exist under <dir>. Callers pass the
# host's INSTALLED location, never its home: both hosts also keep a clone of the marketplace under the
# same home, and that clone contains the skills whether or not the install produced any.
skills_found() {
  local dir="$1" n=0 s
  [ -d "$dir" ] || { echo 0; return; }
  for s in "${SKILLS[@]}"; do
    if find "$dir" -path "*/skills/${s}/SKILL.md" -print -quit 2>/dev/null | grep -q .; then n=$((n + 1)); fi
  done
  echo "$n"
}

# inventory_lists <text> : counts how many expected skill names the host's OWN inventory output names.
# The host discovering the skill is T014's acceptance condition; a file on disk is only a proxy for it.
inventory_lists() {
  local text="$1" n=0 s
  for s in "${SKILLS[@]}"; do
    if printf '%s' "$text" | grep -q -- "$s"; then n=$((n + 1)); fi
  done
  echo "$n"
}

# copilot_inventory <install output> <list output> : Copilot names the plugin, not the skills, in its
# list. Its install message states the count ("Installed N skills"); that count is the inventory when
# the plugin is listed, and 0 otherwise.
copilot_inventory() {
  local install_out="$1" list_out="$2" n
  # Listed as 'name@marketplace' after a marketplace install and as bare 'name' after a direct one.
  printf '%s' "$list_out" | grep -q -E -- "(^|[[:space:]])${PLUGIN}(@|[[:space:]]|\$)" || { echo 0; return; }
  n=$(printf '%s' "$install_out" | grep -o -E 'Installed [0-9]+ skills' | grep -o -E '[0-9]+' | head -1)
  echo "${n:-0}"
}

# installed_revision <home-subtree> : HEAD of the host's own clone of SOURCE under that subtree, or
# "unknown" when the host kept no git metadata. The clone is what the host installed from, so its HEAD
# is the revision the install actually delivered - which is not necessarily the revision the caller
# checked out, and the driver compares the two.
installed_revision() {
  local root="$1" gitdir repo
  [ -d "$root" ] || { echo unknown; return; }
  while IFS= read -r gitdir; do
    repo="$(dirname "$gitdir")"
    if git -C "$repo" remote get-url origin 2>/dev/null | grep -q -i -F -- "$SOURCE"; then
      git -C "$repo" rev-parse HEAD 2>/dev/null || echo unknown
      return
    fi
  done < <(find "$root" -type d -name .git 2>/dev/null)
  echo unknown
}

# installed_digest <install location> : content digest of the installed skill directories, computed by
# digest-skills.sh on the directory that holds them; "unknown" when they are not all present. This is
# the binding that survives a host copying files without their git history.
installed_digest() {
  local dir="$1" first
  first="$(find "$dir" -path "*/skills/${SKILLS[0]}/SKILL.md" -print -quit 2>/dev/null)"
  [ -n "$first" ] || { echo unknown; return; }
  bash /usr/local/bin/digest-skills.sh "$(dirname "$(dirname "$first")")" "${SKILLS[@]}"
}

# report <path> <blocking:yes|no> <rc> <elapsed_ms> <install location> <inventory_rc> <inventory_count> <revision>
# Every RESULT field value is free of whitespace, so the line parses as plain key=value pairs on the
# other side; the failure reason is its own field rather than prose inside the status. Revision and
# digest are recorded here and judged by the driver, which alone knows what was expected.
report() {
  local path="$1" blocking="$2" rc="$3" ms="$4" location="$5" inv_rc="$6" inv="$7" revision="$8" status="pass" reason="-"
  local found digest
  found="$(skills_found "$location")"
  digest="$(installed_digest "$location")"
  # The FIRST failure is the reason recorded; later ones are usually its consequences.
  fail() { status="fail"; [ "$reason" = "-" ] && reason="$1"; }
  [ "$rc" -eq 0 ]                     || fail "exit-code-${rc}"
  [ "$found" -eq "${#SKILLS[@]}" ]    || fail "skills-on-disk-${found}-of-${#SKILLS[@]}"
  [ "$inv_rc" -eq 0 ]                 || fail "inventory-exit-code-${inv_rc}"
  [ "$inv" -eq "${#SKILLS[@]}" ]      || fail "inventory-lists-${inv}-of-${#SKILLS[@]}"
  [ "$ms" -le "$LIMIT_MS" ]           || fail "over-limit-${ms}ms-gt-${LIMIT_MS}ms"
  if [ "$status" != "pass" ] && [ "$blocking" = "yes" ]; then failures=$((failures + 1)); fi
  echo "RESULT path=${path} blocking=${blocking} status=${status} reason=${reason} elapsed_ms=${ms} skills=${found}/${#SKILLS[@]} inventory=${inv}/${#SKILLS[@]} revision=${revision} digest=${digest}"
}

section() { echo; echo "=== $1"; }

section "environment"
echo "node $(node --version) | claude $(claude --version 2>&1 | head -1) | copilot $(copilot --version 2>&1 | head -1) | skills $(skills --version 2>&1 | head -1)"
echo "source ${SOURCE} | plugin ${PLUGIN}@${MARKETPLACE} | HOME ${HOME} (fresh) | expected revision ${EXPECTED_REVISION:-not-given}"

# --- Claude Code: the README's marketplace form ---------------------------------------------------
section "claude-code: /plugin marketplace add + /plugin install"
start=$(now_ms)
claude plugin marketplace add "$SOURCE" && claude plugin install --yes "${PLUGIN}@${MARKETPLACE}"
rc=$?
ms=$(( $(now_ms) - start ))
claude plugin list 2>&1 | sed 's/^/  list: /'
# The host's own component inventory ("Skills (2)  a, b") is the evidence; its exit code counts too.
details=$(claude plugin details "${PLUGIN}@${MARKETPLACE}" 2>&1); details_rc=$?
printf '%s\n' "$details" | sed 's/^/  details: /'
skills_line=$(printf '%s' "$details" | grep -i 'Skills (')
report claude-code yes "$rc" "$ms" "$HOME/.claude/plugins/cache" "$details_rc" "$(inventory_lists "$skills_line")" "$(installed_revision "$HOME/.claude")"

# --- Copilot CLI: the README's marketplace form ---------------------------------------------------
section "copilot-cli: plugin marketplace add + plugin install"
start=$(now_ms)
install_out=$(copilot plugin marketplace add "$SOURCE" 2>&1 && copilot plugin install "${PLUGIN}@${MARKETPLACE}" 2>&1)
rc=$?
ms=$(( $(now_ms) - start ))
printf '%s\n' "$install_out"
# Copilot's inventory is its install message ("Installed N skills") plus the plugin appearing in list;
# the on-disk check is restricted to installed-plugins/, not the marketplace cache beside it.
list_out=$(copilot plugin list 2>&1); list_rc=$?
printf '%s\n' "$list_out" | sed 's/^/  list: /'
report copilot-cli yes "$rc" "$ms" "$HOME/.copilot/installed-plugins" "$list_rc" "$(copilot_inventory "$install_out" "$list_out")" "$(installed_revision "$HOME/.copilot")"

# --- Copilot CLI: whole repository as a plugin, no marketplace (carried-forward verification) -----
section "copilot-cli-direct: plugin install owner/repo into a second clean home"
DIRECT_HOME="$HOME/direct-home"; mkdir -p "$DIRECT_HOME"
# The token lives in the first home's git config; the second home must see the same credential, or a
# private repository fails for a reason that has nothing to do with the host.
[ -f "$HOME/.gitconfig" ] && cp "$HOME/.gitconfig" "$DIRECT_HOME/.gitconfig"
start=$(now_ms)
install_out=$(HOME="$DIRECT_HOME" copilot plugin install "$SOURCE" 2>&1)
rc=$?
ms=$(( $(now_ms) - start ))
printf '%s\n' "$install_out"
list_out=$(HOME="$DIRECT_HOME" copilot plugin list 2>&1); list_rc=$?
printf '%s\n' "$list_out" | sed 's/^/  list: /'
report copilot-cli-direct no "$rc" "$ms" "$DIRECT_HOME/.copilot/installed-plugins" "$list_rc" "$(copilot_inventory "$install_out" "$list_out")" "$(installed_revision "$DIRECT_HOME/.copilot")"

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
list_out=$(HOME="$SKILLS_HOME" skills list -g 2>&1); list_rc=$?
printf '%s\n' "$list_out" | sed 's/^/  list: /'
report skills-cli no "$rc" "$ms" "$SKILLS_HOME/.agents/skills" "$list_rc" "$(inventory_lists "$list_out")" "$(installed_revision "$SKILLS_HOME/.agents")"

section "summary"
if [ "$failures" -eq 0 ]; then echo "install verification: PASS (blocking paths all under ${LIMIT_MS}ms with ${#SKILLS[@]}/${#SKILLS[@]} skills)"; else echo "install verification: FAIL (${failures} blocking path(s))"; fi
exit "$failures"
