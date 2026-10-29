# Trend Research → Design Decisions (October 29, 2026)

This is the "why" behind every system in Steal a Present. Sources were checked the day this was written;
player counts move hourly, so treat numbers as a snapshot.

## 1. What is winning on Roblox right now

| Signal | What we found | Source |
|---|---|---|
| #1 game right now | **Steal An Egg** (launched July 25, 2026). ~700K–1.6M live players on Oct 27, Q3 peak reported between 9.9M and 14.2M concurrent depending on tracker. 6B visits in Q3. | [RoWatcher](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players), [Yahoo Finance](https://finance.yahoo.com/markets/stocks/articles/roblox-stock-down-37-2026-041623422.html), [Rolimons](https://www.rolimons.com/game/107778070777162) |
| Its loop | Raid a guarded nest → carry the egg home → hatch → pet earns $/s → buy upgrades → **train speed** to unlock bigger biomes. Other players can steal from you. | [games.gg guide](https://games.gg/roblox/guides/steal-an-egg-beginner-guide/), [TechWiser wiki](https://techwiser.com/roblox-steal-an-egg-wiki/) |
| Why it works | "An objective you understand immediately, then social conflict because someone can take what you wanted to keep." Simple risk/reward. | [Player.one](https://www.player.one/robloxs-steal-egg-beating-some-platforms-biggest-games-164086) |
| All-time record | **Steal a Brainrot** is still the only game past 25M concurrent (Oct 2025). The "Steal a ___" formula is the proven template of 2025–2026. | [PocketGamer.biz](https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players/) |
| Mutation meta | Brainrot's income multipliers (Gold 1.25x, Diamond 1.5x, Rainbow 10x, event-only Candy/Galaxy/Lava…) are the collectible depth players grind for. | [Eldorado mutations guide](https://www.eldorado.gg/blog/steal-a-brainrot-en/steal-a-brainrot-mutations-guide/) |
| Hybrids work | **Plants vs Brainrots** hit ~9M concurrent by mixing Grow a Garden's farming, Brainrot memes and PvZ defense. | [MaxPowerGaming](https://www.maxpowergaming.co/post/roblox-s-latest-breakout-game-is-plants-vs-brainrots) |
| Seasonal gap | Last Christmas had NO breakout new holiday game, only updates (Steal a Brainrot Holiday, Find the Brainrot Christmas, 99 Nights Xmas). The lane is open. | [games.gg Dec 2025](https://games.gg/news/roblox-top-games-and-trends-december-2025/) |
| Name check | "Steal a Present" is unused. Closest: *Don't Steal the Present* (188 peak players) and a 2023 tycoon. | [RoWatcher](https://rowatcher.com/games/9146507470/don-t-steal-the-present) |

## 2. How Roblox decides who gets shown (June 2026 algorithm change)

Roblox's *Recommended For You* now measures **retention over 28 days** instead of 7, averaging signals over
day 1, days 2–7 and days 8–28. The named signals: play-through rate (click from the tile), first-play
bounce, qualified play sessions, **intentional co-play days**, spend days, play days per user. Clones and
clickbait are penalized. Sources: [Roblox newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox),
[Dubit](https://dubit.io/library/what-makes-a-new-roblox-game-take-off), [games.gg](https://games.gg/news/roblox-algorithm-adult-games-retention/).

What that means for us:

| Algorithm signal | System in this game |
|---|---|
| 28-day retention | **25-day streak calendar** (an Advent Calendar in December) with escalating rewards; miss a day → restart. Fits the window almost exactly. |
| Play days per user | Daily quests (3/day), Snowflake currency you can only earn by playing, calendar. |
| Qualified play sessions | Free **playtime gift every 30 min** (guaranteed Rare+), 8-minute Grinch cycle, 7–12 minute server events. Always a reason to stay 10 more minutes. |
| Intentional co-play days | **Gift a present** to a friend in your server: both get Snowflakes, the present gets +10% forever, +10% more if you're Roblox friends. |
| First-play bounce | Starting cash buys 2 boxes immediately; first unwrap within ~60 seconds; the conveyor is in the middle of the spawn area. |
| Spend days | Fair gamepasses (VIP, slots, speed, auto-collect, strength) + consumables (luck, lock extender, "Become the Grinch"). Nothing locks progress behind Robux. |

## 3. What is hot on Poki / CrazyGames / TikTok

* **Poki top trending (live stats):** Level Devil, Smash Karts, Subway Surfers, Blocky Blast Puzzle, Drive Mad ([poki.com](https://poki.com/)). Level Devil's hook is *deception + failure as entertainment*: traps that look safe, clips of streamers screaming. Our **Coal** tier (worth nothing, explodes you) and base **traps** borrow that "troll moment" energy.
* **CrazyGames:** ragdoll/physics chaos (Ragdoll Show, Ragdoll Archers), .io-style competition, daily puzzles ([playgama](https://playgama.com/blog/top-games/top-crazy-games-april-2026/), [risingtrends](https://www.risingtrends.co/trends/gaming-trends-2026)). Knockback-only combat (no deaths) and snowball fights give that physical comedy.
* **TikTok gaming 2026:** clips are getting shorter (15–30s single highlight beats a montage) ([Viryze](https://viryze.com/blog/tiktok-gaming-trends-2026)). Everything "clippable" here is designed to fit in 15 seconds: a Secret unwrap with server announcement, a Grinch raid on a locked base, a thief getting whacked 2 studs from their pad, a Sleigh Drop scramble.

## 4. The design in one paragraph

Take the proven "steal a thing → bring it home → it earns money" loop (Steal An Egg / Steal a Brainrot),
but make the thing a **mystery box** so every delivery is a gacha reveal (the Pet Simulator 99 egg-hatch
dopamine, in the PS99-style UI you asked for). Gate bigger boxes behind **Strength** training (Steal An
Egg's speed gates) so there's always a visible next goal. Layer **mutations**, an **index**, **traps**
(Plants vs Brainrots), random **server events** (Grow a Garden weather), and the **Grinch** (a 60-second
chaos role everyone can clip). Wrap it in a seasonal skin that rotates (Christmas → New Year → Valentine's)
while the present mechanic stays permanent, and build the retention calendar around the 28-day window the
algorithm now rewards.

## 5. Risks we're aware of

* **"Steal a" fatigue**: the formula is crowded. Differentiators: unwrap reveal, Strength gate, Grinch, gifting. Thumbnail/icon must show the *unwrap*, not just "steal".
* **Clone penalty**: Roblox says low-quality clones are penalized. The seasonal content pipeline (ROADMAP.md) and original systems matter.
* **Griefing**: locks, traps, return-on-hit and the strength gate on stealing (heavier presents need strength) keep new players from being farmed by veterans.
