# Launch notes: icon, thumbnail, title, codes, clips

The June 2026 discovery change made **play-through rate** (people who click your tile) and **first-play bounce**
two of the strongest signals. The game handles bounce (first unwrap in ~60 seconds, objective card, starting
cash). The tile is on you.

## Title
`🎁 Steal a Present [CHRISTMAS]` at launch. Keep "Steal a" (people search it) and put the season in brackets
so the title itself changes every update (a changed title is a free re-impression).

## Icon
One wrapped box mid-unwrap with light bursting out, a rarity word ("MYTHIC?") in the chunky white-with-black-outline
style, and a face reacting. No full scene. Test two: box-only vs box+face.

## Thumbnails (3)
1. The unwrap: Secret-tier present revealed, server announcement text visible.
2. The Grinch: green glowing player sprinting out of a locked base with a present over their head, snowballs flying.
3. Base defense: thief ragdolled by an Elf Guard 2 studs from the pad, "SO CLOSE" text.

## Codes already in the game (`Config.Codes`)
| Code | Gives | Use it for |
|---|---|---|
| LAUNCH | $500 + 10 Snowflakes | description + Discord |
| XMAS2026 | Large Box + 25 Snowflakes (expires Jan 2) | pinned TikTok comment |
| GRINCH | 30 min of 2x luck | Grinch clip |
| TIKTOK | $1,000 + 15 Snowflakes | every TikTok caption |
| FREEBOX | Medium Box | YouTube Shorts |
Add a new one per video (`Config.Codes.NEWCODE = { ... }`), expire old ones with `Expires`.

## 10 clips that make themselves (15–30 seconds each)
1. A Secret unwrap with the rainbow popup and the server-wide announcement.
2. Becoming the Grinch, raiding a LOCKED base, and the owner's chat reaction.
3. Surviving the full 60 seconds as the Grinch: the reward box dropping at your base.
4. Thief gets whacked one step from their pad; present flies back.
5. Sleigh Drop: eight players scrambling for ten sacks.
6. Coal. Just coal. The explosion, the "Ho ho... NO." popup.
7. A Galaxy mutation during Mutation Madness.
8. Gifting a Legendary to a random new player and their reaction.
9. Elf Guard montage: three thieves in a row.
10. Day 25 of the Advent calendar: two Giant boxes, back to back.

Every one of these is a system in the game, not a scripted moment, so creators will make them without you.

## Day-one checklist
* Codes changed or kept on purpose; `Config.DataStoreName` bumped so test data is gone.
* Grinch interval 8 min, events 7–12 min (defaults) — don't shorten them for launch; scarcity is the hook.
* Watch Creator Dashboard retention daily for the first week; the levers are in `docs/BALANCING.md`.
