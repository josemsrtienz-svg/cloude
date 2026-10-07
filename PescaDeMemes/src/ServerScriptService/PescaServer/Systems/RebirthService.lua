--[[
	PescaDeMemes • RebirthService (ModuleScript)
	ServerScriptService > PescaServer > Systems > RebirthService

	♻️ RENACER (reglas en GameConfig.Rebirth). Remote: Rebirth() → { ok, Rebirths }.
	  Requisitos: tener la caña RequiredRod (Abisal) y GameConfig.RebirthCost(R) MemeCoins; no estar pescando.
	  Pierdes: MemeCoins (también las del cobrador) y cañas (vuelves a la Caña de Palo).
	  Te quedas: memes (mochila y parcela), nivel, mochila-acuario, objetos, índice, misiones.
	  Ganas: +1 renacer → más dinero (BoostService.Money), terraza de la parcela (PlotService) y huecos de objeto.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Rods = require(Root.Config.Rods)
local Remotes = require(Root.Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local GearService = require(script.Parent.GearService)
local FishingService = require(script.Parent.FishingService)
local PlotService = require(script.Parent.PlotService)

local RebirthService = {}

local lastAction: { [Player]: number } = {}

local function fail(err: string): any
	return { ok = false, err = err }
end

local function onRebirth(player: Player): any
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 2 then
		return fail("Más despacio")
	end
	lastAction[player] = now
	local data = PlayerData.Get(player)
	if not data then
		return fail("Cargando datos…")
	end
	if FishingService.IsFishing(player) then
		return fail("Termina de pescar primero")
	end
	local required = Rods.Get(GameConfig.Rebirth.RequiredRod)
	if required and not data.Rods[required.Id] then
		return fail(("Necesitas la %s para renacer"):format(required.Name))
	end
	local cost = GameConfig.RebirthCost(data.Rebirths)
	if data.MemeCoin < cost then
		return fail("No tienes suficientes MemeCoins para renacer")
	end
	-- reinicio: dinero (también el que espera en el cobrador) y cañas
	data.MemeCoin = 0
	PlotService.ClearBank(player)
	data.Rods = { [Rods.List[1].Id] = true }
	data.EquippedRod = Rods.List[1].Id
	data.BrokenRods = {}
	data.Rebirths += 1
	PlayerData.Push(player)
	task.spawn(PlayerData.SaveNow, player)
	-- ventajas nuevas: caña de palo en la mano, terraza de la parcela, huecos de objeto
	GearService.Refresh(player)
	PlotService.Refresh(player)
	player:SetAttribute("ItemSlots", BoostService.ItemSlots(player))
	for _, other in ipairs(Players:GetPlayers()) do
		if other == player then
			continue -- su propio aviso lo pone el panel
		end
		PlayerData.Notify(other, ("♻️ ¡%s ha RENACIDO! (Renacer %d)"):format(player.DisplayName, data.Rebirths), "Success")
	end
	return { ok = true, Rebirths = data.Rebirths }
end

function RebirthService.Init()
	Remotes.Get("Rebirth").OnServerInvoke = onRebirth
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return RebirthService
