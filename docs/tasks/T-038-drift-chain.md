# T-038: Drift Chain Combo

**Assignee:** Claude (Opus)
**Date:** 2026-11-26
**Priority:** P2
**Status:** Done
**Estimate:** 2h
**Phase:** Boost and drift depth ([proposal](../design/boost-meter-and-drift-chains.md), owner choice 1a)

### Goal

Reward linking drifts through S-bends (owner FC-2: "could chaining drifts
be possible?"), without enabling "snaking" on straights.

### Acceptance Criteria

- [x] A drift that starts within 0.75 s of a paid-out release, turning
      the other way, is a link, up to 3 links.
- [x] Each link lengthens that drift's payout by 25% (x1.25, x1.5, x1.75).
- [x] Weaving on a straight earns no chain: a cancelled or unpaid drift
      breaks the chain, and the window closes after 0.75 s.
- [x] `chain_count` and the `drift_chained(count)` signal are public. The
      overlay shows `CHAIN xN`.
- [x] Tests cover these. `task ci` is green.

### Context

- **Bonus on the payout, not the charge rate.** This changes the
  proposal. With a faster charge, short weaving drifts on a straight
  would reach tier 1, which is the Mario Kart DS snaking that Mario Kart
  Wii removed. With a longer payout, every drift still needs the full
  tier-1 time (0.85 s), which is about 80 degrees of turning, so a chain
  only pays in real S-bends.
- `chain_links()` and `chain_payout_scale()` are pure and tested.

### Verification

Probe: alternating drifts on an open floor at 22 m/s, full throttle.

| Pattern | Chain | Boost lengths |
|---|---|---|
| 0.95 s drifts, 0.2 s gaps | x1, x2, x3 | 0.70, 0.87, 1.05, 1.22 s |
| 0.95 s drifts, 1.0 s gaps | none | 0.70 s each |
| 0.5 s weave ("snaking") | none | none (no drift reaches a tier) |

The 0.95 s chain sweeps an S 80 m across, so it cannot be done on a
straight road.

Tests (3 new): the link rules and payout scale, a linked drift pays 25%
longer, and short weaving drifts earn no chain.

`task ci`: `Overall Summary: 122 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Assumptions (owner to validate)

- **Assumption:** A 0.75 s link window and +25% per link (max x1.75) make
  chaining the chicane and the sweeper rewarding, but not mandatory.
  **Evidence:** The probe numbers above.
  **Owner check:** Chain the chicane into the sweeper on the circuit
  (F3 shows `CHAIN xN`). Tune `CHAIN_WINDOW` and `CHAIN_BONUS` in
  `vehicle_controller.gd`.
