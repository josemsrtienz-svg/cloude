--[[
	PescaDeMemes • EconomyService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > EconomyService

	Ventas y tienda. Todo se valida aquí:
	  SellCatch(id) · SellAll()            vender memes de la mochila-acuario
	  BuyRod(id) · EquipRod(id) · RepairRod(id)
	  BuyAquarium(tier)                    mochila-acuario más grande
	  BuyItem(id)                          consumibles (Sedal Reforzado)
	La parcela (huecos, cobrador e ingresos) vive en PlotService; la caña y la mochila visibles en GearService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local Remotes = require(Root.Shared.Remotes)
local Inventory = require(Root.Shared.Inventory)

local PlayerData = require(script.Parent.PlayerData)
local GearService = require(script.Parent.GearService)
local FishingService = require(script.Parent.FishingService)

local EconomyService = {}

local SELL_ALL_MAX_ORDER = 3 -- "Vender todo" solo vende Común, Poco común y Raro

local lastAction: { [Player]: number } = {}

local function fail(err: string): any
	return { ok = false, err = err }
end

local function rateLimited(player: Player): boolean
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.15 then
		return true
	end
	lastAction[player] = now
	return false
end

-- Envuelve un handler: comprueba datos cargados y límite de frecuencia.
local function handler(fn: (Player, any, ...any) -> any): (Player, ...any) -> any
	return function(player: Player, ...)
		if rateLimited(player) then
			return fail("Más despacio")
		end
		local data = PlayerData.Get(player)
		if not data then
			return fail("Cargando datos…")
		end
		return fn(player, data, ...)
	end
end

local function onSellCatch(player: Player, data: any, catchId: any): any
	if type(catchId) ~= "string" then
		return fail("Captura inválida")
	end
	local c = data.Catches[catchId]
	if not c then
		return fail("No tienes esa captura")
	end
	if Inventory.InPlot(data, catchId) then
		return fail("Recógelo de tu parcela antes de venderlo")
	end
	data.Catches[catchId] = nil
	data.MemeCoin += c.Value
	PlayerData.Push(player)
	return { ok = true, Earned = c.Value }
end

local function onSellAll(player: Player, data: any): any
	local earned, count = 0, 0
	for id, c in pairs(data.Catches) do
		local meme = Memes.Get(c.MemeId)
		local rarity = meme and Memes.Rarities[meme.Rarity]
		if rarity and rarity.Order <= SELL_ALL_MAX_ORDER and not c.Golden and not c.Impossible and not Inventory.InPlot(data, id) then
			data.Catches[id] = nil
			earned += c.Value
			count += 1
		end
	end
	if count == 0 then
		return fail("No hay nada que vender (los épicos, dorados e imposibles se venden a mano)")
	end
	data.MemeCoin += earned
	PlayerData.Push(player)
	return { ok = true, Earned = earned, Count = count }
end

local function onBuyRod(player: Player, data: any, rodId: any): any
	local rod = Rods.Get(rodId)
	if not rod then
		return fail("Esa caña no existe")
	end
	if data.Rods[rod.Id] then
		return fail("Ya tienes esa caña")
	end
	if data.MemeCoin < rod.Price then
		return fail("No tienes suficientes MemeCoins")
	end
	if FishingService.IsFishing(player) then
		return fail("Termina de pescar primero")
	end
	data.MemeCoin -= rod.Price
	data.Rods[rod.Id] = true
	data.EquippedRod = rod.Id
	PlayerData.Push(player)
	GearService.Refresh(player)
	return { ok = true }
end

local function onEquipRod(player: Player, data: any, rodId: any): any
	local rod = Rods.Get(rodId)
	if not rod or not data.Rods[rod.Id] then
		return fail("No tienes esa caña")
	end
	if data.BrokenRods[rod.Id] then
		return fail("Esa caña está rota: repárala primero")
	end
	if FishingService.IsFishing(player) then
		return fail("Termina de pescar primero")
	end
	data.EquippedRod = rod.Id
	PlayerData.Push(player)
	GearService.Refresh(player)
	return { ok = true }
end

local function onRepairRod(player: Player, data: any, rodId: any): any
	local rod = Rods.Get(rodId)
	if not rod or not data.Rods[rod.Id] then
		return fail("No tienes esa caña")
	end
	if not data.BrokenRods[rod.Id] then
		return fail("Esa caña no está rota")
	end
	if data.MemeCoin < rod.RepairCost then
		return fail("No tienes suficientes MemeCoins")
	end
	if FishingService.IsFishing(player) then
		return fail("Termina de pescar primero")
	end
	data.MemeCoin -= rod.RepairCost
	data.BrokenRods[rod.Id] = nil
	data.EquippedRod = rod.Id
	PlayerData.Push(player)
	GearService.Refresh(player)
	return { ok = true }
end

local function onBuyAquarium(player: Player, data: any, tier: any): any
	local aquarium = Rods.GetAquarium(tier)
	if not aquarium then
		return fail("Esa mochila no existe")
	end
	if aquarium.Tier <= data.AquariumTier then
		return fail("Ya tienes una mochila igual o mejor")
	end
	if aquarium.Tier ~= data.AquariumTier + 1 then
		return fail("Compra antes la mochila anterior")
	end
	if data.MemeCoin < aquarium.Price then
		return fail("No tienes suficientes MemeCoins")
	end
	data.MemeCoin -= aquarium.Price
	data.AquariumTier = aquarium.Tier
	PlayerData.Push(player)
	GearService.RefreshPack(player)
	return { ok = true }
end

local function onBuyItem(player: Player, data: any, itemId: any): any
	local item = Rods.GetItem(itemId)
	if not item then
		return fail("Ese objeto no existe")
	end
	if data.MemeCoin < item.Price then
		return fail("No tienes suficientes MemeCoins")
	end
	data.MemeCoin -= item.Price
	data.Items[item.Id] = (data.Items[item.Id] or 0) + 1
	PlayerData.Push(player)
	return { ok = true }
end

function EconomyService.Init()
	Remotes.Get("SellCatch").OnServerInvoke = handler(onSellCatch)
	Remotes.Get("SellAll").OnServerInvoke = handler(onSellAll)
	Remotes.Get("BuyRod").OnServerInvoke = handler(onBuyRod)
	Remotes.Get("EquipRod").OnServerInvoke = handler(onEquipRod)
	Remotes.Get("RepairRod").OnServerInvoke = handler(onRepairRod)
	Remotes.Get("BuyAquarium").OnServerInvoke = handler(onBuyAquarium)
	Remotes.Get("BuyItem").OnServerInvoke = handler(onBuyItem)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return EconomyService
