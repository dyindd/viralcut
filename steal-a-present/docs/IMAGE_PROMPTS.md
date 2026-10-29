# ChatGPT image prompts for Steal a Present

Paste the **STYLE BLOCK** at the start of a new ChatGPT conversation, then send the batches one at a time.
Ask for **transparent backgrounds** (ChatGPT's image model supports PNG with alpha). Every image is square unless noted.

## How the images get into the game
1. Save each PNG with the filename shown (a 3x3 grid can be cut into tiles with `python3 tools/slice_grid.py grid.png ui_rewards ui_rebirth ...`, needs `pip install pillow`).
2. In Roblox Studio open **View → Asset Manager → Images → Bulk Import**, upload the PNGs, then right-click an image → **Copy ID**.
3. Paste the numeric IDs into `src/shared/Icons.lua` next to the matching key. Anything left at `0` keeps the emoji fallback.
4. Game icon / thumbnails are uploaded on the Creator Dashboard (Experience → Basic Settings), not in Icons.lua.

---

## STYLE BLOCK (paste first)
```
You are generating game art for a Roblox simulator game called "Steal a Present" (Pet Simulator 99 visual style).
Use EXACTLY this style for every image unless I say otherwise:
- Chunky, glossy, cartoon 3D-render look (cel-shaded toy-like volumes, rounded edges), NOT flat vector, NOT realistic.
- Bold saturated candy colors (reds, greens, golds, sky blues, pinks), a bright white top highlight on every shape,
  a soft dark drop shadow underneath.
- A thick dark-navy outline (#26263A) around the whole silhouette, like a sticker.
- Christmas / North Pole theme: snow, candy canes, ribbons, string lights are welcome as accents.
- Subject centered, filling about 80% of the canvas, 3/4 front view, strong readable silhouette at tiny sizes
  (these are 64px buttons on phones).
- Transparent background (PNG with alpha). No text, no letters, no watermark, no frame, nothing else in the image.
- Square 1:1 canvas, 1024x1024.
When I ask for a GRID, put each item in its own equal cell with a thin empty gap between cells, in the order I list,
left to right then top to bottom, one item per cell, nothing overlapping cell borders, no labels.
Reply only with the image.
```

---

## 1. UI buttons (10)

**Batch 1** (9 images, ask for a 3x3 grid or one by one). Save as: `ui_Rewards.png`, `ui_Rebirth.png`, `ui_Gift.png`, `ui_Lock.png`, `ui_Base.png`, `ui_Shop.png`, `ui_Index.png`, `ui_Quests.png`, `ui_Traps.png`

```
GRID of 9 icons, same style block. Items in order:
1. a wrapped gift box with a big bow and a glowing star burst
2. two curved arrows forming a circle with a rising sparkle
3. a heart-shaped gift box with a ribbon
4. a chunky golden padlock
5. a stack of three wrapped presents
6. a red shopping cart full of presents
7. an open book with a golden star on the page
8. a golden five-point star with a checkmark
9. a blue shield with a snowflake emblem
```

**Batch 2** (1 images, ask for a 2x2 grid or one by one). Save as: `ui_Settings.png`

```
GRID of 1 icons, same style block. Items in order:
1. a silver gear
```

## 2. Currencies (3)

**Batch 1** (3 images, ask for a 2x2 grid or one by one). Save as: `cur_Cash.png`, `cur_Snowflakes.png`, `cur_Strength.png`

```
GRID of 3 icons, same style block. Items in order:
1. a stack of green cash bills with a gold dollar coin
2. a sparkling light-blue snowflake
3. a flexing orange arm with a dumbbell
```

## 3. Box tiers (7)

**Batch 1** (4 images, ask for a 2x2 grid or one by one). Save as: `box_Small.png`, `box_Medium.png`, `box_Large.png`, `box_Huge.png`

```
GRID of 4 icons, same style block. Items in order:
1. a small red wrapped gift box with a yellow ribbon
2. a medium blue wrapped gift box with a yellow ribbon
3. a large green wrapped gift box with a gold ribbon
4. a huge purple wrapped gift box covered in sparkles
```

**Batch 2** (3 images, ask for a 2x2 grid or one by one). Save as: `box_Giant.png`, `box_Sack.png`, `box_Gift.png`

```
GRID of 3 icons, same style block. Items in order:
1. a giant golden wrapped gift box with light rays bursting out
2. Santa's red velvet sack overflowing with presents
3. a pink gift box with a heart tag and a glowing bow
```

## 4. Traps (3)

**Batch 1** (3 images, ask for a 2x2 grid or one by one). Save as: `trap_IcePatch.png`, `trap_Mistletoe.png`, `trap_ElfGuard.png`

```
GRID of 3 icons, same style block. Items in order:
1. a round patch of cracked blue ice
2. a mistletoe sprig with a red bow and a snare rope
3. a cartoon elf guard holding a candy cane bat
```

## 5. Mutation badges (6)

**Batch 1** (6 images, ask for a 3x3 grid or one by one). Save as: `mut_Golden.png`, `mut_Frosted.png`, `mut_CandyCane.png`, `mut_Rainbow.png`, `mut_Galaxy.png`, `mut_Cursed.png`

```
GRID of 6 icons, same style block. Items in order:
1. a glossy golden star badge
2. a frosted blue crystal badge
3. a red-and-white striped candy badge
4. a rainbow gradient badge
5. a deep purple galaxy badge with stars
6. a dark red cursed badge with a crack
```

## 6. Gamepasses (5) — also used on the Roblox store page

**Batch 1** (5 images, ask for a 3x3 grid or one by one). Save as: `pass_VIP.png`, `pass_ExtraSlots.png`, `pass_Speed.png`, `pass_AutoCollect.png`, `pass_Strong.png`

```
GRID of 5 icons, same style block. Items in order:
1. a golden crown with VIP written on a ribbon
2. four pedestals with a plus sign
3. a lightning bolt over running boots
4. a horseshoe magnet pulling in gold coins
5. a dumbbell with a flexing arm
```

## 7. Developer products (8)

**Batch 1** (4 images, ask for a 2x2 grid or one by one). Save as: `prod_Cash1.png`, `prod_Cash2.png`, `prod_Cash3.png`, `prod_Snowflakes1.png`

```
GRID of 4 icons, same style block. Items in order:
1. a small pile of cash
2. a bag of cash
3. a vault bursting with cash
4. a jar of glowing snowflakes
```

**Batch 2** (4 images, ask for a 2x2 grid or one by one). Save as: `prod_LuckPotion.png`, `prod_Protein.png`, `prod_LockExtend.png`, `prod_GrinchTurn.png`

```
GRID of 4 icons, same style block. Items in order:
1. a green four-leaf-clover potion bottle
2. a protein shaker bottle with a muscle emblem
3. a golden padlock with a clock
4. a green furry Grinch hand grabbing a present
```

## 8. Present icons (one per collectible, 46 total)

These show in the Index, the unwrap popup and your base list. Describe each as a cute collectible toy. Rarity colors: Coal grey/black, Common light grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic hot pink/red, Secret black-and-rainbow. Give Legendary+ items a glow matching their rarity color.

**Classic set, batch 1** (9 images). Save as: `present_LumpOfCoal.png`, `present_SoggySock.png`, `present_Fruitcake.png`, `present_TeddyBear.png`, `present_RubberDuck.png`, `present_YoYo.png`, `present_ToyCar.png`, `present_SnowGlobe.png`, `present_RobotToy.png`

```
GRID of 9 collectible toy icons, same style block. Items in order:
1. Lump of Coal (Coal rarity: dull grey-black, slightly sad and funny)
2. Soggy Sock (Coal rarity: dull grey-black, slightly sad and funny)
3. Ancient Fruitcake (Coal rarity: dull grey-black, slightly sad and funny)
4. Teddy Bear (Common rarity: simple, light grey accents)
5. Rubber Duck (Common rarity: simple, light grey accents)
6. Yo-Yo (Common rarity: simple, light grey accents)
7. Toy Car (Common rarity: simple, light grey accents)
8. Snow Globe (Common rarity: simple, light grey accents)
9. Robot Toy (Uncommon rarity: green accents)
```

**Classic set, batch 2** (9 images). Save as: `present_Skateboard.png`, `present_GameConsole.png`, `present_Drone.png`, `present_Jetpack.png`, `present_IceDragonEgg.png`, `present_YetiCub.png`, `present_FrostPhoenix.png`, `present_NorthernOrb.png`, `present_GrinchHeart.png`

```
GRID of 9 collectible toy icons, same style block. Items in order:
1. Skateboard (Uncommon rarity: green accents)
2. Game Console (Rare rarity: blue accents and a small sparkle)
3. Drone (Rare rarity: blue accents and a small sparkle)
4. Jetpack (Epic rarity: purple accents with sparkles)
5. Ice Dragon Egg (Epic rarity: purple accents with sparkles)
6. Yeti Cub (Legendary rarity: golden glow and light rays)
7. Frost Phoenix (Legendary rarity: golden glow and light rays)
8. Northern Lights Orb (Mythic rarity: hot pink and red glow with energy swirls)
9. The Grinch's Heart (Secret rarity: black with a rainbow holographic sheen and an intense glow)
```

**Christmas set, batch 1** (9 images). Save as: `present_WoolSocks.png`, `present_Gingerbread.png`, `present_Nutcracker.png`, `present_CocoaMug.png`, `present_CandyCaneSword.png`, `present_ElfHat.png`, `present_ReindeerPlush.png`, `present_GoldenSled.png`, `present_SnowmanKing.png`

```
GRID of 9 collectible toy icons, same style block. Items in order:
1. Wool Socks (Common rarity: simple, light grey accents)
2. Gingerbread Man (Uncommon rarity: green accents)
3. Nutcracker (Uncommon rarity: green accents)
4. Hot Cocoa Mug (Uncommon rarity: green accents)
5. Candy Cane Sword (Rare rarity: blue accents and a small sparkle)
6. Elf Hat (Rare rarity: blue accents and a small sparkle)
7. Reindeer Plush (Rare rarity: blue accents and a small sparkle)
8. Golden Sled (Epic rarity: purple accents with sparkles)
9. Snowman King (Epic rarity: purple accents with sparkles)
```

**Christmas set, batch 2** (5 images). Save as: `present_SantasBoots.png`, `present_DiamondSnowflake.png`, `present_RedNoseReindeer.png`, `present_KrampusIdol.png`, `present_SantasSleigh.png`

```
GRID of 5 collectible toy icons, same style block. Items in order:
1. Santa's Boots (Legendary rarity: golden glow and light rays)
2. Diamond Snowflake (Legendary rarity: golden glow and light rays)
3. Red-Nose Reindeer (Mythic rarity: hot pink and red glow with energy swirls)
4. Krampus Idol (Mythic rarity: hot pink and red glow with energy swirls)
5. Santa's Sleigh (Secret rarity: black with a rainbow holographic sheen and an intense glow)
```

**NewYear set, batch 1** (7 images). Save as: `present_PartyPopper.png`, `present_DiscoBall.png`, `present_ChampagneTower.png`, `present_CountdownClock.png`, `present_GoldenFireworks.png`, `present_TimeCapsule.png`, `present_BallDrop.png`

```
GRID of 7 collectible toy icons, same style block. Items in order:
1. Party Popper (Common rarity: simple, light grey accents)
2. Disco Ball (Uncommon rarity: green accents)
3. Champagne Tower (Rare rarity: blue accents and a small sparkle)
4. Countdown Clock (Epic rarity: purple accents with sparkles)
5. Golden Fireworks (Legendary rarity: golden glow and light rays)
6. Time Capsule (Mythic rarity: hot pink and red glow with energy swirls)
7. The Ball Drop (Secret rarity: black with a rainbow holographic sheen and an intense glow)
```

**Valentines set, batch 1** (7 images). Save as: `present_LoveLetter.png`, `present_ChocolateBox.png`, `present_HeartTeddy.png`, `present_CupidsBow.png`, `present_DiamondRing.png`, `present_HeartOfGold.png`, `present_CupidHimself.png`

```
GRID of 7 collectible toy icons, same style block. Items in order:
1. Love Letter (Common rarity: simple, light grey accents)
2. Chocolate Box (Uncommon rarity: green accents)
3. Teddy with Heart (Rare rarity: blue accents and a small sparkle)
4. Cupid's Bow (Epic rarity: purple accents with sparkles)
5. Diamond Ring (Legendary rarity: golden glow and light rays)
6. Heart of Gold (Mythic rarity: hot pink and red glow with energy swirls)
7. Cupid Himself (Secret rarity: black with a rainbow holographic sheen and an intense glow)
```

---

## 9. Game icon (512x512) — upload on the Creator Dashboard
```
Roblox game icon, square 1:1, same style block but NO transparent background (fill the canvas): a huge wrapped
present mid-unwrap, the lid popping off with golden light rays and rainbow sparkles bursting out, a cute Roblox-style
character's hands reaching in from the bottom, snowy North Pole background with a decorated Christmas tree and
string lights, bold, extremely colorful, high contrast, designed to be readable at 100 pixels. No text.
```
Make a second variant with the text **"STEAL A PRESENT"** in chunky white letters with a thick navy outline across the top, and pick whichever reads better small.

## 10. Thumbnails (1920x1080, landscape 16:9) — upload on the Creator Dashboard
```
Thumbnail 1, 16:9 landscape, same style block without transparency: a Roblox-style character at a snowy base
unwrapping a glowing SECRET-tier present, rainbow light bursting out, a giant popup card behind them in chunky
white-with-navy-outline style showing a gift and stars, other players running toward it, Christmas cottages,
candy canes and an aurora sky behind. Extremely colorful, cinematic, no readable text.
```
```
Thumbnail 2, 16:9: a glowing green Grinch-like Roblox character sprinting out of a locked base carrying a huge
present over its head, snowballs flying at it from three players, a padlock gate behind, dusk sky with aurora,
motion blur and sparkles. No text.
```
```
Thumbnail 3, 16:9: a cartoon elf guard with a candy cane bat whacking a sneaky thief who drops a golden present
one step from a glowing green pad, "so close" energy, Christmas base with fence lights and a gingerbread cottage,
snow particles. No text.
```

## 11. Optional: seamless wrapping-paper textures (apply to box Parts with a Texture instance)
```
Seamless tileable wrapping paper texture, 1024x1024, top-down flat, no shading, no outline:
(a) red with white candy-cane stripes; (b) blue with white snowflakes; (c) green with gold polka dots;
(d) pink with white hearts. One image per pattern.
```

## Checklist of files (88 images)

`ui_Rewards.png`, `ui_Rebirth.png`, `ui_Gift.png`, `ui_Lock.png`, `ui_Base.png`, `ui_Shop.png`, `ui_Index.png`, `ui_Quests.png`, `ui_Traps.png`, `ui_Settings.png`, `cur_Cash.png`, `cur_Snowflakes.png`, `cur_Strength.png`, `box_Small.png`, `box_Medium.png`, `box_Large.png`, `box_Huge.png`, `box_Giant.png`, `box_Sack.png`, `box_Gift.png`, `trap_IcePatch.png`, `trap_Mistletoe.png`, `trap_ElfGuard.png`, `mut_Golden.png`, `mut_Frosted.png`, `mut_CandyCane.png`, `mut_Rainbow.png`, `mut_Galaxy.png`, `mut_Cursed.png`, `pass_VIP.png`, `pass_ExtraSlots.png`, `pass_Speed.png`, `pass_AutoCollect.png`, `pass_Strong.png`, `prod_Cash1.png`, `prod_Cash2.png`, `prod_Cash3.png`, `prod_Snowflakes1.png`, `prod_LuckPotion.png`, `prod_Protein.png`, `prod_LockExtend.png`, `prod_GrinchTurn.png`, `present_LumpOfCoal.png`, `present_SoggySock.png`, `present_Fruitcake.png`, `present_TeddyBear.png`, `present_RubberDuck.png`, `present_YoYo.png`, `present_ToyCar.png`, `present_SnowGlobe.png`, `present_WoolSocks.png`, `present_RobotToy.png`, `present_Skateboard.png`, `present_Gingerbread.png`, `present_Nutcracker.png`, `present_CocoaMug.png`, `present_GameConsole.png`, `present_Drone.png`, `present_CandyCaneSword.png`, `present_ElfHat.png`, `present_ReindeerPlush.png`, `present_GoldenSled.png`, `present_SnowmanKing.png`, `present_Jetpack.png`, `present_IceDragonEgg.png`, `present_SantasBoots.png`, `present_YetiCub.png`, `present_FrostPhoenix.png`, `present_DiamondSnowflake.png`, `present_RedNoseReindeer.png`, `present_NorthernOrb.png`, `present_KrampusIdol.png`, `present_SantasSleigh.png`, `present_GrinchHeart.png`, `present_PartyPopper.png`, `present_DiscoBall.png`, `present_ChampagneTower.png`, `present_CountdownClock.png`, `present_GoldenFireworks.png`, `present_TimeCapsule.png`, `present_BallDrop.png`, `present_LoveLetter.png`, `present_ChocolateBox.png`, `present_HeartTeddy.png`, `present_CupidsBow.png`, `present_DiamondRing.png`, `present_HeartOfGold.png`, `present_CupidHimself.png`
