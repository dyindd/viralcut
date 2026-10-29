--[[
	MonetizationService.lua
	Gamepasses (cached ownership) + developer products with a PROPER ProcessReceipt:
	 - receipt ids are stored in the profile so a product is never granted twice
	 - we only return PurchaseGranted after the profile saved successfully
	Fill in the IDs in Config.Monetization. Anything with Id = 0 is hidden/disabled.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local MonetizationService = {}

local passByid = {}
local productById = {}
for key, pass in pairs(Config.Monetization.Gamepasses) do
	if pass.Id and pass.Id > 0 then passByid[pass.Id] = key end
end
for key, product in pairs(Config.Monetization.Products) do
	if product.Id and product.Id > 0 then productById[product.Id] = key end
end

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

function MonetizationService.ApplyVIPTag(player)
	local char = player.Character
	if not char then return end
	local existing = char:FindFirstChild("VIPTag")
	if not Data().HasGamepass(player, "VIP") then
		if existing then existing:Destroy() end
		return
	end
	if existing then return end
	local head = char:FindFirstChild("Head") or char.PrimaryPart
	if not head then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "VIPTag"
	bb.Size = UDim2.new(0, 120, 0, 36)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Parent = char
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = "👑 VIP"
	tl.TextColor3 = Color3.fromRGB(255, 215, 0)
	tl.TextStrokeTransparency = 0
	tl.Parent = bb
end

local function applyPassEffects(player)
	MonetizationService.ApplyVIPTag(player)
	local plot = Registry.Get("PlotService").GetPlot(player)
	if plot then
		Registry.Get("PlotService").RefreshSlots(plot)
		Registry.Get("PresentService").RecalcIncome(plot)
	end
	Registry.Get("CarryService").ApplySpeed(player)
end

local function refreshGamepasses(player, profile)
	for key, pass in pairs(Config.Monetization.Gamepasses) do
		if pass.Id and pass.Id > 0 and not profile.Gamepasses[key] then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				profile.Gamepasses[key] = true
			end
		end
	end
	applyPassEffects(player)
	Data().Replicate(player)
end

---------------------------------------------------------------------------
-- Products
---------------------------------------------------------------------------
local productHandlers = {
	Cash = function(player, profile, product) Data().AddCash(player, product.Cash) end,
	Snowflakes = function(player, profile, product) Data().AddSnowflakes(player, product.Snowflakes) end,
	LuckPotion = function(player, profile)
		profile.Boosts.LuckUntil = math.max(os.time(), profile.Boosts.LuckUntil or 0) + Config.Luck.PotionDuration
	end,
	Protein = function(player, profile)
		profile.Boosts.ProteinUntil = math.max(os.time(), profile.Boosts.ProteinUntil or 0) + Config.Strength.ProteinDuration
	end,
	LockExtend = function(player, profile)
		profile.Boosts.LockExtendSeconds = (profile.Boosts.LockExtendSeconds or 0) + Config.Lock.ExtendProductSeconds
	end,
	GrinchTurn = function(player) Registry.Get("GrinchService").ForceGrinch(player) end,
}

local function grantProduct(player, profile, key)
	local product = Config.Monetization.Products[key]
	if not product then return false end
	local handler
	if product.Cash then handler = productHandlers.Cash
	elseif product.Snowflakes then handler = productHandlers.Snowflakes
	else handler = productHandlers[key] end
	if not handler then return false end
	handler(player, profile, product)
	Notify().Notify(player, "Purchased " .. product.Name .. "! Thank you!", "success")
	Data().Replicate(player)
	return true
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Data().GetProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receiptInfo.PurchaseId)
	for _, id in ipairs(profile.Receipts) do
		if id == receiptId then
			return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
		end
	end
	local key = productById[receiptInfo.ProductId]
	if not key then
		warn("[Monetization] Unknown product id " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(grantProduct, player, profile, key)
	if not ok then
		warn("[Monetization] grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.Receipts, receiptId)
	while #profile.Receipts > 50 do table.remove(profile.Receipts, 1) end
	if Data().Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- Save failed. The grant + receipt id are in memory, so a retry returns PurchaseGranted
	-- without granting twice; NotProcessedYet makes Roblox retry until a save succeeds.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------------------
-- Prompts
---------------------------------------------------------------------------
local function onPromptPurchase(player, kind, key)
	if not RateLimiter.Check(player, "Default") then return end
	if not Validate.IsString(kind, 16) or not Validate.IsString(key, 32) then return end
	if kind == "Gamepass" then
		local pass = Config.Monetization.Gamepasses[key]
		if pass and pass.Id > 0 then
			if Data().HasGamepass(player, key) then
				Notify().Notify(player, "You already own " .. pass.Name .. "!", "info")
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end
	elseif kind == "Product" then
		local product = Config.Monetization.Products[key]
		if product and product.Id > 0 then
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end
	end
end

function MonetizationService.Init()
	Remotes.Get("PromptPurchase").OnServerEvent:Connect(onPromptPurchase)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end
		local key = passByid[passId]
		local profile = Data().GetProfile(player)
		if key and profile then
			profile.Gamepasses[key] = true
			applyPassEffects(player)
			Data().Replicate(player)
			Notify().Notify(player, "Thanks for buying " .. Config.Monetization.Gamepasses[key].Name .. "!", "success")
		end
	end)
	Data().OnLoaded(function(player, profile)
		task.spawn(refreshGamepasses, player, profile)
	end)
end

function MonetizationService.Start()
	local function hook(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			MonetizationService.ApplyVIPTag(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
end

return MonetizationService
