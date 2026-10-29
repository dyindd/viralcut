--[[
	Validate.lua  (ServerScriptService.Server.Validate)
	Argument + distance checks used by every remote handler. NEVER trust the client.
]]

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Validate = {}

function Validate.IsNumber(v, min, max)
	if type(v) ~= "number" then return false end
	if v ~= v then return false end -- NaN
	if v == math.huge or v == -math.huge then return false end
	if min and v < min then return false end
	if max and v > max then return false end
	return true
end

function Validate.IsString(v, maxLen)
	return type(v) == "string" and #v <= (maxLen or 64)
end

function Validate.IsVector3(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

-- Character root part if the player is alive
function Validate.GetRoot(player)
	local char = player and player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

-- Is the player within `maxDist` studs of `position` (Vector3 or BasePart)?
function Validate.Near(player, position, maxDist)
	local root = Validate.GetRoot(player)
	if not root then return false end
	if typeof(position) == "Instance" then
		if position:IsA("BasePart") then
			position = position.Position
		elseif position:IsA("Model") and position.PrimaryPart then
			position = position.PrimaryPart.Position
		else
			return false
		end
	end
	if typeof(position) ~= "Vector3" then return false end
	return (root.Position - position).Magnitude <= (maxDist or Config.MaxInteractDistance)
end

return Validate
