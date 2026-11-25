# ADR-020: Steam Remote Play Together as the First Online Path

**Status:** Proposed (needs an owner decision; evaluation ticket T-016)

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

The docs found so far do not mention SDK calls, but they do not explicitly
rule them out. T-016 confirms this.

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
