# Handoff prompt — paste this into a new Claude Code session (PC or cloud)

```
I'm continuing work on a Roblox game called "Steal a Present". Everything is in the GitHub repo
dyindd/viralcut on branch claude/compassionate-keller-zbf527, inside the folder steal-a-present/.
If the folder isn't in your working directory yet, clone the repo and check out that branch first:
  git clone https://github.com/dyindd/viralcut.git && cd viralcut && git checkout claude/compassionate-keller-zbf527 && cd steal-a-present

WHAT IT IS
A "Steal a Brainrot" style steal-and-collect game where the hook is UNWRAPPING: boxes on a conveyor have
hidden rarity until you carry them to your base, then they pop into Coal..Common..Rare..Epic..Legendary..
Mythic..Secret with mutations. Other players steal from your base; you whack them with a Candy Cane Bat;
every 8 minutes one player becomes the Grinch. UI is Pet Simulator 99 style (chunky outlined white panels,
Fredoka font, candy gradient buttons), built entirely in Luau code. Launches as a Christmas season but
presents are permanent; New Year's and Valentine's sets are already in the catalog.

READ FIRST (in this order)
1. README.md (how to sync with Rojo, where every system lives, how to tune numbers)
2. docs/TESTING.md (there is a headless mini-Roblox test engine; run the tests before/after every change)
3. docs/STUDIO_CHECKLIST.md (manual Studio steps: API access, gamepass/product IDs, sounds, art)
4. docs/BALANCING.md, docs/ROADMAP.md, docs/RESEARCH.md, docs/LAUNCH.md as needed

CURRENT STATE
- ~12,000 lines of Luau, 22 server services, 9 client panels, all data-driven from src/shared/Config.lua
  and src/shared/Catalog.lua. The world is fully procedural (Decor.lua + Environment.lua): decorated
  trees, snowmen, cottages, aurora, terrain mountains, lighting/post-fx; presents float; training lifts.
- All checks pass: `python3 tests/run_tests.py` (unit), `python3 tests/run_scenarios.py` (45 end-to-end
  scenarios that boot the REAL server and client in the engine), `python3 tests/econ_sim.py` (pacing).
  They need `pip install lupa`.
- The game has NOT yet been run inside Roblox Studio. That is the next step. Expect a few runtime
  surprises (physics, replication, sounds); the output window will name the service.

CONVENTIONS (keep them)
- Server-authoritative: every remote is rate-limited (RateLimiter) and validated (Validate); all rolls,
  money and purchases happen on the server. Never trust the client.
- Services talk through Registry.Get("Name") at call time; Main.server.lua registers, then Init, then Start.
- All tunable numbers live in Config.lua; all content (presents, quests, seasons, mutations) in Catalog.lua.
- The code deliberately avoids Luau-only syntax (no +=, no continue, no type annotations) so the plain-Lua
  test engine can parse and run it. Keep it that way.
- UI: build everything through src/client/UI/UIKit.lua (Panel, Button, IconButton, Card, Scroll,
  ProgressBar). Gradient elements use a white BackgroundColor3 (UIGradient multiplies the base color).
  Button labels are children named "Label" (TextButton.Text would shadow a child named "Text").
- Work in this chat directly; don't spawn subagents or workflows (they cost too much).
- Commit to the branch above; never push to main.

NEXT STEPS
1. Open in Roblox Studio via Rojo (README section 1), press Play, fix anything red in the output.
2. Test with 2 clients (stealing, Grinch, gifting).
3. Create gamepasses/products and paste IDs into Config.Monetization; replace sound IDs; swap in art.
4. Keep adding scenarios in tests/scenarios.lua for every new mechanic.
```
