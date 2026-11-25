# T-016: Evaluate Steam Remote Play Together

**Assignee:** Unassigned (owner decision required)
**Date:** 2026-11-24
**Priority:** P3
**Estimate:** 3h (research and decision; hands-on testing needs a Steam app ID)
**Phase:** 5 — Online path ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-020](../adr/ADR-020-steam-remote-play-together-online-path.md) (Proposed)

### Goal

Answer the open questions in ADR-020, so the owner can accept or reject
"Remote Play Together first, netfox later".

### Acceptance Criteria

- [ ] Confirmed from Steamworks docs whether Remote Play Together needs
      any SDK integration, or only the partner-site setting.
- [ ] Documented how remote guests' controllers appear to the host
      process, and therefore what Godot 4.7 device IDs they get. This
      matters for `DeviceActionMap` (ADR-014).
- [ ] Documented how remote **keyboard** guests behave next to a local
      keyboard player (expected: merged into host keyboard input).
- [ ] Recorded the current Steam Direct fee and the testing path before a
      public store page exists (for example a private branch or Playtest).
- [ ] ADR-020 status changed to Accepted or Rejected, with the findings.

### Context

Sources already found:

- <https://partner.steamgames.com/doc/features/remoteplay>: the setting is
  under *Application → Steam Remote Play*. It is enabled automatically for
  games tagged Local Multiplayer, Local Co-op or Shared/Split Screen. Only
  the host needs the game. Testing needs a Steam client from 2020-05-23 or
  newer.
- <https://partner.steamgames.com/doc/marketing/remoteplaytogether>

GodotSteam is **not** needed for Remote Play Together itself. If lobbies,
achievements or rich presence are wanted later, GodotSteam (MIT, now on
Codeberg) goes through the ADR-015 checklist in its own ticket.

### Files Likely Affected

- `docs/adr/ADR-020-steam-remote-play-together-online-path.md`
- `docs/adr/DECISIONS.md` (status)

### Implementation Plan

1. Read both Steamworks pages above in full, plus the Steam Input and
   Remote Play sections on guest input routing.
2. Search Steamworks docs and Valve developer forums for "Remote Play
   Together" plus "SDK" or "ISteamRemotePlay". Note which APIs are
   optional: for example, showing guest names in-game is optional and
   needs the SDK.
3. Check the current Steam Direct fee on the partner site.
4. Write the findings into ADR-020, then present the decision to the owner.
5. If accepted, add a follow-up ticket for a hands-on test once an app ID
   exists: two remote guests on gamepads, plus a check of their device IDs
   with the F3 overlay.

### Verification

ADR-020 has no "Proposed" status left, and every question above has an
answer and a source.

### Dependencies

None.
