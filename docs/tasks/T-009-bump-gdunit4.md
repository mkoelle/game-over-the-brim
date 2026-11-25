# T-009: Bump GdUnit4 6.2.0 → 6.2.3

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P3
**Status:** Done
**Estimate:** 1h
**Phase:** 1 — Maintenance ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-007](../adr/ADR-007-build-test-and-release-pipeline.md)
**Approval:** vendoring approved by the owner on 2026-11-24, at the latest release available at vendoring time ([plan](../plans/addon-adoption-plan.md#owner-decisions-2026-11-24)).

### Goal

Update the vendored GdUnit4 to the latest patch release, after reading
the release notes.

### Acceptance Criteria

- [x] The 6.2.1, 6.2.2 and 6.2.3 release notes have been read, and any
      breaking or CLI change is noted in the PR body.
- [x] `addons/gdUnit4/` is replaced with the v6.2.3 content, unmodified.
- [x] The ADR-007 version line and `CHANGELOG.md` are updated.
- [x] `task ci` is green. The zero-suite timeout guard in `ci.yml` still
      behaves as documented in ADR-007.

### Context

- Upstream moved to `godot-gdunit-labs/gdUnit4`. The latest is v6.2.3
  (2026-11-01, verified 2026-11-24).
- `test_vehicle_controller.gd` cites line numbers inside
  `addons/gdUnit4/src/core/GdUnitSceneRunnerImpl.gd`. Re-check that those
  comments are still accurate after the bump, and update or remove the
  line numbers.

### Files Likely Affected

- `addons/gdUnit4/` (vendored)
- `docs/adr/ADR-007-build-test-and-release-pipeline.md`
- `CHANGELOG.md`

### Implementation Plan

1. Branch `chore/bump-gdunit4-6.2.3`.
2. Read the notes:
   `gh release view v6.2.1 -R godot-gdunit-labs/gdUnit4`, then the same
   for v6.2.2 and v6.2.3.
3. Search for other version references:
   `grep -rn "6\.2\.0" .github Taskfile.yml docs`. Update each one found,
   for example a `gdUnit4-action` version input.
4. Replace `addons/gdUnit4/` with the release content.
5. `task import && task ci`.
6. Update the line-number references in the `test_vehicle_controller.gd`
   comments if they moved.

### Verification

`task ci` is green.

### Release notes review

No breaking or CLI changes in 6.2.1, 6.2.2 or 6.2.3. All entries are bug
fixes, with two behavior changes worth knowing:

- GD-1459 (6.2.3): the scene runner no longer delivers input events
  twice. Our vehicle tests pass unchanged.
- GD-1293 (6.2.1): opt-in ProjectSettings auto save/restore API. Opt-in,
  so no effect here.

The CLI invocation in `Taskfile.yml` and `ci.yml` is unchanged. The
vendor commit also drops one `.import` file (`logo.png.import`) and adds
an upstream `.gdignore`. Both come from the release layout.

The scene-runner line numbers in `test_vehicle_controller.gd` had
moved, so the comments now cite function names instead.

A throwaway failing test made `task test` exit 201 (GdUnit4 exit code
100), so the CI gate still works. The file was deleted before commit.

Note: the old vendored `plugin.cfg` said 6.2.1, although ADR-007 said
v6.2.0. It now says 6.2.3.

### Dependencies

None.
