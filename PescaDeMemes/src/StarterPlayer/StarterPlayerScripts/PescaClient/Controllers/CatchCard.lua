--[[
	PescaDeMemes • CatchCard (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > CatchCard

	Tarjeta de resultados al subir de una inmersión: una ficha por meme pescado con su FIGURA 3D,
	nombre, rareza, kg, tamaño, valor e insignias (¡NUEVO!, DORADO, IMPOSIBLE).
	Los memes ya están en tu mochila-acuario: cada ficha tiene "💰" para venderlo ya (lo valida el servidor).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Memes = require(Root.Config.Memes)
local Weather = require(Root.Config.Weather)
local FishMath = require(Root.Shared.FishMath)
local Util = require(Root.Shared.Util)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)

local T = UIKit.Theme
local CatchCard = {}
CatchCard.Closed = Util.Signal()

local gui: ScreenGui
local current: Frame? = nil

local function close()
	if current then
		local card = current
		current = nil
		UIKit.tween(card, 0.2, { Position = UDim2.fromScale(0.5, 1.4) })
		task.delay(0.25, function()
			card:Destroy()
		end)
		CatchCard.Closed:Fire()
	end
end

local function badge(parent: Instance, text: string, color: Color3, order: number)
	local b = UIKit.new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(78, 20), BackgroundColor3 = color, Parent = parent })
	UIKit.corner(b, 10)
	UIKit.stroke(b, 2)
	UIKit.label({ Text = text, Size = UDim2.new(1, -6, 1, -2), Position = UDim2.fromOffset(3, 1), Font = T.FontTitle, Parent = b }, { MaxSize = 13 })
end

local function tile(parent: Instance, catch: any, isNew: boolean, order: number)
	local meme = Memes.Get(catch.MemeId)
	local rarity = Memes.GetRarity(catch.MemeId)
	local sizeName = meme and FishMath.SizeOf(meme, catch.Weight) or "?"
	local frame = UIKit.new("Frame", { LayoutOrder = order, BackgroundColor3 = T.PanelLight, Parent = parent })
	UIKit.corner(frame, 14)
	UIKit.stroke(frame, 4, if catch.Golden then T.Coin else rarity.Color)
	local icon = UIKit.memeIcon(catch.MemeId, { Size = UDim2.new(1, -16, 0, 120), Position = UDim2.fromOffset(8, 8), Parent = frame },
		{ Golden = catch.Golden, Mutation = catch.Mutation, Spin = 1 })
	UIKit.pop(icon, 0.4)
	local badges = UIKit.new("Frame", { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 12), BackgroundTransparency = 1,
		ZIndex = 3, Parent = frame })
	UIKit.list(badges, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left)
	if isNew then
		badge(badges, "¡NUEVO!", T.Success, 1)
	end
	if catch.Golden then
		badge(badges, "DORADO ×3", T.Coin, 2)
	end
	local mutation = Weather.GetMutation(catch.Mutation)
	if mutation then
		badge(badges, ("%s %s ×%d"):format(mutation.Emoji, mutation.Name, mutation.Multiplier), mutation.Color, 2)
	end
	if catch.Impossible then
		badge(badges, "🏆 IMPOSIBLE", T.Secondary, 3)
	end
	UIKit.label({ Text = meme and meme.Name or "?", Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 132), Font = T.FontTitle,
		TextColor3 = if catch.Golden then T.Coin else T.Text, Parent = frame }, { Stroke = 2, MaxSize = 20 })
	UIKit.label({ Text = rarity.Name, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 156), Font = T.Font,
		TextColor3 = rarity.Color, Parent = frame }, { Stroke = 2, MaxSize = 16 })
	UIKit.label({ Text = ("⚖️ %s · %s"):format(FishMath.FormatWeight(catch.Weight), sizeName), Size = UDim2.new(1, -10, 0, 18),
		Position = UDim2.fromOffset(5, 176), Font = T.Font, Parent = frame }, { MaxSize = 16 })
	if catch.Sold then
		-- no cabía en la mochila: el servidor ya lo vendió solo
		UIKit.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -16, 0, 30),
			Text = if catch.AutoSold then "VENDIDO (auto)" else "VENDIDO (no cabía)", Font = T.FontTitle, TextColor3 = T.Coin, Parent = frame }, { Stroke = 2, MaxSize = 16 })
		return
	end
	local sell = UIKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 36),
		Parent = frame }, { Color = T.Primary, Text = "💰 " .. Util.formatShort(catch.Value), TextSize = 20 })
	local busy = false
	sell.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local r = State.Call("SellCatch", catch.Id)
		busy = false
		if r.ok then
			HUD.Toast(("💰 +%s MemeCoins"):format(Util.formatShort(r.Earned or catch.Value)), "Success")
			UIKit.playSound("Coins")
			sell.Visible = false
			UIKit.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -16, 0, 30),
				Text = "VENDIDO", Font = T.FontTitle, TextColor3 = T.Success, Parent = frame }, { Stroke = 2, MaxSize = 22 })
		else
			HUD.Toast(r.err or "No se pudo vender", "Error")
		end
	end)
end

-- summary = respuesta de Surface: { Catches, NewIds, XP, LevelUp }
function CatchCard.ShowResults(summary: any)
	close()
	local catches = summary.Catches or {}
	if #catches == 0 then
		return
	end
	local newSet = {}
	for _, id in ipairs(summary.NewIds or {}) do
		newSet[id] = true
	end
	local cols = math.min(#catches, 4)
	local rows = math.ceil(#catches / 4)
	local width = math.max(420, cols * 170 + 40)
	local height = 150 + rows * 260
	local card = UIKit.new("Frame", { Name = "CatchCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1.4),
		Size = UDim2.fromOffset(width, height), BackgroundColor3 = T.Panel, Parent = gui })
	current = card
	UIKit.corner(card, 22)
	UIKit.stroke(card, 5, T.Primary)
	UIKit.responsive(card)
	UIKit.gradient(card, { T.PanelLight, T.PanelDark }, 90)

	UIKit.label({ Text = ("¡%d MEME%s PESCADO%s!"):format(#catches, if #catches == 1 then "" else "S", if #catches == 1 then "" else "S"),
		Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 10), Font = T.FontTitle, TextColor3 = T.Primary, Parent = card },
		{ Stroke = 3, MaxSize = 40 })
	local grid = UIKit.new("Frame", { Size = UDim2.new(1, -24, 0, rows * 260), Position = UDim2.fromOffset(12, 60), BackgroundTransparency = 1, Parent = card })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 250), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	-- primero lo más valioso
	local sorted = table.clone(catches)
	table.sort(sorted, function(a, b)
		return a.Value > b.Value
	end)
	local total = 0
	for i, catch in ipairs(sorted) do
		total += catch.Value
		-- "¡NUEVO!" solo en la primera ficha de cada meme nuevo
		tile(grid, catch, newSet[catch.MemeId] == true, i)
		newSet[catch.MemeId] = nil
	end
	UIKit.label({ Text = ("Valor total: 🪙 %s   ·   +%d XP"):format(Util.formatShort(total), summary.XP or 0), AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -230, 0, 30), Position = UDim2.new(0, 16, 1, -24), Font = T.Font, TextColor3 = T.Coin,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { MaxSize = 24 })
	local ok = UIKit.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -12), Size = UDim2.fromOffset(200, 56),
		Parent = card }, { Color = T.Accent, Text = "🐠 ¡Al acuario!", TextSize = 24 })
	ok.Activated:Connect(close)

	UIKit.tween(card, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	-- celebración según lo MEJOR del lanzamiento (rareza, dorado, meme nuevo)
	local best, bestColor, golden = 1, nil, false
	for _, c in ipairs(catches) do
		-- un ⚡ o 🌙 se celebra como mínimo como un épico / mítico (con el color de la mutación)
		local rarity = Memes.GetRarity(c.MemeId)
		local order, color = rarity.Order, rarity.Color
		if c.Mutation == "Electric" and order < 4 then
			order, color = 4, Weather.Mutations.Electric.Color
		elseif c.Mutation == "Lunar" and order < 5 then
			order, color = 5, Weather.Mutations.Lunar.Color
		end
		if order > best then
			best, bestColor = order, color
		end
		golden = golden or c.Golden == true or c.Mutation ~= nil
	end
	UIKit.celebrate(best, bestColor, golden, #(summary.NewIds or {}) > 0)

end

function CatchCard.IsOpen(): boolean
	return current ~= nil
end

function CatchCard.Init()
	gui = UIKit.new("ScreenGui", { Name = "PescaCatchCard", ResetOnSpawn = false, DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
end

return CatchCard
