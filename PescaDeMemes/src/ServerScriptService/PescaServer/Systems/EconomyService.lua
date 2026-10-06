--[[
	PescaDeMemes • EconomyService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > EconomyService

	Mochila, acuario y tienda. Todo se valida aquí:
	  SellCatch(id) · SellAll() · PlaceInAquarium(id) · RemoveFromAquarium(slot)
	  BuyRod(id) · EquipRod(id) · BuyItem(id)
	El acuario genera MemeCoins cada pocos segundos (y mientras no estás, a la mitad y con tope).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local Remotes = require(Root.Shared.Remotes)
local Util = require(Root.Shared.Util)

local PlayerData = require(script.Parent.PlayerData)
local FishingService = require(script.Parent.FishingService)

local EconomyService = {}

local INCOME_TICK = 5 -- segundos
local SELL_ALL_MAX_ORDER = 3 -- "Vender todo" solo vende Común, Poco común y Raro

local lastAction: { [Player]: number } = {}
local incomeRemainder: { [Player]: number } = {}

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

local function aquariumSlotOf(data: any, catchId: string): number?
	return table.find(data.Aquarium, catchId)
end

function EconomyService.IncomePerMinute(data: any): number
	local total = 0
	for _, id in ipairs(data.Aquarium) do
		local c = id ~= "" and data.Catches[id]
		if c then
			total += c.Value
		end
	end
	return total * GameConfig.AquariumIncomeRate
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
	if aquariumSlotOf(data, catchId) then
		return fail("Sácalo del acuario antes de venderlo")
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
		if rarity and rarity.Order <= SELL_ALL_MAX_ORDER and not c.Golden and not c.Impossible and not aquariumSlotOf(data, id) then
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

local function onPlace(player: Player, data: any, catchId: any): any
	if type(catchId) ~= "string" or not data.Catches[catchId] then
		return fail("No tienes esa captura")
	end
	if aquariumSlotOf(data, catchId) then
		return fail("Ya está en el acuario")
	end
	local slot = table.find(data.Aquarium, "")
	if not slot then
		return fail("🐠 Acuario lleno: saca alguno primero")
	end
	data.Aquarium[slot] = catchId
	PlayerData.Push(player)
	return { ok = true, Slot = slot }
end

local function onRemove(player: Player, data: any, slot: any): any
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > GameConfig.AquariumSlots then
		return fail("Hueco inválido")
	end
	if data.Aquarium[slot] == "" then
		return fail("Ese hueco está vacío")
	end
	local backpack = 0
	for id in pairs(data.Catches) do
		if not aquariumSlotOf(data, id) then
			backpack += 1
		end
	end
	if backpack >= GameConfig.MaxBackpack then
		return fail("🎒 Mochila llena: vende algo antes de sacarlo")
	end
	data.Aquarium[slot] = ""
	PlayerData.Push(player)
	return { ok = true }
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
	data.MemeCoin -= rod.Price
	data.Rods[rod.Id] = true
	data.EquippedRod = rod.Id
	PlayerData.Push(player)
	FishingService.RefreshRod(player)
	return { ok = true }
end

local function onEquipRod(player: Player, data: any, rodId: any): any
	local rod = Rods.Get(rodId)
	if not rod or not data.Rods[rod.Id] then
		return fail("No tienes esa caña")
	end
	data.EquippedRod = rod.Id
	PlayerData.Push(player)
	FishingService.RefreshRod(player)
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

local function grantOffline(player: Player, data: any)
	local now = os.time()
	if data.LastSeen > 0 then
		local elapsed = math.clamp(now - data.LastSeen, 0, GameConfig.OfflineCapHours * 3600)
		local earned = math.floor(EconomyService.IncomePerMinute(data) * GameConfig.OfflineIncomeMultiplier * elapsed / 60)
		if earned > 0 then
			data.MemeCoin += earned
			PlayerData.Push(player)
			PlayerData.Notify(player, ("🐠 Tu acuario ganó %s 🪙 mientras no estabas"):format(Util.formatNumber(earned)), "Success")
		end
	end
	data.LastSeen = now
end

function EconomyService.Init()
	Remotes.Get("SellCatch").OnServerInvoke = handler(onSellCatch)
	Remotes.Get("SellAll").OnServerInvoke = handler(onSellAll)
	Remotes.Get("PlaceInAquarium").OnServerInvoke = handler(onPlace)
	Remotes.Get("RemoveFromAquarium").OnServerInvoke = handler(onRemove)
	Remotes.Get("BuyRod").OnServerInvoke = handler(onBuyRod)
	Remotes.Get("EquipRod").OnServerInvoke = handler(onEquipRod)
	Remotes.Get("BuyItem").OnServerInvoke = handler(onBuyItem)

	PlayerData.Loaded:Connect(grantOffline)
	Players.PlayerRemoving:Connect(function(player)
		local data = PlayerData.Get(player)
		if data then
			data.LastSeen = os.time()
		end
		lastAction[player] = nil
		incomeRemainder[player] = nil
	end)

	-- ingresos del acuario en directo
	task.spawn(function()
		while true do
			task.wait(INCOME_TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data then
					local amount = EconomyService.IncomePerMinute(data) * INCOME_TICK / 60 + (incomeRemainder[player] or 0)
					local whole = math.floor(amount)
					incomeRemainder[player] = amount - whole
					data.LastSeen = os.time()
					if whole > 0 then
						data.MemeCoin += whole
						PlayerData.Push(player)
					end
				end
			end
		end
	end)
end

return EconomyService
