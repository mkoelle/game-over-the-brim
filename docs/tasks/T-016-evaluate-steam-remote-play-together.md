# T-016: Evaluate Steam Remote Play Together

**Assignee:** Unassigned (owner decision required)
**Date:** 2026-11-24
**Priority:** P3
**Status:** Done
**Estimate:** 3h (research and decision; hands-on testing needs a Steam app ID)
**Phase:** 5 — Online path ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-020](../adr/ADR-020-steam-remote-play-together-online-path.md) (Proposed)

### Goal

Answer the open questions in ADR-020, so the owner can accept or reject
"Remote Play Together first, netfox later".

### Acceptance Criteria

- [x] Confirmed from Steamworks docs whether Remote Play Together needs
      any SDK integration, or only the partner-site setting.
- [ ] Documented how remote guests' controllers appear to the host
      process, and therefore what Godot 4.7 device IDs they get. This
      matters for `DeviceActionMap` (ADR-014).
      *Partly met: Godot's ID assignment is documented from 4.7.2 source;
      the exact guest ID needs a hands-on test. Pending owner: needs an
      app ID.*
- [ ] Documented how remote **keyboard** guests behave next to a local
      keyboard player (expected: merged into host keyboard input).
      *Partly met: forum reports say merged; no Valve doc. Pending owner:
      hands-on test.*
- [x] Recorded the current Steam Direct fee and the testing path before a
      public store page exists (for example a private branch or Playtest).
- [ ] ADR-020 status changed to Accepted or Rejected, with the findings.
      *Pending owner: findings and a recommendation (accept) are in the
      ADR. Status stays Proposed because it involves money and accounts.*

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

Every question above has an answer and a source in ADR-020. The status
stays "Proposed" until the owner decides (see Assumptions).

### Dependencies

None.

### Assumptions (owner to validate)

- **Assumption:** Recommend **accepting** ADR-020. Remote Play Together
  needs no SDK or addon, so Tier 1 splitscreen can ship online-capable
  before any netfox work.
  **Evidence:** <https://partner.steamgames.com/doc/features/remoteplay>
  (partner-site setting only; SDK optional) and the ADR-020 Findings.
  **Owner check:** Decide to launch on Steam and pay the $100 Steam Direct
  fee (<https://partner.steamgames.com/steamdirect>), then set ADR-020 and
  `docs/adr/DECISIONS.md` to Accepted or Rejected.
- **Assumption:** Guest gamepads arrive as ordinary extra Godot joypads
  with the lowest free IDs (0 to 15), in connection order, so ADR-014's
  press-to-join design needs no change.
  **Evidence:** `drivers/sdl/joypad_sdl.cpp` and `core/input/input.cpp` at
  4.7.2-stable (`get_unused_joy_id()`); Valve says Steam Input provides the
  streamed input. Valve does not document guest IDs.
  **Owner check:** Run the hands-on test in ADR-020 once an app ID exists.
- **Assumption:** Remote keyboard guests merge into the host keyboard, so
  treat guests as gamepad-only.
  **Evidence:** Steam community report
  <https://steamcommunity.com/groups/SteamClientBeta/discussions/0/4052614347231719696>
  (unofficial). `BEnableRemotePlayTogetherDirectInput` is the SDK escape
  hatch (<https://partner.steamgames.com/doc/api/ISteamRemotePlay>).
  **Owner check:** Step 8 of the ADR-020 hands-on test.
