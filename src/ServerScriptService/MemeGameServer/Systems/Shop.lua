--[[
	MemeGame • Shop (ModuleScript)
	ServerScriptService > MemeGameServer > Systems > Shop

	MemeMarket: compra de memes con MemeCoin. El precio sale del catálogo del servidor,
	nunca del cliente. Para ampliar la tienda, añade memes con InShop = true en MemeCatalog.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local Remotes = require(Shared.Shared.Remotes)
local Util = require(Shared.Shared.Util)
local PlayerData = require(script.Parent.PlayerData)
local MemeCoin = require(script.Parent.MemeCoin)
local Inventory = require(script.Parent.Inventory)

local Shop = {}

local lastBuy: { [Player]: number } = {}

function Shop.Buy(player: Player, memeId: any): (boolean, string)
	local data = PlayerData.Get(player)
	if not data then
		return false, "Cargando tus datos... ⏳"
	end
	local now = os.clock()
	if lastBuy[player] and now - lastBuy[player] < 0.4 then
		return false, "¡Más despacio! 😅"
	end
	lastBuy[player] = now

	local meme = MemeCatalog.Get(memeId)
	if not meme or not meme.InShop then
		return false, "Ese meme no está a la venta 🤨"
	end
	local price = meme.Value
	if data.MemeCoin < price then
		return false, ("Te faltan %s %s 😭"):format(Util.formatNumber(price - data.MemeCoin), GameConfig.CurrencyName)
	end
	if not MemeCoin.Spend(player, price, false) then
		return false, "No tienes suficientes " .. GameConfig.CurrencyName
	end
	Inventory.Add(player, meme.Id, 1)
	data.Stats.MemesBought += 1
	PlayerData.Push(player)
	return true, ("¡Compraste %s %s! 🎉"):format(meme.Emoji, meme.Name)
end

function Shop.Init()
	Remotes.Get("BuyMeme").OnServerInvoke = Shop.Buy
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)
end

return Shop
