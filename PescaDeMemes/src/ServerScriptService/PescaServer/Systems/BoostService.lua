--[[
	PescaDeMemes • BoostService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > BoostService

	Multiplicadores del jugador: boosts temporales (Config/Boosts) y Game Passes (Config/Monetization).
	  BoostService.Money(player)      → multiplicador de dinero (ventas y parcela)
	  BoostService.Luck(player)       → multiplicador de suerte (inmersión)
	  BoostService.ExtraHooks(player) → anzuelos extra
	Los boosts activos se guardan en data.Boosts = { [id] = os.time() en que caducan }.
	BOOST GRATIS: cada jugador tiene su propio reloj aleatorio; cuando toca, el atributo "FreeBoost" dice cuál
	es y hay que ir a la TIENDA FÍSICA a recogerlo (ClaimFreeBoost). Comprar boosts también exige estar allí.
	Atributos para el cliente: FreeBoost (string) · FreeBoostUntil (os.time) · Pass_<Key> (bool).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Boosts = require(Root.Config.Boosts)
local Monetization = require(Root.Config.Monetization)
local Remotes = require(Root.Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local BoostService = {}

local passes: { [Player]: { [string]: boolean } } = {}
local nextFree: { [Player]: number } = {}
local lastAction: { [Player]: number } = {}
local rng = Random.new()

local function fail(err: string): any
	return { ok = false, err = err }
end

local function active(player: Player, id: string): boolean
	local data = PlayerData.Get(player)
	local untilTime = data and data.Boosts and data.Boosts[id]
	return type(untilTime) == "number" and untilTime > os.time()
end

local function passValue(player: Player, field: string, default: number, combine: (number, number) -> number): number
	local owned = passes[player]
	local value = default
	if owned then
		for _, pass in ipairs(Monetization.GamePasses) do
			if owned[pass.Key] and pass[field] then
				value = combine(value, pass[field])
			end
		end
	end
	return value
end

local function mul(a: number, b: number): number
	return a * b
end
local function add(a: number, b: number): number
	return a + b
end

function BoostService.Money(player: Player): number
	local boost = if active(player, "Money") then Boosts.List.Money.Multiplier else 1
	return boost * passValue(player, "MoneyMultiplier", 1, mul)
end

function BoostService.Luck(player: Player): number
	local boost = if active(player, "Luck") then Boosts.List.Luck.Multiplier else 1
	return boost * passValue(player, "LuckMultiplier", 1, mul)
end

function BoostService.ExtraHooks(player: Player): number
	return passValue(player, "ExtraHooks", 0, add)
end

-- Suma `seconds` al boost (si ya estaba activo, se alarga).
function BoostService.Grant(player: Player, id: string, seconds: number)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local now = os.time()
	local current = data.Boosts[id]
	data.Boosts[id] = math.max(now, if type(current) == "number" then current else 0) + seconds
	PlayerData.Push(player)
end

-- ¿Está el jugador junto al mostrador de la tienda física?
local function nearShop(player: Player): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local map = Workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local shop = hub and hub:FindFirstChild("Shop")
	local counter = shop and shop:FindFirstChild("Counter") :: BasePart?
	if not hrp or not counter then
		return false
	end
	return (hrp.Position - counter.Position).Magnitude <= Boosts.ShopRange
end

local function rateLimited(player: Player): boolean
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.3 then
		return true
	end
	lastAction[player] = now
	return false
end

local function scheduleFree(player: Player)
	nextFree[player] = os.time() + rng:NextInteger(Boosts.Free.MinDelay, Boosts.Free.MaxDelay)
	player:SetAttribute("FreeBoost", nil)
	player:SetAttribute("FreeBoostUntil", nil)
end

-- ===== Remotes =====

local function onBuyBoost(player: Player, id: any): any
	if rateLimited(player) then
		return fail("Más despacio")
	end
	local boost = Boosts.Get(id)
	local data = PlayerData.Get(player)
	if not boost or not data then
		return fail("Boost inválido")
	end
	if not nearShop(player) then
		return fail("🛒 Los boosts se compran en la TIENDA (entrada del mapa)")
	end
	if data.MemeCoin < boost.Price then
		return fail("No tienes suficientes MemeCoins")
	end
	data.MemeCoin -= boost.Price
	BoostService.Grant(player, boost.Id, boost.Duration)
	return { ok = true }
end

local function onClaimFree(player: Player): any
	if rateLimited(player) then
		return fail("Más despacio")
	end
	local id = player:GetAttribute("FreeBoost")
	local claimUntil = player:GetAttribute("FreeBoostUntil")
	local boost = Boosts.Get(id)
	if not boost then
		return fail("Ahora mismo no tienes ningún boost gratis")
	end
	if type(claimUntil) ~= "number" or os.time() > claimUntil then
		scheduleFree(player)
		return fail("Ese boost gratis ya caducó. ¡Saldrá otro!")
	end
	if not nearShop(player) then
		return fail("🛒 Ve a la TIENDA para recogerlo")
	end
	BoostService.Grant(player, boost.Id, boost.Duration)
	scheduleFree(player)
	return { ok = true, Name = boost.Name }
end

-- ===== Game Passes =====

local function refreshPasses(player: Player)
	local owned = passes[player] or {}
	passes[player] = owned
	for _, pass in ipairs(Monetization.GamePasses) do
		if pass.Id > 0 and not owned[pass.Key] then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				owned[pass.Key] = true
			end
		end
		player:SetAttribute("Pass_" .. pass.Key, owned[pass.Key] == true)
	end
end

function BoostService.Init()
	Remotes.Get("BuyBoost").OnServerInvoke = onBuyBoost
	Remotes.Get("ClaimFreeBoost").OnServerInvoke = onClaimFree

	local function onPlayer(player: Player)
		scheduleFree(player)
		task.spawn(refreshPasses, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
		nextFree[player] = nil
		lastAction[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in ipairs(Monetization.GamePasses) do
			if pass.Id == passId then
				passes[player] = passes[player] or {}
				passes[player][pass.Key] = true
				player:SetAttribute("Pass_" .. pass.Key, true)
				PlayerData.Notify(player, ("%s ¡Gracias! %s activado"):format(pass.Emoji, pass.Name), "Success")
			end
		end
	end)

	-- reloj del boost gratis de cada jugador
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local pending = player:GetAttribute("FreeBoost")
				local claimUntil = player:GetAttribute("FreeBoostUntil")
				if pending then
					if type(claimUntil) == "number" and now > claimUntil then
						scheduleFree(player)
					end
				elseif nextFree[player] and now >= nextFree[player] and PlayerData.IsLoaded(player) then
					local id = Boosts.Order[rng:NextInteger(1, #Boosts.Order)]
					local boost = Boosts.List[id]
					player:SetAttribute("FreeBoost", id)
					player:SetAttribute("FreeBoostUntil", now + Boosts.Free.ClaimWindow)
					PlayerData.Notify(player, ("🎁 ¡BOOST GRATIS (%s %s) esperándote en la TIENDA! Tienes 5 min"):format(boost.Emoji, boost.Name), "Success")
				end
			end
		end
	end)
end

return BoostService
