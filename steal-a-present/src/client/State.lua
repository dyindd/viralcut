--[[
	State.lua - the client's cache of everything the server told it, plus a tiny signal
	system so UI pieces can react: State.On("Profile", fn), State.Fire("Profile").
]]

local State = {}

State.Profile = nil
State.Base = nil        -- BaseState payload
State.Carry = nil       -- CarryState payload
State.Grinch = nil      -- GrinchState payload
State.Event = nil       -- EventState payload
State.Quests = {}       -- QuestsChanged payload
State.Streak = nil      -- StreakChanged payload

local listeners = {}

function State.On(name, fn)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
	return function()
		local list = listeners[name]
		if not list then return end
		for i, f in ipairs(list) do
			if f == fn then table.remove(list, i) break end
		end
	end
end

function State.Fire(name, ...)
	for _, fn in ipairs(listeners[name] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then warn("[State] listener error for " .. name .. ": " .. tostring(err)) end
	end
end

function State.Set(name, value)
	State[name] = value
	State.Fire(name, value)
end

-- seconds remaining until a server timestamp (from Workspace:GetServerTimeNow())
function State.Remaining(serverTime)
	if not serverTime then return 0 end
	return math.max(0, serverTime - workspace:GetServerTimeNow())
end

return State
