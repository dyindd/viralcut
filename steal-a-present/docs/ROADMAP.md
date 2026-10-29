# 3-Month Live-Ops Roadmap

Roblox's algorithm now scores 28-day retention, so the plan is **one meaningful reason to come back every
week**, not one big launch. Every update below adds: new presents (content), one new mechanic (depth), and a
limited-time event (urgency). Dates assume a **December 1, 2026** launch; the Christmas season in
`Catalog.Seasons` is already set to Nov 20 → Jan 2 so you can soft-launch early.

## Phase 0 — Soft launch (Nov 20 – Nov 30)
* Publish privately / to friends. Watch: first-play bounce, time to first unwrap, D1 retention (Creator Dashboard → Analytics → Retention).
* Tune `Config.BoxTiers` prices if players stall; tune `Config.Grinch.Interval` if rounds feel too rare/too spammy.
* Make the icon + thumbnail show an unwrap moment with a rarity name on screen (play-through rate is a top signal).

## Phase 1 — Christmas launch (Dec 1 → Jan 2)  ✅ built
* **Content:** Christmas present set (18 presents) + Classic set, Santa's Sack, Advent Calendar (25 days).
* **Mechanic:** Grinch Mode, traps, gifting, strength training, server events.
* **Event:** Dec 24–26 "Christmas Eve Rush": set `Config.Grinch.Interval = 240` and `Config.Events.MinInterval = 180` for 72 hours; announce a 2x Luck weekend by temporarily setting `Config.Luck.VIPMultiplier`-style global luck (add a `Config.GlobalLuck` if you want it as a one-liner).
* Weekly drops (Dec 8, 15, 22): add 2–3 new presents each week (one line each in `Catalog.Presents`). New index entries = new reasons to open boxes.

## Phase 2 — New Year's update (Jan 2 → Feb 1)
* **Content:** "NewYear" set (Set = "NewYear"): Party Popper (Common), Disco Ball (Uncommon), Champagne Tower (Rare), Countdown Clock (Epic), Golden Fireworks (Legendary), Time Capsule (Mythic), Ball Drop (Secret). Re-skin the calendar as "Party Calendar" (already in `Catalog.Seasons`).
* **Mechanic:** **Fireworks Launcher** at each base — spend Snowflakes to fire a firework that reveals the rarity of one box on the belt for 10 seconds (information as a resource; creates "sniping" moments).
* **Event:** "Midnight Countdown" every real hour at :59 — a 60-second window where every unwrap has a guaranteed mutation. Players will set alarms.
* **Retention:** Resolutions = weekly quests (7-day goals with a Giant Box reward) on top of dailies.

## Phase 3 — Valentine's update (Feb 1 → Mar 1)
* **Content:** "Valentines" set: Love Letter, Chocolate Box, Teddy with Heart, Cupid's Bow (Epic), Diamond Ring (Legendary), Heart of Gold (Mythic), Cupid Himself (Secret).
* **Mechanic:** **Trading** (present-for-present, confirm-on-both-sides UI, 5 second cooldown + trade log). Trading is the biggest co-play driver in Adopt Me/Grow a Garden; by this point the index is big enough that trades are interesting.
* **Event:** "Secret Santa… in February": the server pairs everyone; gifting your partner gives a 2x bonus. Pushes the intentional co-play signal.
* **Monetization:** Valentine's cosmetic wraps (box skins) as a limited gamepass — pure cosmetics, no power.

## Always-on cadence
| Cadence | What |
|---|---|
| Weekly | 2–3 presents, one new daily-quest type, rotate the Snowflake Shop |
| Bi-weekly | New server event (there's a list in `Config.Events.List`; add one, it's data-driven) |
| Monthly | Season flip + one mechanic + one limited event |
| Ongoing | Read the Grinch win/loss ratio; if the Grinch survives >60% of rounds, raise `HitsToDefeat` damage or lower `WalkSpeed` |

## After March
Spring/Easter ("Steal an Egg" territory — do a *collab-style* "Egg Hunt" season instead of competing head-on),
Summer (beach presents, water balloon fights replace snowballs), Halloween 2027 (Krampus returns), then
Christmas 2027 with everything you learned. Presents never stop being the core; only the wrapping changes.
