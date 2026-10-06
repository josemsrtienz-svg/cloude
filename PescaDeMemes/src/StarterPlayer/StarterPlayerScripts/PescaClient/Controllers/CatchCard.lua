--[[
	PescaDeMemes • CatchCard (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > CatchCard

	Tarjeta que aparece al pescar algo: meme, rareza, peso, tamaño, insignias y valor.
	La captura entra sola en tu mochila-acuario. Botones: 🐠 OK · 💰 Vender.
	Si no cabe: 💰 Vender ya · 🌊 Soltar (cada acción la valida el servidor).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Memes = require(Root.Config.Memes)
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
	local b = UIKit.new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(130, 30), BackgroundColor3 = color, Parent = parent })
	UIKit.corner(b, 15)
	UIKit.stroke(b, 2)
	UIKit.label({ Text = text, Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Font = T.FontTitle, Parent = b }, { MaxSize = 18 })
end

-- result = respuesta de FinishFight: { Catch, FirstTime, LevelUp, XP }
function CatchCard.Show(result: any)
	close()
	local catch = result.Catch
	local meme = Memes.Get(catch.MemeId)
	if not meme then
		return
	end
	local rarity = Memes.Rarities[meme.Rarity]
	local sizeName = FishMath.SizeName(FishMath.Fraction(meme, catch.Weight))

	local card = UIKit.new("Frame", {
		Name = "CatchCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1.4),
		Size = UDim2.fromOffset(420, 470), BackgroundColor3 = T.Panel, Parent = gui,
	})
	current = card
	UIKit.corner(card, 22)
	UIKit.stroke(card, 5, if catch.Golden then T.Coin else rarity.Color)
	UIKit.responsive(card)
	UIKit.gradient(card, { T.PanelLight, T.PanelDark }, 90)

	UIKit.label({ Text = "¡PESCADO!", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 10), Font = T.FontTitle,
		TextColor3 = T.Primary, Parent = card }, { Stroke = 3, MaxSize = 40 })

	local icon = UIKit.memeIcon(meme.Id, { Size = UDim2.fromOffset(130, 130), Position = UDim2.new(0.5, -65, 0, 60), Parent = card })
	UIKit.stroke(icon, 4, if catch.Golden then T.Coin else T.Stroke)
	UIKit.pop(icon, 0.3)

	UIKit.label({ Text = (if catch.Golden then "✨ " else "") .. meme.Name, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 196),
		Font = T.FontTitle, TextColor3 = if catch.Golden then T.Coin else T.Text, Parent = card }, { Stroke = 3, MaxSize = 34 })
	UIKit.label({ Text = rarity.Name, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 232), Font = T.Font,
		TextColor3 = rarity.Color, Parent = card }, { Stroke = 2, MaxSize = 22 })
	UIKit.label({ Text = ("⚖️ %s  ·  Tamaño %s  ·  ocupa %d"):format(FishMath.FormatWeight(catch.Weight), sizeName, catch.Size or 0), Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 260), Font = T.Font, Parent = card }, { MaxSize = 22 })

	local badges = UIKit.new("Frame", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 292), BackgroundTransparency = 1, Parent = card })
	UIKit.list(badges, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	if result.FirstTime then
		badge(badges, "¡NUEVO!", T.Success, 1)
	end
	if catch.Golden then
		badge(badges, "DORADO ×3", T.Coin, 2)
	end
	if catch.Impossible then
		badge(badges, "🏆 IMPOSIBLE", T.Secondary, 3)
	end

	UIKit.label({ Text = ("Valor: 🪙 %s   ·   +%d XP"):format(Util.formatShort(catch.Value), result.XP or 0), Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 332), Font = T.Font, TextColor3 = T.Coin, Parent = card }, { MaxSize = 24 })

	local row = UIKit.new("Frame", { Size = UDim2.new(1, -24, 0, 64), Position = UDim2.new(0, 12, 1, -78), BackgroundTransparency = 1, Parent = card })
	UIKit.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	local function action(text: string, color: Color3, order: number, fn: () -> ())
		local btn = UIKit.button({ LayoutOrder = order, Size = UDim2.fromOffset(180, 60), Parent = row }, { Color = color, Text = text, TextSize = 22 })
		btn.Activated:Connect(fn)
		return btn
	end
	local busy = false
	local function run(remote: string, arg: any)
		if busy then
			return
		end
		busy = true
		local r = State.Call(remote, arg)
		busy = false
		if r.ok then
			if r.Earned then
				HUD.Toast(("💰 +%s MemeCoins"):format(Util.formatShort(r.Earned)), "Success")
				UIKit.playSound("Coins")
			end
			close()
		else
			HUD.Toast(r.err or "No se pudo", "Error")
		end
	end
	if result.NoSpace then
		-- no cabe en la mochila-acuario: venderlo ya o soltarlo
		UIKit.label({ Text = ("🐠 ¡No cabe en tu acuario! (ocupa %d kg)"):format(catch.Size or 0), Size = UDim2.new(1, -20, 0, 24),
			Position = UDim2.new(0, 10, 1, -106), Font = T.Font, TextColor3 = T.Danger, Parent = card }, { MaxSize = 20 })
		action("💰 Vender " .. Util.formatShort(catch.Value), T.Primary, 1, function()
			run("ResolvePending", "sell")
		end)
		action("🌊 Soltar", T.PanelLight, 2, function()
			run("ResolvePending", "release")
		end)
	else
		action("🐠 ¡Al acuario!", T.Accent, 1, close)
		action("💰 Vender " .. Util.formatShort(catch.Value), T.Primary, 2, function()
			run("SellCatch", catch.Id)
		end)
	end

	UIKit.tween(card, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	UIKit.playSound("Catch")
	if result.LevelUp and State.Data then
		HUD.Toast(("⬆️ ¡Has subido al nivel %d!"):format(State.Data.Level), "Success")
	end
end

function CatchCard.IsOpen(): boolean
	return current ~= nil
end

function CatchCard.Init()
	gui = UIKit.new("ScreenGui", { Name = "PescaCatchCard", ResetOnSpawn = false, DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
end

return CatchCard
