#!/usr/bin/env bash
# Prints one SHA-256 over the content of the named skill directories under <skills-root>, so an
# installed copy can be compared with the tree it was supposed to come from without trusting either
# side's git metadata. eng/Get-SkillsTreeDigest.ps1 is the same definition in PowerShell; the two are
# proven equal by eng/Test-Checks.ps1 and MUST change together.
#
# Definition: for every regular file under each named skill directory, excluding dotfiles, take its
# path relative to <skills-root> (forward slashes) and the SHA-256 of its bytes with every CR removed;
# sort the paths bytewise; hash the text "<path>\n<sha256>\n" for each in that order.
# CRs are removed because a host may rewrite line endings when it copies a skill, and a line-ending
# change is not a content change for these Markdown files.
#
# Usage: digest-skills.sh <skills-root> <skill-dir>... ; prints "unknown" when a named skill is absent.

set -u

root="${1:?skills root required}"; shift
[ "$#" -gt 0 ] || { echo "at least one skill directory name is required" >&2; exit 2; }
for skill in "$@"; do
  [ -d "${root}/${skill}" ] || { echo unknown; exit 0; }
done

cd "$root" || { echo unknown; exit 0; }
find "$@" -type f ! -name '.*' | LC_ALL=C sort | while IFS= read -r file; do
  printf '%s\n%s\n' "$file" "$(tr -d '\r' < "$file" | sha256sum | cut -d' ' -f1)"
done | sha256sum | cut -d' ' -f1
