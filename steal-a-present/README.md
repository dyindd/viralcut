# 🎁 Steal a Present — Roblox game (Rojo project)

A "Steal a Brainrot"-style steal-and-collect game where the hook is **UNWRAPPING**: boxes on the conveyor are
mysteries until they reach your base, then they pop into a rarity (Coal → Common → … → Mythic → Secret) with
mutations, server-wide announcements, a Pet Simulator 99-style UI, and a **Grinch Mode** every 8 minutes.
Presents are the permanent core; seasons (Christmas → New Year → Valentine's) rotate as content updates.

Everything is code: the map, the UI, the tools. Press Play and it runs. Swap in real art whenever you want.

* `docs/RESEARCH.md` — the trend study (Steal An Egg, Brainrot, Poki/CrazyGames/TikTok, the June 2026 Roblox algorithm change) and why each system exists
* `docs/BALANCING.md` — the economy numbers, the pacing simulation, and how to tune
* `docs/ROADMAP.md` — 3-month live-ops plan (Christmas launch, New Year's, Valentine's)
* `docs/STUDIO_CHECKLIST.md` — the manual steps: API access, gamepass/product IDs, sounds, art, publishing
* `docs/TESTING.md` — how the headless test engine runs the real server + client here, and how to add scenarios
* `docs/LAUNCH.md` — icon/thumbnail/title advice, the launch codes, and 10 clip ideas for TikTok

---

## 1. Install & sync into Roblox Studio

1. Install **Rojo**:
   * Easiest: install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run:
     ```bash
     rokit install
     ```
   * Or download the Rojo 7.4+ binary from [rojo.space](https://rojo.space/docs/v7/getting-started/installation/).
2. Install the **Rojo plugin** in Roblox Studio (Plugins → Manage Plugins → search "Rojo", or `rojo plugin install`).
3. In this folder:
   ```bash
   rojo serve
   ```
4. In Studio: open a new Baseplate place, delete the Baseplate, open the Rojo plugin and click **Connect**. The scripts appear under `ReplicatedStorage.Shared`, `ServerScriptService.Server` and `StarterPlayer.StarterPlayerScripts.Client`.
5. **Game Settings → Security → Enable Studio Access to API Services** (so data saves). Press **Play**.
6. Test multiplayer with **Test → Clients and Servers → 2 players** (needed for stealing, gifting and the Grinch).

To build a place file instead of live-syncing:
```bash
rojo build -o StealAPresent.rbxl
```

---

## 2. Where everything lives

```
src/
  shared/   (ReplicatedStorage.Shared) — read by server AND client
    Config.lua         EVERY tunable number: prices, odds, timers, rewards, gamepass IDs, sounds, rate limits
    Catalog.lua        CONTENT: rarities, every present, mutations, traits, daily quests, seasons, snowflake shop
    Util.lua           number formatting, weighted random, deep copy, day stamps
    Seasons.lua        which season is active now + which present sets can drop
    Remotes.lua        the single list of RemoteEvents/RemoteFunctions (server creates, client waits)
    PresentModels.lua  placeholder box/present models + the art-swap hook (ReplicatedStorage.Models)

  server/   (ServerScriptService.Server)
    Main.server.lua    boots services in order (register → Init → Start)
    Registry.lua       service locator (no circular requires)
    RateLimiter.lua    per-player per-remote throttling
    Validate.lua       argument + distance checks (never trust the client)
    WorldBuilder.lua   generates the North Pole hub (workshop, giant tree, lamp posts, snowmen, igloos, paths) and the ring of 8 fenced cottage bases
    Decor.lua          procedural Christmas models from plain Parts: trees with lights, snowmen, lamp posts, candy canes, gingerbread houses, present piles, igloos, fences, padlock, mailbox, gym set, training barbell
    Environment.lua    sky/lighting/atmosphere/bloom/color correction/sun rays, clouds, snowy terrain mountains + frozen lake, animated aurora, snowfall
    Services/
      DataService         DataStore with session locking, autosave, BindToClose, schema migrations, Studio mock
      PlotService         base assignment, slots, lock/shield, sign, pad touches → other services
      CarryService        carrying one thing at a time, weight → walk speed, drop on hit/death/leave
      ConveyorService     belt spawning/moving/buying, floor pickups, reward boxes delivered to your base
      PresentService      ★ unwrap rolls (rarity/type/mutation), placing, income tick, pile, collect, sell, offline earnings
      StealService        steal prompt, "in transit" ownership, return-on-hit, owner-leaves reclaim (no dupes)
      CombatService       Candy Cane Bat (knockback + drop), snowball projectiles
      GrinchService       the 60-second Grinch round, hits, rewards, "Become the Grinch" product
      EventService        Blizzard / Aurora / Sleigh Drop / Krampus Night / Lucky Hour
      StrengthService     training bench
      TrapService         Ice Patch / Mistletoe Snare / Elf Guard
      RebirthService      reset for a permanent multiplier + slot
      RetentionService    25-day streak calendar, playtime gift, snowflake shop, settings
      QuestService        3 daily quests (deterministic per day+player)
      IndexService        collection book + set-completion rewards
      GiftService         gift a present to someone in your server (co-play hook)
      MonetizationService gamepass cache + ProcessReceipt with receipt dedupe, VIP tag
      LeaderstatsService  player-list stats
      CodeService         redeem codes (Config.Codes)
      TutorialService     first-join objectives + completion reward
      LeaderboardService  global top-10 boards in the hub (OrderedDataStore)
      NotifyService       toasts / announcements / world effects helpers

  client/   (StarterPlayerScripts.Client)
    Main.client.lua    builds the HUD, wires remotes → State, starts controllers
    State.lua          client cache + tiny signal bus
    UI/Theme.lua       colors, font (FredokaOne), sizes — the PS99 look
    UI/UIKit.lua       component factory: panels, chunky buttons, icon buttons, cards, progress bars, rainbow
    UI/HUD.lua         currencies, side/bottom buttons, quest tracker, timers, carry card, panel manager
    UI/Toasts.lua      announcements + notifications
    UI/UnwrapPopup.lua the unwrap reveal
    UI/GrinchOverlay.lua
    UI/Panels/         Shop, Index (collection + box odds), Quests, Rewards (calendar + playtime gift), Rebirth, Base (sell), Gift, Traps, Settings (+ codes)
    Controllers/       Input (Q drop, L lock, snowball aim), Prompt (hide prompts that aren't yours), Sound, Effects

tests/
  tests.lua + run_tests.py        logic tests for the shared modules
  scenarios.lua + run_scenarios.py 45 end-to-end scenarios: the REAL server and client running in a headless engine
  engine/                          the mini Roblox runtime (see docs/TESTING.md)
  econ_sim.py                      pacing simulation (reads the real Config)
```
All three need `pip install lupa` (a Lua VM for Python). No Roblox Studio required.

### How a box becomes money (the core loop in code)
1. `ConveyorService` spawns a box (tier only, no rarity) → player holds E → `CarryService.Give`.
2. Player touches the green **DepositPad** at their base → `PlotService` → `PresentService.TryDeposit`.
3. `PresentService.unwrapBox` rolls rarity (with luck) → present type (season-aware) → mutation (event-aware), places the model, fires `UnwrapResult` to the client (popup) and announces Legendary+.
4. Every second `PresentService` adds income to the base **pile**; touch the gold **CollectPad** to bank it (or own Auto Collect).
5. Anyone can hold E on your present → `StealService.TrySteal` (refused while locked, unless they're the Grinch) → they carry it; hit them with the bat and it returns.

---

## 3. Changing odds, prices and everything else

Open `src/shared/Config.lua`. Some examples:

| I want to… | Edit |
|---|---|
| Make Legendaries rarer in Large boxes | `Config.BoxTiers[3].Odds.Legendary` (keep each tier's odds summing to 100 — the tests check it) |
| Change the price of a box | `Config.BoxTiers[n].Price` |
| Change how much strength a box needs | `Config.BoxTiers[n].Strength` |
| Change how much a present earns | `Catalog.Presents` → `Income` (cash per second) |
| Add a present | add one line to `Catalog.Presents` (Key, Name, Rarity, Income, Icon, Set) — it's instantly in the index, drops and popups |
| Add a mutation | `Catalog.Mutations` + `Catalog.MutationOrder` |
| Grinch timing / rewards | `Config.Grinch` |
| Add a server event | add to `Config.Events.List` (+ a handler in `EventService` if it does something physical) |
| Calendar rewards | `Config.Streak.Rewards` (exactly 25 entries) |
| Daily quests | `Catalog.Quests` |
| Gamepass / product IDs | `Config.Monetization` |
| Lock duration / cooldown | `Config.Lock` |
| Rebirth cost curve | `Config.Rebirth` |
| Add / expire a redeem code | `Config.Codes` (uppercase, alphanumeric; optional `Expires = {y, m, d}`) |
| Change the tutorial steps or reward | `Config.Tutorial` |
| Leaderboard boards | `Config.Leaderboard.Boards` |
| Anti-teleport strictness | `Config.AntiCheat.MaxTravelSpeed` (studs/s) |
| Wipe all player data | change `Config.DataStoreName` |

After editing, run the tests (the scenario suite boots the whole game headlessly):
```bash
pip install lupa
python3 tests/run_tests.py
python3 tests/run_scenarios.py
python3 tests/econ_sim.py
```

---

## 4. Controls
* **E / tap the prompt** — buy, pick up, steal, train, lock
* **Q** — drop what you're carrying · **L** — lock your base (must be near it)
* **Click** — swing the Candy Cane Bat (knocks thieves back; they drop the present)
* **Grinch Mode** — everyone else gets a Snowball tool: equip and click to throw. 3 hits defeats the Grinch.

## 5. Security model (short version)
* All rolls, money, stealing and purchases happen on the server. The client only sends intents.
* Every remote is rate-limited (`RateLimiter`) and validated (`Validate`: types, NaN, distance, ownership).
* Profiles are session-locked in the DataStore; a present being stolen lives in a server-side "transit" table, so two players can never both own it, and an owner leaving reclaims it before their save.
* Dev products are granted once per receipt id and only confirmed after a successful save.
* Deposits that imply travelling faster than `Config.AntiCheat.MaxTravelSpeed` (teleport exploits) are refused and the present goes home; the player is flagged in `Stats.Flags`.
* Stealing is strength-gated (2x the present's weight), so a brand-new account can't be farmed for its Legendary by a veteran unless the veteran is the Grinch.

## 6. Visual layer (all code, swap for meshes any time)
* The whole world is procedural: `Decor.lua` builds every tree, snowman, lamp post, cottage and candy cane from Parts, `Environment.lua` sets the golden-hour winter lighting, atmosphere, bloom, clouds, generates snowy terrain mountains and a frozen lake, and animates an aurora. Each decoration is one function, so replacing e.g. `Decor.Tree` with a mesh clone changes every tree in the game.
* Presents at bases float and spin (client-side), Rare+ get a neon ring, Legendary+ a light pillar and sparkles.
* Training equips a barbell tool so the character actually lifts (the tool pose raises the arm; the grip pumps), with sweat particles and a "💪 TRAINING" tag.
* Every base has a **launch pad** (owner only, hands empty) that flings you toward the conveyor, an **elf worker** that wanders between your pedestals, a **present pile** that grows with your collection, **repaint** in the Snowflake shop (recolors roof, rims, rug, mailbox, launch pad), fireworks on Legendary+ unwraps.
* The conveyor has scrolling stripes, glowing gold **SALE boxes** at half price, and sparks when a box hits the shredder.
* Decoration variety: reindeer team + Santa's sleigh at the workshop, nutcracker and gingerbread statues, giant lollipops, ice crystals, snow rocks, penguins, garlands between lamp posts; the trees now sit between bases, not in front of them.
* The padlock lamp on every base turns green while locked, red when open.
* UI: shine sweeps on buttons, spinning light rays behind the unwrap reveal, floating "+$x" pops, a rainbow outline on Rewards while something is claimable, gradient panel bodies and titles.

## 7. Art assets (`assets/`)
* `assets/images/` — 88 finished icons (512px PNG, transparent): UI buttons, currencies, box tiers, traps, mutation badges, gamepasses, products, all 46 presents.
* `assets/marketing/` — game icon (two variants) and three 1920x1080 thumbnails for the Creator Dashboard.
* `assets/textures/` — four seamless wrapping papers that the belt boxes wear once uploaded.
* **Images only render after they are uploaded to YOUR Roblox account** (that's a Roblox rule, not a game one). Three ways, pick one:
  1. **Studio, no typing** (easiest): View → Asset Manager → Images → *Bulk Import* `assets/images` and `assets/textures`. When the upload finishes, select all the new images in Asset Manager, right-click → *Insert*. They appear as Decals named `ui_Rewards`, `present_TeddyBear`, …. Create a Folder named `Icons` in ReplicatedStorage and drag the Decals into it, then save the place. `Icons.Get` finds them by name at runtime. (Press Play and the UI, tool hotbar and box wrapping all switch to the real art.)
  2. **Make it permanent in the repo**: with the Decals in `ReplicatedStorage.Icons`, run the one-liner from the header of `tools/apply_ids.py` in Studio's Command Bar, paste the Output into `ids.txt`, run `python3 tools/apply_ids.py ids.txt`. Now the ids live in `src/shared/Icons.lua`.
  3. **Fully automatic from the terminal**: `python3 tools/upload_to_roblox.py --user <your id>` with an Open Cloud API key (steps in the file header).
  Until an image is available the UI shows the emoji fallback, so you can do this gradually. Tool hotbar pictures reuse existing art (Candy Cane Sword for the bat, Snowflake for the snowball, Strength arm for the barbell).
* 3D models (presents on pedestals, boxes, traps) are still generated Parts; drop meshes into `ReplicatedStorage.Models.*` to replace them.
* **Sounds**: `Config.Sounds` has library IDs that may be silent/moderated; replace with your own.
* **Icons**: UI uses emoji; `UIKit.IconButton` takes an `Image` to swap.
* **Base lock** is enforced by the server (steals are refused), not by a physical wall — simpler and exploit-proof, but thieves can still walk through a locked base.
* **Trading** (present-for-present) is planned for the Valentine's update, not built.
