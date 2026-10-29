# Things you must do by hand in Roblox Studio

The code builds the whole map at runtime, so the only manual work is settings, IDs and art.

## Before first test
1. **Rojo**: install the Rojo plugin in Studio (Plugins → Manage Plugins → search "Rojo"), then run `rojo serve` in this folder and press *Connect* in the plugin. See README.md.
2. **Game Settings → Security → Enable Studio Access to API Services** (so DataStores save while testing). Without it the game still runs using an in-memory store and warns in the output.
3. **Game Settings → Places → Max Players: 8** (`Config.MaxPlayersPerServer`). The map has 8 bases; raise `Config.Plots.Count` first if you want more.
4. **Game Settings → Avatar**: R15 works out of the box.
5. Press Play. You should spawn in the hub, see boxes on the belt, and have a Candy Cane Bat in your hotbar. Use **Test → Clients and Servers (2 players)** to test stealing, locks and the Grinch (needs 2+ players).

## Before publishing
6. **Create Gamepasses** (Creator Dashboard → your experience → Monetization → Passes): VIP, +4 Base Slots, Fast Legs, Auto Collect, Super Strength. Paste each ID into `Config.Monetization.Gamepasses[...].Id`.
7. **Create Developer Products** (Monetization → Developer Products): 1,000 Cash, 10,000 Cash, 100,000 Cash, Luck Potion, Protein Shake, Lock Extender, Become the Grinch, 100 Snowflakes. Paste IDs into `Config.Monetization.Products[...].Id`. Anything left at `0` is hidden from the shop.
8. **Sounds**: `Config.Sounds` has placeholder library IDs. Replace with sounds you own/upload (Toolbox → Audio, or upload your own). Set an ID to `0` to silence it.
9. **Art swap** (optional, any time): put a Model named `Small`/`Medium`/`Large`/`Huge`/`Giant`/`Sack`/`Gift` with a PrimaryPart in `ReplicatedStorage.Models.Boxes`, or a Model named after a present key (e.g. `TeddyBear`) in `ReplicatedStorage.Models.Presents`. The code uses it automatically.
10. **Icon + thumbnails**: show an unwrap with a rarity name. Play-through rate is one of the strongest discovery signals.
11. **Experience settings**: genre "Simulator / Tycoon", enable all devices (the UI scales for phones), age guidelines questionnaire, enable "Allow Private Servers" if you want (optional).
12. **Season dates**: check `Catalog.Seasons` — Christmas is Nov 20 → Jan 2 (UTC). Change them if your launch moves.
13. **Wipe test data before launch** by changing `Config.DataStoreName` (e.g. `SAP_Profiles_v2`). Everyone starts fresh.
14. **Leaderboards** use OrderedDataStores named in `Config.Leaderboard.Boards`; they need the same API access as saving. To reset them, rename the stores.
15. **Codes**: the launch codes are in `Config.Codes` (LAUNCH, XMAS2026, GRINCH, TIKTOK, FREEBOX). Change them before you publish if you don't want everyone to have them on day one. Players enter them in Settings.
16. **Upload the art**: `python3 tools/upload_to_roblox.py --user <your user id>` with an Open Cloud API key (setup steps are in the file header) uploads all 92 images and fills `Icons.lua`. Then upload `assets/marketing/game_icon_text.png` and the three thumbnails on the Creator Dashboard.
17. **Run the tests before every update**: `python3 tests/run_scenarios.py` boots the real server and client here, no Studio needed (see `docs/TESTING.md`).

## Optional but recommended
* **Graphics**: `default.project.json` sets `Lighting.Technology = Future`; in Studio set the quality level to 10+ (File → Studio Settings → Rendering) to see bloom, shadows and the atmosphere the way players on good devices will. The terrain mountains, aurora and clouds are generated at runtime by `Environment.lua`, so there is nothing to place by hand.
* To add a custom skybox, create a `Sky` in Lighting with your textures and delete the `fx("Sky", ...)` line in `Environment.ApplyLighting`.
* Replace the emoji icons in the UI with images: every `UIKit.IconButton` accepts `Image = "rbxassetid://..."`.
* Set up a group so you can add developers and split revenue.
