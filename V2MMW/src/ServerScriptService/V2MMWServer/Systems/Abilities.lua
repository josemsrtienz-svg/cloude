--[[
	V2MMW • Abilities (ModuleScript)
	ServerScriptService > V2MMWServer > Systems > Abilities

	Habilidades de la hotbar (slots 1-3). SOLO funcionan durante una partida.
	El servidor valida: que estés en partida, que el slot tenga un meme equipado y el cooldown.
	Son habilidades ficticias de videojuego: velocidad, salto, escudo y dash.
	Para añadir un tipo nuevo, agrégalo en APPLY y úsalo en MemeCatalog (Ability.Type).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local Remotes = require(Shared.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Teleport = require(script.Parent.Teleport)
local MatchService = require(script.Parent.MatchService)

local Abilities = {}

local cooldowns: { [Player]: { [number]: number } } = {}
local buffTokens: { [Player]: number } = {}

local function saveBase(hum: Humanoid)
	if hum:GetAttribute("BaseWalkSpeed") == nil then
		hum:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
		hum:SetAttribute("BaseJumpHeight", hum.JumpHeight)
		hum:SetAttribute("BaseJumpPower", hum.JumpPower)
	end
end

local function endBuffLater(player: Player, duration: number)
	local token = (buffTokens[player] or 0) + 1
	buffTokens[player] = token
	task.delay(duration, function()
		if buffTokens[player] == token and MatchService.IsPlaying(player) then
			Teleport.ResetMovement(player)
		end
	end)
end

local APPLY = {
	Speed = function(player: Player, hum: Humanoid, ability)
		saveBase(hum)
		hum.WalkSpeed = hum:GetAttribute("BaseWalkSpeed") * ability.Power
		endBuffLater(player, ability.Duration)
	end,
	Jump = function(player: Player, hum: Humanoid, ability)
		saveBase(hum)
		hum.JumpHeight = hum:GetAttribute("BaseJumpHeight") * ability.Power
		hum.JumpPower = hum:GetAttribute("BaseJumpPower") * ability.Power
		endBuffLater(player, ability.Duration)
	end,
	Shield = function(player: Player, hum: Humanoid, ability)
		local char = hum.Parent
		local old = char:FindFirstChild("AbilityShield")
		if old then
			old:Destroy()
		end
		local ff = Instance.new("ForceField")
		ff.Name = "AbilityShield"
		ff.Parent = char
		task.delay(ability.Duration, function()
			if ff.Parent then
				ff:Destroy()
			end
		end)
	end,
	Dash = function()
		-- el impulso lo aplica el cliente (es dueño de la física de su personaje);
		-- el servidor solo autoriza y controla el cooldown.
	end,
}

function Abilities.Use(player: Player, slot: any): (boolean, string?, any?)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > GameConfig.MaxEquipped then
		return false, "Slot inválido"
	end
	if not MatchService.IsPlaying(player) then
		return false, "Las habilidades solo funcionan en partida"
	end
	local data = PlayerData.Get(player)
	local memeId = data and data.EquippedMemes[slot]
	local meme = memeId and MemeCatalog.Get(memeId)
	if not meme or not meme.Ability then
		return false, "Ese slot está vacío"
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local now = os.clock()
	cooldowns[player] = cooldowns[player] or {}
	local readyAt = cooldowns[player][slot] or 0
	if now < readyAt then
		return false, ("Recargando... %.1fs"):format(readyAt - now)
	end
	local ability = meme.Ability
	local apply = APPLY[ability.Type]
	if not apply then
		return false, "Habilidad desconocida"
	end
	cooldowns[player][slot] = now + ability.Cooldown
	apply(player, hum, ability)
	return true, ("%s %s!"):format(meme.Emoji, meme.Name), {
		Type = ability.Type, Power = ability.Power, Duration = ability.Duration, Cooldown = ability.Cooldown,
	}
end

function Abilities.Init()
	Remotes.Get("UseAbility").OnServerInvoke = Abilities.Use
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		buffTokens[player] = nil
	end)
end

return Abilities
