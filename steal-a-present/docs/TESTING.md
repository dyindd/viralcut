# Testing without Roblox Studio

Studio can't run on a server, so this project ships a **headless mini-Roblox** (`tests/engine/`) that is just
good enough to execute the real game scripts: the server boots `Main.server.lua`, builds the map, loads
profiles through a session-locked DataStore mock, spawns belt boxes on a virtual clock, and the client builds
the actual HUD and panels. Scenarios then act like players: trigger prompts, touch pads, swing bats, fire
remotes, leave and rejoin, and jump the calendar forward.

```bash
pip install lupa                 # a Lua VM embedded in Python
python3 tests/run_tests.py       # unit tests for shared modules (odds sum to 100, formatting, seasons...)
python3 tests/run_scenarios.py   # 44 end-to-end scenarios against the real server + client
python3 tests/econ_sim.py        # pacing simulation (first Rare, first rebirth...)
```

## What the engine emulates
| Area | Fidelity |
|---|---|
| Instances | tree, `Parent`, `FindFirstChild`/`WaitForChild`/`GetDescendants`, `Clone`, `Destroy`, attributes, `GetPropertyChangedSignal`, `PivotTo` |
| Properties | per-class allow-list: a typo like `TextLable.Txet` shows up in the "property names the engine didn't recognise" report; key properties are type-checked (`Text` must be a string, `LayoutOrder` an integer, `Size` a UDim2 on GUIs...) and properties shadow children just like Roblox (`TextButton.Text` is the property, not a child) |
| Signals | `Touched`, `Triggered`, `Activated`, `Died`, `ChildAdded`, remotes (`FireClient` reaches the simulated client), `Heartbeat` |
| Time | `task.wait/delay/defer/spawn`, `os.time`, `os.clock`, `GetServerTimeNow` all run on a virtual clock. `Sched.advance(seconds)` simulates frames; `Sched.skipTime(seconds)` jumps the calendar |
| Services | Players (join/leave/characters/kick), DataStoreService (session locking works, failures can be injected), OrderedDataStore, MarketplaceService, Debris, TweenService (instant), UserInputService, Workspace:Raycast (AABB, vertical) |
| Not emulated | physics, rendering, replication latency, sound, real input |

Because physics isn't simulated, tests move players with `Engine.teleport` and must wait realistic travel time
before depositing (the anti-teleport check is on in the tests too).

## Adding a scenario
Open `tests/scenarios.lua` and copy a `test("...", function() ... end)` block. Helpers you'll use:
```lua
local p = Engine.addPlayer("Name", 123)      -- joins, loads a profile, spawns at their base
buyBox(p, "Small")                            -- walks to the belt and buys that tier
deposit(p) / collect(p)                       -- touches the pads at their base
Engine.trigger(prompt, p)                     -- ProximityPrompt
Engine.fireServer(Remotes.LockBase, p, ...)   -- a client remote
Sched.advance(10)                             -- 10 virtual seconds
Engine.removePlayer(p)                        -- leaves (saves)
forceRarity("Legendary")                      -- make the next unwrap deterministic; resetRolls() after
```
Everything the server sends to a player is logged: `Engine.lastSent(p, "UnwrapResult")`.

## Reading failures
* `FAIL name -> message`: the assertion that failed.
* `engine error: ...`: a runtime error inside a game script (with a Lua traceback) - these are the ones that would have been red text in Studio's output.
* The "property names the engine didn't recognise" line lists `Class.Property` pairs set by the game that aren't in the engine's allow-list: either a typo in the game or a property the engine doesn't know yet (add it to `PROPS` in `tests/engine/instance.lua`).
