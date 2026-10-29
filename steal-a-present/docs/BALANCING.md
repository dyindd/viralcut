# Balancing

All numbers live in `src/shared/Config.lua` and `src/shared/Catalog.lua`. This document explains the
*reasoning* and shows what the pacing simulation predicts, so you can change numbers on purpose.

## Targets
| Milestone | Target | Simulated (median, solo player, 24s per box trip) |
|---|---|---|
| First Uncommon | ~1–2 min | 1.6 min |
| First Rare | ~5 min | 4.3 min (4.8 min with slow 30s trips) |
| First Epic | ~10 min | 8.5 min |
| First Legendary | ~25–30 min | 23.6 min |
| First Mythic | ~1–1.5 h | 76 min |
| First Secret | a flex, not a milestone | 135 min, and only ~38% of players within 3 hours |
| First Rebirth ($100k) | 45–60 min | 45.6 min (p10 28 min, p90 72 min) |

Run it yourself after changing numbers (it reads the real Config/Catalog):
```bash
pip install lupa
python3 tests/econ_sim.py        # 24 second round trips (default)
python3 tests/econ_sim.py 30     # pessimistic: slower walking / busy belt
```
The sim is a solo optimal player (never robbed, never AFK, always buys the best box they can carry, trains
when the next tier is affordable but too heavy, sells the worst present when the base is full). Real players
are slower, so these are *fast-case* numbers. If live data shows rebirth 1 arriving under 40 minutes, raise
`Config.Rebirth.BaseCost`, not the box prices.

## The levers and what they do

### Box tiers (`Config.BoxTiers`)
| Tier | Price | Strength | Best odds | Role |
|---|---|---|---|---|
| Small | $25 | 0 | Rare 3.6%, Epic 0.4% | the first 2 minutes; 15% Coal for the troll moment |
| Medium | $200 | 15 | Rare 11.5%, Legendary 0.2% | minutes 2–10; first strength gate (15s of training) |
| Large | $1,500 | 75 | Legendary 1.15%, Mythic 0.05% | minutes 10–40; the "main" box |
| Huge | $12,000 | 400 | Mythic 0.58%, Secret 0.02% | post-rebirth grind; 400 strength ≈ 7 min of training (less with rebirths/Protein) |
| Giant | $100,000 | 2,000 | Mythic 3.7%, Secret 0.3% | the long-term goal; same price as rebirth 1 on purpose: "rebirth or gamble?" |
| Santa's Sack | free (events) | 0 | Legendary 8.5% | makes Sleigh Drop a scramble worth clipping |
| Playtime Gift | free (30 min) | 0 | Rare+ guaranteed | the "stay 10 more minutes" hook |

Rules of thumb:
* Each tier roughly **×6–8 price** and **×3–5 Legendary odds** over the previous one.
* Strength requirements turn into *time*: `Config.Strength.GainPerSecond = 1`, +50% per rebirth, ×2 with the pass or a Protein Shake. Keep the next tier's training time around 2–7 minutes so it feels like a goal, not a wall.
* Coal odds drop with tier (15% → 0%) so paying more never feels worse.

### Present income (`Catalog.Presents`)
| Rarity | $/s | Why |
|---|---|---|
| Coal | 0 | the joke; also an index entry so completionists want it |
| Common | 1–2 | |
| Uncommon | 3–5 | |
| Rare | 8–12 | 6 Rares ≈ $60/s ≈ a Large box every 25s |
| Epic | 25–40 | |
| Legendary | 80–150 | one Legendary > your whole early base |
| Mythic | 400–700 | |
| Secret | 3,000–5,000 | a single Secret is a rebirth every 30 seconds — it's *supposed* to feel broken |

Each rarity is ~3× the previous. Mutations stack on top (Golden 1.5×, Frosted 2×, Candy Cane 3×, Rainbow 6×,
Galaxy 10×, Cursed 4×; event-only boosts ×10 the chance of the matching mutation). Traits add +5–15%.

### Why the base pile (not instant cash)
Income goes into a pile at your base that you collect by touching the gold pad. That means:
* leaving your base to buy boxes or steal has a *cost* (uncollected cash is at risk from nothing, but it pulls you home — and home is where thieves are);
* Auto Collect is a meaningful gamepass without being pay-to-win;
* offline earnings (50% rate, 8h cap) land in the pile, so "welcome back" is a satisfying tap.

### Rebirth (`Config.Rebirth`)
`cost(n) = 100,000 × 4^n` → $100k, $400k, $1.6M… Each rebirth: +0.5× income (permanent), +1 slot,
25 Snowflakes. Strength and the index are kept. The multiplier is additive (×1.5, ×2.0, ×2.5…) so late
rebirths don't explode the economy; the ×4 cost curve keeps the gap between rebirths roughly constant in
*minutes* as income grows.

### Slots
6 to start, +1 per rebirth, +4 with the pass, +1 per Snowflake-shop purchase, max 20. A full base forces a
decision (sell the worst, rebirth, or buy slots). Selling pays 120 seconds of that present's income
(`Config.SellSeconds`): enough to not feel like a loss, too little to farm.

### Stealing
* A thief carrying a present is slowed by weight (`Catalog.Rarities[].Weight`) and an extra 10% for stolen goods; the victim's bat hit sends it home instantly.
* Stealing a present needs `2 × its Weight` in Strength (Common/Uncommon: anyone; Legendary: 200; Secret: 1,000). New players can't be farmed for their one Legendary by a veteran… unless that veteran is the Grinch.
* Lock: 60s shield, 180s cooldown (+30s with VIP, +5 min with the Lock Extender). Krampus Night halves it.

### Grinch Mode (`Config.Grinch`)
Every 8 minutes, 60 seconds, needs 2+ players. Assist $150 per hit, $600 for the final hit, $3,000 + a Huge
box for surviving — all scaled by `(1 + rebirths × 0.5)` so it matters at every stage. If live data shows
the Grinch surviving more than ~60% of rounds, lower `WalkSpeed` (30) before touching `HitsToDefeat` (3).

### Retention rewards
* Calendar: 25 days, escalating from $250 to two Giant boxes. Days 7/14/21 give Luck time. Total value of a
  full streak ≈ 4–5 hours of mid-game income — worth logging in for, not worth not playing for.
* Daily quests: 3/day, $500–$10,000 + 4–20 Snowflakes. Snowflakes are the only way to buy Santa's Sacks
  outside events (300 ❄️) — a long-term sink that makes dailies feel cumulative.
* Playtime gift every 30 min: Rare 65% / Epic 28% / Legendary 6.5% / Mythic 0.5%.

## Monetization sanity
* VIP (2× cash, +25% luck, longer lock) is the only "power" pass and it's a multiplier on *effort*, not a skip.
* Cash packs are priced so that $100k (one rebirth) costs ~R$999: buying progress is possible but not the efficient path — Huge boxes earn that in ~15 minutes mid-game.
* "Become the Grinch" is the fun purchase: it changes the server's next 60 seconds, which is content for everyone.

## What to watch after launch (Creator Dashboard → Analytics)
| Metric | Healthy | If not |
|---|---|---|
| First-play bounce | low | starting cash too low, belt too far, first box too slow — check `Config.StartingCash`, `Conveyor.SpawnInterval` |
| D1 retention | > 25% | calendar day-2 reward too weak; make day 2 a Medium Box |
| Avg session | > 12 min | lower `PlaytimeGift.IntervalSeconds` to 20 min, shorten `Grinch.Interval` |
| Rebirth 1 time | 45–60 min | adjust `Rebirth.BaseCost` |
| Grinch win rate | 30–50% | `Grinch.WalkSpeed` / `HitsToDefeat` |
| Steal success rate | 40–60% | `Lock.Duration`, trap prices, `Steal.StolenSpeedPenaltyBonus` |
