--[[
	Registry.lua  (ServerScriptService.Server.Registry)
	Service locator so services can talk to each other without circular requires.
	Main.server.lua registers every service; services call Registry.Get("Name") at CALL time.
]]

local Registry = {}
local services = {}

function Registry.Register(name, service)
	services[name] = service
end

function Registry.Get(name)
	local s = services[name]
	if not s then
		error("Service not registered: " .. tostring(name))
	end
	return s
end

function Registry.All()
	return services
end

return Registry
