-- Roblox value types for the headless test engine: Vector3, Vector2, CFrame, Color3, UDim(2),
-- NumberRange/Sequence, ColorSequence, TweenInfo, RaycastParams, Random, Enum, typeof.
-- Precision is "good enough for logic tests", not a physics engine.

local sqrt, sin, cos = math.sqrt, math.sin, math.cos

---------------------------------------------------------------- Vector3
local V3 = { __typeof = "Vector3" }
local V3m = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__index = function(t, k)
	if k == "Magnitude" then return sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then return v3(0, 0, 0) end
		return v3(t.X / m, t.Y / m, t.Z / m)
	end
	return V3m[k]
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z) end
function V3m:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function V3m:Cross(b) return v3(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X) end
function V3m:Lerp(b, a) return v3(self.X + (b.X - self.X) * a, self.Y + (b.Y - self.Y) * a, self.Z + (b.Z - self.Z) * a) end
function V3m:FuzzyEq(b, eps) eps = eps or 1e-5 return (self - b).Magnitude <= eps end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

---------------------------------------------------------------- Vector2
local V2 = { __typeof = "Vector2" }
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__index = function(t, k)
	if k == "Magnitude" then return sqrt(t.X * t.X + t.Y * t.Y) end
	if k == "Unit" then local m = sqrt(t.X * t.X + t.Y * t.Y) if m == 0 then return v2(0, 0) end return v2(t.X / m, t.Y / m) end
	return nil
end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b) if type(a) == "number" then return v2(a * b.X, a * b.Y) elseif type(b) == "number" then return v2(a.X * b, a.Y * b) end return v2(a.X * b.X, a.Y * b.Y) end
V2.__div = function(a, b) if type(b) == "number" then return v2(a.X / b, a.Y / b) end return v2(a.X / b.X, a.Y / b.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__tostring = function(a) return string.format("%.2f, %.2f", a.X, a.Y) end
Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1) }

---------------------------------------------------------------- CFrame (3x3 rotation, row-major r[1..9])
local CF = { __typeof = "CFrame" }
local CFm = {}
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function cfnew(x, y, z, r) return setmetatable({ _x = x or 0, _y = y or 0, _z = z or 0, _r = r or IDENT }, CF) end
local function mulR(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function mulRV(r, v) return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z) end
local function transpose(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
CF.__index = function(t, k)
	if k == "Position" or k == "p" then return v3(t._x, t._y, t._z) end
	if k == "X" then return t._x elseif k == "Y" then return t._y elseif k == "Z" then return t._z end
	local r = t._r
	if k == "LookVector" then return v3(-r[3], -r[6], -r[9]) end
	if k == "RightVector" then return v3(r[1], r[4], r[7]) end
	if k == "UpVector" then return v3(r[2], r[5], r[8]) end
	if k == "Rotation" then return cfnew(0, 0, 0, r) end
	return CFm[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		local p = mulRV(a._r, b)
		return v3(a._x + p.X, a._y + p.Y, a._z + p.Z)
	end
	local p = mulRV(a._r, v3(b._x, b._y, b._z))
	return cfnew(a._x + p.X, a._y + p.Y, a._z + p.Z, mulR(a._r, b._r))
end
CF.__add = function(a, v) return cfnew(a._x + v.X, a._y + v.Y, a._z + v.Z, a._r) end
CF.__sub = function(a, v) return cfnew(a._x - v.X, a._y - v.Y, a._z - v.Z, a._r) end
CF.__tostring = function(a) return string.format("CFrame(%.2f, %.2f, %.2f)", a._x, a._y, a._z) end
CF.__eq = function(a, b)
	if a._x ~= b._x or a._y ~= b._y or a._z ~= b._z then return false end
	for i = 1, 9 do if a._r[i] ~= b._r[i] then return false end end
	return true
end
function CFm:Inverse()
	local rt = transpose(self._r)
	local p = mulRV(rt, v3(self._x, self._y, self._z))
	return cfnew(-p.X, -p.Y, -p.Z, rt)
end
function CFm:ToWorldSpace(other) return self * other end
function CFm:ToObjectSpace(other) return self:Inverse() * other end
function CFm:PointToWorldSpace(v) return self * v end
function CFm:VectorToWorldSpace(v) return mulRV(self._r, v) end
function CFm:Lerp(other, a) return cfnew(self._x + (other._x - self._x) * a, self._y + (other._y - self._y) * a, self._z + (other._z - self._z) * a, a < 0.5 and self._r or other._r) end
function CFm:GetComponents() local r = self._r return self._x, self._y, self._z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end
local function angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cfnew(0, 0, 0, mulR(mulR(Rx, Ry), Rz))
end
local function lookAt(pos, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - pos)
	if look.Magnitude < 1e-6 then return cfnew(pos.X, pos.Y, pos.Z) end
	look = look.Unit
	if math.abs(look:Dot(up)) > 0.999 then up = v3(0, 0, 1) end
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look)
	return cfnew(pos.X, pos.Y, pos.Z, { right.X, up2.X, -look.X, right.Y, up2.Y, -look.Y, right.Z, up2.Z, -look.Z })
end
CFrame = {
	new = function(a, b, c)
		if a == nil then return cfnew() end
		if getmetatable(a) == V3 then
			if b and getmetatable(b) == V3 then return lookAt(a, b) end
			return cfnew(a.X, a.Y, a.Z)
		end
		return cfnew(a, b, c)
	end,
	Angles = angles, fromEulerAnglesXYZ = angles,
	fromEulerAnglesYXZ = function(rx, ry, rz)
		local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
		local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
		local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
		local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
		return cfnew(0, 0, 0, mulR(mulR(Ry, Rx), Rz))
	end,
	lookAt = lookAt,
	identity = cfnew(),
	fromMatrix = function(pos, vx, vy, vz)
		vz = vz or vx:Cross(vy)
		return cfnew(pos.X, pos.Y, pos.Z, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
	end,
}

---------------------------------------------------------------- Color3
local C3 = { __typeof = "Color3" }
local C3m = {}
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
C3.__index = C3m
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3.__tostring = function(a) return string.format("Color3(%.2f, %.2f, %.2f)", a.R, a.G, a.B) end
function C3m:Lerp(b, a) return c3(self.R + (b.R - self.R) * a, self.G + (b.G - self.G) * a, self.B + (b.B - self.B) * a) end
function C3m:ToHSV() return 0, 0, math.max(self.R, self.G, self.B) end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6) local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i = i % 6
		if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
		elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) else return c3(v, p, q) end
	end,
	fromHex = function() return c3(1, 1, 1) end,
}

---------------------------------------------------------------- UDim / UDim2
local UD = { __typeof = "UDim" }
UD.__index = UD
UD.__add = function(a, b) return setmetatable({ Scale = a.Scale + b.Scale, Offset = a.Offset + b.Offset }, UD) end
UD.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
UDim = { new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end }
local UD2 = { __typeof = "UDim2" }
UD2.__index = function(t, k) if k == "Width" then return t.X elseif k == "Height" then return t.Y end return nil end
UD2.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, UD2) end
UD2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
UD2.__tostring = function(a) return string.format("{%s, %s}, {%s, %s}", a.X.Scale, a.X.Offset, a.Y.Scale, a.Y.Offset) end
UDim2 = {
	new = function(xs, xo, ys, yo) return setmetatable({ X = UDim.new(xs or 0, xo or 0), Y = UDim.new(ys or 0, yo or 0) }, UD2) end,
	fromScale = function(x, y) return setmetatable({ X = UDim.new(x, 0), Y = UDim.new(y, 0) }, UD2) end,
	fromOffset = function(x, y) return setmetatable({ X = UDim.new(0, x), Y = UDim.new(0, y) }, UD2) end,
}

---------------------------------------------------------------- sequences / ranges / misc
local function simple(typeofName, fields)
	local mt = { __typeof = typeofName }
	mt.__index = mt
	return function(...)
		local args = { ... }
		local t = setmetatable({}, mt)
		for i, f in ipairs(fields) do t[f] = args[i] end
		return t
	end
end
NumberRange = { new = function(a, b) return setmetatable({ Min = a, Max = b or a }, { __typeof = "NumberRange" }) end }
NumberSequenceKeypoint = { new = simple("NumberSequenceKeypoint", { "Time", "Value", "Envelope" }) }
ColorSequenceKeypoint = { new = simple("ColorSequenceKeypoint", { "Time", "Value" }) }
NumberSequence = { new = function(a, b)
	local kps
	if type(a) == "number" then kps = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } else kps = a end
	return setmetatable({ Keypoints = kps }, { __typeof = "NumberSequence" })
end }
ColorSequence = { new = function(a, b)
	local kps
	if getmetatable(a) == C3 then kps = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } else kps = a end
	return setmetatable({ Keypoints = kps }, { __typeof = "ColorSequence" })
end }
TweenInfo = { new = function(t, style, dir, rep, rev, delay) return setmetatable({ Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0 }, { __typeof = "TweenInfo" }) end }
RaycastParams = { new = function() return setmetatable({ FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false, RespectCanCollide = false }, { __typeof = "RaycastParams" }) end }
BrickColor = { new = function(n) return setmetatable({ Name = n, Color = c3(0.5, 0.5, 0.5) }, { __typeof = "BrickColor" }) end }
Rect = { new = function(a, b, c, d) return setmetatable({ Min = v2(a, b), Max = v2(c, d) }, { __typeof = "Rect" }) end }
PhysicalProperties = { new = function(...) return setmetatable({ ... }, { __typeof = "PhysicalProperties" }) end }

---------------------------------------------------------------- Random
local RND = { __typeof = "Random" }
RND.__index = RND
function RND:NextNumber(a, b) if a == nil then return math.random() end return a + math.random() * (b - a) end
function RND:NextInteger(a, b) return math.random(a, b) end
function RND:Shuffle(t) for i = #t, 2, -1 do local j = math.random(1, i) t[i], t[j] = t[j], t[i] end end
function RND:NextUnitVector() return v3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit end
Random = { new = function(seed) return setmetatable({ Seed = seed }, RND) end }

---------------------------------------------------------------- Enum
local enumItemMT = { __typeof = "EnumItem", __tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end }
enumItemMT.__index = enumItemMT
local enumCache = {}
Enum = setmetatable({}, { __index = function(t, enumName)
	local items = {}
	local e = setmetatable({}, {
		__index = function(_, item)
			if item == "GetEnumItems" then
				return function() local out = {} for _, v in pairs(items) do table.insert(out, v) end return out end
			end
			local key = enumName .. "." .. item
			local obj = enumCache[key]
			if not obj then
				obj = setmetatable({ Name = item, EnumType = enumName, Value = 0 }, enumItemMT)
				enumCache[key] = obj
				items[item] = obj
			end
			return obj
		end,
		__tostring = function() return "Enum." .. enumName end,
	})
	rawset(t, enumName, e)
	return e
end })

---------------------------------------------------------------- typeof / polyfills
function typeof(v)
	local t = type(v)
	if t ~= "table" then return t end
	local mt = getmetatable(v)
	if mt then
		if mt.__typeof then return mt.__typeof end
		if mt.__isInstance then return "Instance" end
	end
	return "table"
end
-- Luau has these; Lua 5.4+ does not
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
math.pow = math.pow or function(a, b) return a ^ b end
math.noise = math.noise or function() return 0 end
unpack = unpack or table.unpack
math.clamp = math.clamp or function(n, lo, hi) if n < lo then return lo elseif n > hi then return hi end return n end
math.round = math.round or function(n) return math.floor(n + 0.5) end
math.sign = math.sign or function(n) return n > 0 and 1 or n < 0 and -1 or 0 end
table.find = table.find or function(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end return nil end
table.create = table.create or function(n, v) local t = {} for i = 1, n do t[i] = v end return t end
table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
string.split = string.split or function(s, sep) local out = {} for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do table.insert(out, piece) end return out end
