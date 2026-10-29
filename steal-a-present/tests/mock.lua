-- Minimal Roblox API mock so the shared modules can run in plain Lua (used by run_tests.py)
local M = {}

Color3 = {
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, __color = true } end,
	new = function(r, g, b) return { R = r, G = g, B = b, __color = true } end,
}
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z, __vec = true } end }
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end }) end })
math.clamp = math.clamp or function(n, lo, hi) if n < lo then return lo elseif n > hi then return hi end return n end
task = { wait = function() end, spawn = function(f, ...) return f(...) end, delay = function() end, defer = function(f, ...) return f(...) end }
typeof = typeof or function(v) return type(v) end

-- module graph: refs look like { __path = "..." } and resolve through require
local ROOT = M.ROOT or ""
local function ref(path) return { __path = path } end
local function folder(path)
	return setmetatable({ __dir = path }, { __index = function(t, name)
		if name == "Parent" then
			local parent = path:match("^(.*)/[^/]+$") or ""
			return folder(parent)
		end
		local f = io.open(path .. "/" .. name .. ".lua", "r")
		if f then f:close() return ref(path .. "/" .. name .. ".lua") end
		return folder(path .. "/" .. name)
	end })
end
M.folder = folder

local cache = {}
local origRequire = require
function require(target)
	if type(target) == "string" then return origRequire(target) end
	local path = target.__path
	if not path then error("cannot require folder " .. tostring(target.__dir)) end
	if cache[path] then return cache[path] end
	local chunk = assert(loadfile(path))
	-- give the module its own `script`
	local prevScript = script
	script = folder(path:match("^(.*)/[^/]+$"))
	script.Parent = folder(path:match("^(.*)/[^/]+$"))
	local result = chunk()
	script = prevScript
	cache[path] = result
	return result
end

game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return { Shared = folder(M.SHARED or "src/shared") }
		end
		if name == "RunService" then return { IsServer = function() return true end, IsStudio = function() return true end } end
		return {}
	end,
}
return M
