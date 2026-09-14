# Changelog

All notable changes to this package are recorded here. Releases are cut from a
matching `vMAJOR.MINOR.PATCH` tag.

## [1.0.0] - 2026-09-12

### Added

- A router skill that selects the least-autonomous mechanism for a requirement.
- A mapping skill that maps an approved decision to Microsoft Agent Framework
  constructs.
- Dated references, worked examples, counter-examples, golden fixtures, trigger
  corpora, install verification, and host enforcement evidence.
- Export-parity validation and a tag-driven release workflow.

### Verification

- `eng/Test-Skills.ps1` is the package validity command.
- `eng/Export-Package.ps1` verifies that an exported tree contains exactly the
  committed package scope.
- `eng/Test-Install.ps1` binds each install record to the revision it verifies:
  every path reports the revision the host cloned and a content digest of the
  installed skills, and a blocking path fails when either differs from the
  tree the run started from (`-ExpectedRevision`; CI passes the triggering
  commit).
- Host enforcement remains explicitly advisory where the measurements show that
  `disallowed-tools` is not reliable; see `tests/results/`.
