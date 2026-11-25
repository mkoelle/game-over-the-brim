# ADR-020: Steam Remote Play Together as the First Online Path

**Status:** Proposed (research done in T-016; the owner decides accept or reject)

**Date:** 2026-11-24

---

### Context

[ADR-009](ADR-009-netcode-addon-netfox.md) plans netfox for Tier 2
(networked grid). Real netcode for a physics-driven arcade racer is the
largest single engineering cost on the roadmap. It is also exactly the
over-engineering-before-fun risk STATE.md warns about.

Steam **Remote Play Together** streams a local-multiplayer game from the
host's machine to remote friends. Guests do not need to own the game, and
their controllers appear to the host as local input devices.

Valve's Steamworks documentation describes enabling it as a partner-site
setting:

- *Application → Steam Remote Play* in the partner site.
- Enabled automatically for games tagged Local Multiplayer, Local Co-op or
  Shared/Split Screen.

T-016 confirmed the SDK question. See Findings below.

Sources:
- <https://partner.steamgames.com/doc/features/remoteplay>
- <https://partner.steamgames.com/doc/marketing/remoteplaytogether>

This game is couch-first: Tier 1 splitscreen with per-device input
(ADR-004, [ADR-014](ADR-014-per-device-input-action-map.md)) is already
the core target. Remote Play Together would turn Tier 1 into "online with
friends" with no netcode.

---

### Decision (proposed)

1. Treat Remote Play Together as the **first online offering**. Ship Tier
   1 splitscreen on Steam with Remote Play Together enabled before starting
   any netfox (Tier 2) work.
2. Defer ADR-009 Tier 2 implementation until data shows demand Remote Play
   cannot serve:
   - more than 4 racers
   - latency complaints
   - a presenter or broadcast client on a separate machine
3. **GodotSteam** (MIT; GitHub repo archived and development moved to
   Codeberg, `codeberg.org/godotsteam/godotsteam`; latest GitHub tag v4.24,
   2026-11-08) is needed only for Steam lobbies, achievements or rich
   presence, not for Remote Play Together itself. GodotSteam is native, so
   it is gated by [ADR-015](ADR-015-native-gdextension-addon-policy.md).

To accept this ADR, the owner must confirm:
- It is OK to commit to Steam as a launch platform. The Steam Direct app
  fee applies.
- It is OK to push networked play (Tier 2) back.

---

### Findings (T-016, 2026-11-25)

**1. SDK integration: not required.** The partner-site setting is enough.
The Steamworks page says the SDK is optional, only for an in-game invite
button via `ISteamRemotePlay::BSendRemotePlayTogetherInvite()`. Games tagged
Local Multiplayer, Local Co-op or Shared/Split Screen get the feature
automatically, and the tag can be overridden.
Source: <https://partner.steamgames.com/doc/features/remoteplay>

**2. Optional SDK APIs (`ISteamRemotePlay`).** None are needed for launch.
Useful later:
- `GetSessionCount`, `BSessionRemotePlayTogether`, session connect and
  disconnect callbacks: detect that a guest joined.
- `GetSessionSteamID`, `GetSessionClientName`, avatar getters: show guest
  names and avatars in the lobby.
- `BSendRemotePlayTogetherInvite`, `ShowRemotePlayTogetherUI`: invite UI.
- `BEnableRemotePlayTogetherDirectInput` and `GetInput`: read remote
  keyboard and mouse separately from the host's own input.

Source: <https://partner.steamgames.com/doc/api/ISteamRemotePlay>

Whether GodotSteam wraps these was not verified (godotsteam.com returned
403 to the fetch tool). Check before relying on it.

**3. Guest controllers and Godot 4.7 device IDs.** Valve does not document
how guest controllers appear to the host game. What is established:
- Steam Input injects an emulated Xbox controller into the game. On Windows
  the overlay hooks XInput, DirectInput, RawInput and Windows.Gaming.Input.
  macOS and Linux use a driver instead. Valve states "Steam Remote Play uses
  it to provide input while streaming."
  Source: <https://partner.steamgames.com/doc/features/steam_controller/steam_input_gamepad_emulation_bestpractices>
- Godot 4.7.2 uses an SDL3 joypad driver. Each `SDL_EVENT_JOYSTICK_ADDED`
  gets `Input.get_unused_joy_id()`, which returns the lowest ID in 0 to 15
  not currently connected (`core/input/input.cpp`, 4.7.2-stable). IDs follow
  connection order and are reused after a disconnect. They are not tied to
  XInput slot or player.
  The driver also reports `steam_input_index` (Steam handle) and, on
  Windows, `xinput_index` in the joypad info dictionary.
  Source: `drivers/sdl/joypad_sdl.cpp` at tag `4.7.2-stable`,
  <https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/sdl/joypad_sdl.cpp>
- Inference, not verified: guest pads should arrive as ordinary extra
  joypads with the next free IDs, in the order Steam presents them. Reports
  say guest pads can show up in an unexpected slot or not at all.
  Community reports:
  <https://steamcommunity.com/groups/SteamClientBeta/discussions/0/4052614347231719696>
  and <https://itch.io/post/2129240>
- Not established: the exact ID, name, GUID and ordering of a guest pad in
  Godot, and whether Steam Input on or off changes it. Only a hands-on test
  can settle this (see the test procedure below).

Effect on ADR-014: `DeviceActionMap` must not assume that ID order equals
seat order, or that IDs are stable. Bind devices to players on a "press to
join" screen, and handle `joy_connection_changed` for guests who connect or
drop mid-session. Do not key on `xinput_index`.

**4. Remote keyboard guests.** Valve does not document the default. The
host controls whether guests may share keyboard and mouse
(<https://store.steampowered.com/remoteplay>). Community reports say guest
keyboard input is merged into the host's OS keyboard stream, so the game
cannot tell sources apart
(<https://steamcommunity.com/groups/SteamClientBeta/discussions/0/4052614347231719696>).
That matches the expectation, but it is a forum claim, not Valve
documentation. The SDK offers a fix: `BEnableRemotePlayTogetherDirectInput`
separates remote keyboard and mouse input (source in item 2). Decision:
treat Remote Play guests as gamepad-only slots, and keep the SDK route as
a later option.

**5. Cost and testing path.**
- Steam Direct fee: $100 per product, non-refundable, recoupable after the
  product reaches $1,000 adjusted gross revenue. First-release rules: a
  public "coming soon" page for at least two weeks and a 21-day wait
  between paying the fee and release.
  Source: <https://partner.steamgames.com/steamdirect>
- Testing before release: put the build on a password-protected branch,
  leave the default branch empty, set *Application → Steam Remote Play* to
  that branch, send CD keys to testers, and invite them from the friends
  list. Each session needs a fresh invite. Needs a Steam client dated
  2020-05-23 or newer. Steam Playtest is a separate feature and was not
  researched here.
  Source: <https://partner.steamgames.com/doc/features/remoteplay>
- Guest count: Valve says "up to four players, or even more with fast
  connections," with no firm maximum or bandwidth figure. VR is not
  supported. Source: <https://store.steampowered.com/remoteplay>

---

### Hands-on test (pending owner; needs an app ID)

An app ID costs $100 and needs a Steamworks account, so no agent created
one. When an app ID exists:
1. Upload a Windows build to a password-protected branch. Enable
   *Application → Steam Remote Play* for that branch.
2. Add a throwaway debug overlay (the F3 overlay) that logs
   `Input.get_connected_joypads()`, `Input.get_joy_name(id)`,
   `Input.get_joy_guid(id)` and `Input.get_joy_info(id)`. Log
   `joy_connection_changed` events with timestamps.
3. Host starts the game with one local pad connected. Note its ID.
4. Invite guest A, who has a gamepad. Record the new ID, name, GUID and
   info keys (`steam_input_index`, `xinput_index`).
5. Invite guest B with a second gamepad. Record the same fields.
6. Repeat steps 3 to 5 with Steam Input forced on, then off, in the game's
   Steam controller properties.
7. Guest A disconnects and rejoins. Does the ID change? Does the event fire?
8. A guest with only a keyboard, while the host also uses the keyboard. Do
   both inputs reach the same `InputEventKey` stream? Can they be told
   apart?
9. Run a 4-player race (host plus 3 guests). Note input lag and any
   dropped joypad.
10. Write the results into this ADR and set it to Accepted or Rejected.

---

### Recommendation (for the owner)

**Accept.** Reasons:
- No SDK or addon is needed to ship it. The only cost is the $100 Steam
  Direct fee, which a Steam launch needs anyway.
- It reuses Tier 1 splitscreen and the per-device input map (ADR-014), and
  postpones the largest engineering cost (netfox) until demand is proven.
- The unknowns (guest device IDs, keyboard guests) are cheap to test and
  are already covered by ADR-014's press-to-join design.

Conditions: commit to Steam as a launch platform, and accept that Tier 2
(netfox) waits. Keep the hands-on test as a gate before marketing "play
online". If the test shows guest pads are unusable, reject and revisit
ADR-009. This recommendation is recorded as an assumption in T-016.

---

### Consequences

**Positive (if accepted):**
- "Play online with friends" without writing netcode. Engineering time goes
  to handling feel and spectator chaos.
- Validates the online audience before the netfox investment.

**Negative / Tradeoffs:**
- Steam-only. No cross-store online play.
- Guest experience depends on the host's upload bandwidth and on stream
  latency.
- Remote guests who use a **keyboard** arrive as host keyboard input. That
  collides with a local keyboard player. Remote Play guests should be
  treated as gamepad-only slots, or the collision must be tested.
- Does not serve Tier 2 or 3 scale (16+ racers) or a separate presenter
  machine (ADR-005 and ADR-006). netfox stays the plan for those.

---

### Alternatives Considered

1. **Go straight to netfox Tier 2:** Higher cost and risk before there is
   evidence the online audience exists.
2. **Parsec or other third-party streaming:** Works with no integration at
   all, but nothing in-store or in-client is visible to players. It can be
   recommended to players, but it is not a product feature.
