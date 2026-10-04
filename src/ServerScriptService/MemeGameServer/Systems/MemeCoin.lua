--[[
	MemeGame • MemeCoin (ModuleScript)
	ServerScriptService > MemeGameServer > Systems > MemeCoin

	Única puerta para tocar el saldo de MemeCoin y la XP/nivel. Nunca se confía en el cliente.
	Otros scripts del servidor pueden dar premios con:
	    game.ServerStorage.MemeGameGrant:Fire(player, { MemeCoin = 50, XP = 20 })
]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local Util = require(Shared.Shared.Util)
local PlayerData = require(script.Parent.PlayerData)

local MemeCoin = {}

function MemeCoin.Get(player: Player): number
	local data = PlayerData.Get(player)
	return data and data.MemeCoin or 0
end

function MemeCoin.CanAfford(player: Player, amount: number): boolean
	return MemeCoin.Get(player) >= amount
end

-- Suma MemeCoin (amount > 0). Devuelve true si se aplicó.
function MemeCoin.Add(player: Player, amount: number, push: boolean?): boolean
	local data = PlayerData.Get(player)
	amount = math.floor(tonumber(amount) or 0)
	if not data or amount <= 0 then
		return false
	end
	data.MemeCoin += amount
	data.Stats.MemeCoinEarned += amount
	if push ~= false then
		PlayerData.Push(player)
	end
	return true
end

-- Resta MemeCoin solo si hay saldo suficiente. Devuelve true si se aplicó.
function MemeCoin.Spend(player: Player, amount: number, push: boolean?): boolean
	local data = PlayerData.Get(player)
	amount = math.floor(tonumber(amount) or 0)
	if not data or amount < 0 or data.MemeCoin < amount then
		return false
	end
	data.MemeCoin -= amount
	if push ~= false then
		PlayerData.Push(player)
	end
	return true
end

function MemeCoin.AddXP(player: Player, amount: number, push: boolean?)
	local data = PlayerData.Get(player)
	amount = math.floor(tonumber(amount) or 0)
	if not data or amount <= 0 then
		return
	end
	data.XP += amount
	local leveled = false
	while data.XP >= GameConfig.XPForLevel(data.Level) do
		data.XP -= GameConfig.XPForLevel(data.Level)
		data.Level += 1
		leveled = true
	end
	if leveled then
		PlayerData.Notify(player, ("¡SUBISTE A NIVEL %d! 🎉"):format(data.Level), "Reward")
	end
	if push ~= false then
		PlayerData.Push(player)
	end
end

-- reward = { MemeCoin = n, XP = n }
function MemeCoin.Grant(player: Player, reward: any)
	if type(reward) ~= "table" then
		return
	end
	MemeCoin.Add(player, reward.MemeCoin, false)
	MemeCoin.AddXP(player, reward.XP, false)
	PlayerData.Push(player)
end

function MemeCoin.Describe(reward: any): string
	local parts = {}
	if reward.MemeCoin and reward.MemeCoin > 0 then
		table.insert(parts, ("+%s %s %s"):format(Util.formatNumber(reward.MemeCoin), GameConfig.CurrencyEmoji, GameConfig.CurrencyName))
	end
	if reward.XP and reward.XP > 0 then
		table.insert(parts, ("+%d XP"):format(reward.XP))
	end
	return table.concat(parts, "  ")
end

function MemeCoin.Init()
	local grantEvent = ServerStorage:FindFirstChild("MemeGameGrant") or Instance.new("BindableEvent")
	grantEvent.Name = "MemeGameGrant"
	grantEvent.Parent = ServerStorage
	grantEvent.Event:Connect(MemeCoin.Grant)
end

return MemeCoin
