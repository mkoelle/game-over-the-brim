# T-009: Bump GdUnit4 6.2.0 → 6.2.3

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P3
**Estimate:** 1h
**Phase:** 1 — Maintenance ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-007](../adr/ADR-007-build-test-and-release-pipeline.md)
**Approval:** vendoring approved by the owner on 2026-11-24, at the latest release available at vendoring time ([plan](../plans/addon-adoption-plan.md#owner-decisions-2026-11-24)).

### Goal

Update the vendored GdUnit4 to the latest patch release, after reading
the release notes.

### Acceptance Criteria

- [ ] The 6.2.1, 6.2.2 and 6.2.3 release notes have been read, and any
      breaking or CLI change is noted in the PR body.
- [ ] `addons/gdUnit4/` is replaced with the v6.2.3 content, unmodified.
- [ ] The ADR-007 version line and `CHANGELOG.md` are updated.
- [ ] `task ci` is green. The zero-suite timeout guard in `ci.yml` still
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

### Dependencies

None.
