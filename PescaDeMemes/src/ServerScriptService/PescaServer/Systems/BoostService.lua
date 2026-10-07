--[[
	PescaDeMemes • BoostService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > BoostService

	Multiplicadores del jugador: boosts temporales (Config/Boosts) y Game Passes (Config/Monetization).
	  BoostService.Money(player)      → multiplicador de dinero (ventas y parcela)
	  BoostService.Luck(player)       → multiplicador de suerte (inmersión)
	  BoostService.ExtraHooks(player) → anzuelos extra
	  BoostService.Speed(player)      → multiplicador de la bajada del anzuelo
	Los boosts activos se guardan en data.Boosts = { [id] = os.time() en que caducan }.
	BOOST GRATIS DEL TABLÓN: cada 15 min cambia (Boosts.FreeRound, igual para todos). Cada jugador lo recoge
	UNA vez por ronda en la GRAN TIENDA (data.FreeRound guarda la última ronda recogida).
	Comprar boosts también exige estar junto al mostrador. Atributos: Pass_<Key> (bool).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Boosts = require(Root.Config.Boosts)
local Monetization = require(Root.Config.Monetization)
local Rods = require(Root.Config.Rods)
local Remotes = require(Root.Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local BoostService = {}

local passes: { [Player]: { [string]: boolean } } = {}
local lastAction: { [Player]: number } = {}

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
	return passValue(player, "ExtraHooks", 0, add) + (if active(player, "Hook") then 1 else 0)
end

function BoostService.ItemSlots(player: Player): number
	return math.min(Rods.MaxItemSlots, Rods.BaseItemSlots + passValue(player, "ItemSlots", 0, add))
end

-- ¿Lleva este objeto equipado (y cabe en sus huecos)?
function BoostService.HasItem(player: Player, id: string): boolean
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	local slots = BoostService.ItemSlots(player)
	for i, itemId in ipairs(data.EquippedItems) do
		if i > slots then
			break
		end
		if itemId == id then
			return (data.Items[id] or 0) > 0
		end
	end
	return false
end

function BoostService.Speed(player: Player): number
	return if active(player, "Speed") then Boosts.List.Speed.Multiplier else 1
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
	local gift = shop and shop:FindFirstChild("GiftPedestal")
	local pedestal = gift and gift:FindFirstChild("Pedestal") :: BasePart?
	if not hrp then
		return false
	end
	-- vale estar junto al mostrador o junto al regalo del tablón
	for _, spot in ipairs({ counter, pedestal }) do
		if spot and (hrp.Position - spot.Position).Magnitude <= Boosts.ShopRange then
			return true
		end
	end
	return false
end

local function rateLimited(player: Player): boolean
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.3 then
		return true
	end
	lastAction[player] = now
	return false
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
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	local round, boost = Boosts.FreeRound(os.time())
	if data.FreeRound == round then
		return fail("Ya recogiste el boost gratis de esta ronda. ¡Mira el tablón para el siguiente!")
	end
	if not nearShop(player) then
		return fail("🛒 Ve a la GRAN TIENDA para recogerlo")
	end
	data.FreeRound = round
	BoostService.Grant(player, boost.Id, boost.Duration)
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
	player:SetAttribute("ItemSlots", BoostService.ItemSlots(player))
end

function BoostService.Init()
	Remotes.Get("BuyBoost").OnServerInvoke = onBuyBoost
	Remotes.Get("ClaimFreeBoost").OnServerInvoke = onClaimFree

	local function onPlayer(player: Player)
		task.spawn(refreshPasses, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
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
				player:SetAttribute("ItemSlots", BoostService.ItemSlots(player))
				PlayerData.Notify(player, ("%s ¡Gracias! %s activado"):format(pass.Emoji, pass.Name), "Success")
			end
		end
	end)

	-- la ronda actual del tablón la publica el SERVIDOR (atributo de Workspace): así el cliente nunca
	-- dice "disponible" con un reloj distinto. Aviso a todos cuando cambia.
	Workspace:SetAttribute("FreeRound", (Boosts.FreeRound(os.time())))
	task.spawn(function()
		local lastRound = Boosts.FreeRound(os.time())
		while true do
			task.wait(1)
			local round, boost = Boosts.FreeRound(os.time())
			Workspace:SetAttribute("FreeRound", round)
			if round ~= lastRound then
				lastRound = round
				for _, player in ipairs(Players:GetPlayers()) do
					PlayerData.Notify(player, ("🎁 ¡NUEVO boost gratis en el tablón de la GRAN TIENDA: %s %s (5 min)!"):format(boost.Emoji, boost.Name), "Success")
				end
			end
		end
	end)
end

return BoostService
