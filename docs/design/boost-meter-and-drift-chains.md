# Boost Meter and Drift Chains (Proposal)

**Date:** 2026-11-26
**Status:** Proposal. The owner picks a direction; nothing here is built
yet.
**Source:** owner questions at FC-2, in the
[FC-2 checklist](../plans/fc-2-owner-checklist.md) §9:
> could chaining drifts be possible? could building up a boost be done
> over time, and using space to boost when not turning and space to
> drift when turning work? time without boosting or drifting would
> slowly drain boost gauge? thoughts and challenges, counters and
> alternatives

## Today (T-031)

Each drift charges in three tiers (0.85 s, 1.9 s and 3.0 s). Releasing
the button pays the tier at once, as a boost of +4.8 m/s for 0.7, 1.45
or 2.3 s. There is no stored boost. The drift button is also the trick
button in the air (T-033). The owner passed the FC-2 gate with this
model, so any change should keep that instant payout feel.

## What other racers do

- **Chained powerslide boosts, CTR Nitro-Fueled.** Players chain
  powerslide boosts to hold top speed almost indefinitely. A hidden
  "reserves" pool builds up and extends the boost. Some actions keep the
  reserves, such as braking in the air.
  [PowerPyx](https://www.powerpyx.com/crash-team-racing-nitro-fueled-boost-mechanics-explained/),
  [Games Atlas](https://gamesatlas.com/crash-team-racing/features/advanced-turbo-and-boosting-guide-for-crash-team-racing-nitro-fueled),
  [Push Square](https://www.pushsquare.com/news/2019/07/guide_ctr_nitro-fueled_-_how_to_boost)
- **Snaking, Mario Kart DS, and its removal in Wii.** In DS, players
  chained mini-turbos on straights ("snaking"). Online, it beat players
  who could not do it, and opinion split on whether it was skill or an
  exploit. Wii's counter was to charge only while drifting through a
  turn, so snaking charged more slowly. Nintendo did not publish its
  reasons; the fairness reading comes from reviews.
  [Mario Wiki: Snaking](https://www.mariowiki.com/Snaking),
  [GameSpot review](https://gamespot.com/reviews/mario-kart-wii-review/1900-6189936/),
  [Goombastomp](https://goombastomp.com/?p=223959)
- **A boost meter, Burnout 3.** Reckless driving fills the meter:
  drifting, near misses, oncoming lanes and air. Boost can be spent at
  any time, and takedowns extend the meter up to four times its size. A
  separate boost button spends it.
  [Wikipedia](https://en.wikipedia.com/wiki/Burnout_3_Takedown),
  [GameSpot](https://gamespot.com/reviews/burnout-3-takedown-review/1900-6106835/)
- **A boost meter, Hot Wheels Unleashed.** Drifting fills the meter
  fastest. Some cars show it as segments.
  [Prima Games](https://primagames.com/gaming/hot-wheels-unleashed-drift-guide),
  [Pro Game Guides](https://progameguides.com/hot-wheels-unleashed-2/hot-wheels-unleashed-2-tips-and-tricks-for-beginners/)

## Q1. Chaining drifts

| Option | How | Pros | Cons |
|---|---|---|---|
| **1a. Chain combo** (recommended) | A new drift started within about 0.75 s of releasing one, in the other direction, is a link. Each link multiplies the next drift's charge rate (x1.25, up to 3 links). | Rewards S-bends and keeps the instant payout. One rule, and it reads on screen. | Snaking risk on straights (see the counters). |
| 1b. CTR-style timed boosts | A press at the right moment mid-drift cashes out a boost and keeps the drift going, up to 3 times. | The highest skill ceiling. Proven in the genre. | An execution barrier for casual couch players, against the "Accessible" pillar. A third meaning for the drift button. |
| 1c. Flick to switch direction | A hop-and-flick switches the drift direction and keeps the charge. | Expressive in esses. | Easy to trigger by accident, and hard to read in split screen. |

**Counters to snaking:** our drift costs no speed (T-028), so weaving on a
straight would be the best line. Snaking is the main risk, and there are
three counters:
- **Charge by heading change, not time.** Charge counts the yaw the
  travel direction actually turns, so weaving on a straight earns
  little. This follows Mario Kart Wii's "charge only while turning".
- **Link only across real corners.** A link needs the previous drift to
  reach at least tier 1.
- **Link window.** About 0.75 s. Shorter is harder, longer is easier.

## Q2. A boost gauge you build up and spend

The idea: drift releases (and tricks, and later near misses) fill a gauge.
You spend it when you choose.

| Option | Input | Pros | Cons |
|---|---|---|---|
| **2a. Hybrid bank** (recommended) | Release still pays the tier at once (the FC-2 feel), **and** banks charge into a 3-segment gauge. Spend one segment with a **dedicated boost button**. | Keeps what passed the gate and adds a strategic choice: spend now, or save it for the straight. A dedicated button is clear (pillar 2, Clarity), as in Burnout and Hot Wheels. | One more button. The keyboard and gamepad maps need a slot. |
| 2b. Contextual space | Press with steer = drift. Press without steer = spend boost. In the air = trick. | One button, as the owner suggests. | See the challenges below. |
| 2c. Bank only | Releases pay nothing at once, and everything goes into the gauge. | Simple, and very strategic. | It loses the instant reward that just passed FC-2. Drifting feels flat until you spend. |

**Challenges of the contextual space (2b), with counters:**
- **Players press before they steer.** That is the genre habit: hop, then
  steer. Pressing on a straight to start a drift would spend boost by
  mistake. *Counter:* decide by tap or hold. A short tap (under about
  0.15 s) with steer under 0.3 is a boost. A hold that then steers is a
  drift. A tap delays the boost by the tap length.
- **Analog noise near the threshold.** With a little stick wobble, the
  same press could be read either way. *Counter:* hysteresis and a dead
  band.
- **Three meanings on one button** (drift, boost and trick). This is
  hard to teach and to read for spectators. *Counter:* move the trick to
  the boost button, or keep the trick on drift.
- **Mid-drift release.** Straightening out at the end of a drift and
  tapping again would spend boost. That could be a feature (release,
  then boost), but it needs a test.

## Q3. Draining the gauge when idle

| Option | Rule | Pros | Cons |
|---|---|---|---|
| **3a. Cap, no drain** (recommended) | The gauge holds 3 segments. Charge past full is lost. | Hoarding is bounded, with no stress. Charge wasted at full is soft pressure to spend. It is friendly to beginners. | A full gauge waiting for the last straight is still possible, but only 3 segments. |
| 3b. Slow drain after a grace period | After about 3 s without a drift or a boost, the gauge loses about 1 segment per 5 s. | A strong "use it" pressure. It keeps the flow going. | It punishes players who do not know, against "approachable". It creates anxiety. |
| 3c. Overcharge drain | Drain only above the cap: allow a 4th "hot" segment that cools off. | It rewards good drivers with a bonus that does not last. | More rules to read. |

**Multiplayer note:** a gauge invites end-of-race boost dumps. The cap
(3a) bounds that. For a tournament party game, a trailing player could
fill the gauge faster, a mild catch-up. That is a tournament design
question, so it stays out of the handling code.

## Recommendation

Prototype the **hybrid bank (2a) plus the chain combo (1a), with a cap and
no drain (3a)**, behind a toggle, so FC-3 can compare it with today's
model:
1. Releases still pay their tier at once. They also add a third,
   two-thirds or a full segment for tiers 1, 2 and 3 to a 3-segment
   gauge. A trick adds a third.
2. A dedicated boost button spends one segment: +4.8 m/s for 1.0 s.
3. A chain link within 0.75 s, in the other direction, after a tier-1+
   drift, multiplies charge by 1.25 per link, up to 3 links.
4. Charge counts turned heading, so snaking on straights earns little.
5. The gauge shows on the car (a band glow per segment), not as a small
   HUD bar (handling-reference §6).

If the owner prefers a single button, prototype 2b with the tap and hold
rule instead, and test the press-before-steer habit first.
