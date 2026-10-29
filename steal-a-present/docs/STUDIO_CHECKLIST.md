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

## Optional but recommended
* Add a `Lighting` Atmosphere / SkyBox for the winter look (the project JSON only sets brightness/ambient).
* Replace the emoji icons in the UI with images: every `UIKit.IconButton` accepts `Image = "rbxassetid://..."`.
* Set up a group so you can add developers and split revenue.
