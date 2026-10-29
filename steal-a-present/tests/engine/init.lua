-- Loads the headless engine. Usage (from the project root):
--   ENGINE_DIR = "tests/engine"; local Engine = dofile("tests/engine/init.lua")
local base = ENGINE_DIR or "tests/engine"
dofile(base .. "/types.lua")
dofile(base .. "/sched.lua")
dofile(base .. "/instance.lua")
dofile(base .. "/engine.lua")
return Engine
