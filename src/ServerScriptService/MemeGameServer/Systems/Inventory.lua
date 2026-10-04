--[[
	MemeGame • Inventory (ModuleScript)
	ServerScriptService > MemeGameServer > Systems > Inventory

	Inventario de memes ([Id] = cantidad) y los 3 slots de equipamiento.
	Reglas (validadas SIEMPRE aquí, en el servidor):
	  - Solo se equipan memes que el jugador posee.
	  - Un meme ocupa como máximo un slot.
	  - Máximo absoluto: GameConfig.MaxEquipped (3). Nunca 4.
	  - Si un meme deja de poseerse (trade), se libera su slot automáticamente.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local Remotes = require(Shared.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Inventory = {}

local lastCall: { [Player]: number } = {}
local function throttled(player: Player): boolean
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.15 then
		return true
	end
	lastCall[player] = now
	return false
end

function Inventory.Count(player: Player, memeId: string): number
	local data = PlayerData.Get(player)
	return data and data.OwnedMemes[memeId] or 0
end

function Inventory.EquippedCount(data: any): number
	local n = 0
	for slot = 1, GameConfig.MaxEquipped do
		if data.EquippedMemes[slot] ~= "" then
			n += 1
		end
	end
	return n
end

-- Añade cantidad (sin Push; quien llama decide cuándo refrescar).
function Inventory.Add(player: Player, memeId: string, amount: number?): boolean
	local data = PlayerData.Get(player)
	if not data or not MemeCatalog.Get(memeId) then
		return false
	end
	data.OwnedMemes[memeId] = (data.OwnedMemes[memeId] or 0) + (amount or 1)
	return true
end

-- Quita cantidad. Si llega a 0, se borra y se desequipa.
function Inventory.Remove(player: Player, memeId: string, amount: number?): boolean
	local data = PlayerData.Get(player)
	amount = amount or 1
	if not data or (data.OwnedMemes[memeId] or 0) < amount then
		return false
	end
	local left = data.OwnedMemes[memeId] - amount
	data.OwnedMemes[memeId] = left > 0 and left or nil
	if left <= 0 then
		for slot = 1, GameConfig.MaxEquipped do
			if data.EquippedMemes[slot] == memeId then
				data.EquippedMemes[slot] = ""
			end
		end
	end
	return true
end

-- Equipa en el primer slot libre (o en `slot` si se pide y está libre).
function Inventory.Equip(player: Player, memeId: any, slot: any): (boolean, string)
	local data = PlayerData.Get(player)
	if not data then
		return false, "Cargando tus datos... ⏳"
	end
	local meme = MemeCatalog.Get(memeId)
	if not meme then
		return false, "Ese meme no existe 🤨"
	end
	if (data.OwnedMemes[memeId] or 0) <= 0 then
		return false, "No tienes ese meme 🔒"
	end
	if table.find(data.EquippedMemes, memeId) then
		return false, meme.Name .. " ya está equipado"
	end
	if player:GetAttribute("GameState") == "Match" then
		return false, "No puedes cambiar memes durante la partida"
	end
	local target: number? = nil
	if type(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= GameConfig.MaxEquipped then
		if data.EquippedMemes[slot] == "" then
			target = slot
		end
	end
	if not target then
		for i = 1, GameConfig.MaxEquipped do
			if data.EquippedMemes[i] == "" then
				target = i
				break
			end
		end
	end
	if not target or Inventory.EquippedCount(data) >= GameConfig.MaxEquipped then
		return false, ("Máximo de %d memes equipados."):format(GameConfig.MaxEquipped)
	end
	data.EquippedMemes[target] = memeId
	PlayerData.Push(player)
	return true, ("%s %s equipado en el slot %d"):format(meme.Emoji, meme.Name, target)
end

function Inventory.Unequip(player: Player, slot: any): (boolean, string)
	local data = PlayerData.Get(player)
	if not data then
		return false, "Cargando tus datos... ⏳"
	end
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > GameConfig.MaxEquipped then
		return false, "Slot inválido"
	end
	if player:GetAttribute("GameState") == "Match" then
		return false, "No puedes cambiar memes durante la partida"
	end
	local id = data.EquippedMemes[slot]
	if id == "" then
		return false, "Ese slot ya está vacío"
	end
	data.EquippedMemes[slot] = ""
	PlayerData.Push(player)
	local meme = MemeCatalog.Get(id)
	return true, ("%s desequipado"):format(meme and meme.Name or id)
end

function Inventory.Init()
	Remotes.Get("EquipMeme").OnServerInvoke = function(player, memeId, slot)
		if throttled(player) then
			return false, "¡Más despacio! 😅"
		end
		return Inventory.Equip(player, memeId, slot)
	end
	Remotes.Get("UnequipSlot").OnServerInvoke = function(player, slot)
		if throttled(player) then
			return false, "¡Más despacio! 😅"
		end
		return Inventory.Unequip(player, slot)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return Inventory
