--[[
	PescaDeMemes • HUD (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > HUD

	Lo que siempre está en pantalla:
	  · MemeCoins y nivel/XP (arriba a la izquierda)
	  · Botones de paneles (derecha): Mochila, Acuario, Tienda, Bestiario
	  · Avisos (toasts) y anuncios de capturas épicas de otros jugadores
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Remotes = require(Root.Shared.Remotes)
local Util = require(Root.Shared.Util)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)

local T = UIKit.Theme
local HUD = {}
HUD.ButtonPressed = Util.Signal() -- (panelName)

local gui: ScreenGui
local toastHolder: Frame
local coinsLabel: TextLabel
local levelLabel: TextLabel
local xpFill: Frame

local TOAST_COLORS = {
	Info = T.Accent,
	Success = T.Success,
	Error = T.Danger,
	Warning = T.PrimaryDark,
}

function HUD.Toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = TOAST_COLORS[kind or "Info"] or T.Accent
	local toast = UIKit.new("Frame", { Size = UDim2.fromOffset(460, 46), BackgroundColor3 = T.PanelDark, Parent = toastHolder })
	UIKit.corner(toast, 12)
	UIKit.stroke(toast, 3, color)
	UIKit.label({ Text = text, Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Font = T.Font, Parent = toast }, { MaxSize = 22 })
	UIKit.pop(toast, 0.6)
	if kind == "Error" then
		UIKit.playSound("Click")
	end
	task.delay(3.2, function()
		if toast.Parent then
			UIKit.tween(toast, 0.25, { BackgroundTransparency = 1 })
			task.wait(0.25)
			toast:Destroy()
		end
	end)
end

local function showAnnouncement(text: string, rarityId: string?)
	local rarity = Memes.Rarities[rarityId or "LEGENDARY"] or Memes.Rarities.LEGENDARY
	local banner = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(720, 64),
		BackgroundColor3 = T.PanelDark, Parent = gui,
	})
	UIKit.corner(banner, 16)
	UIKit.stroke(banner, 4, rarity.Color)
	UIKit.responsive(banner)
	UIKit.label({ Text = text, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6), Font = T.FontTitle,
		TextColor3 = rarity.Color, Parent = banner }, { Stroke = 3, MaxSize = 30 })
	UIKit.tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	task.delay(5, function()
		UIKit.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, -90) })
		task.wait(0.4)
		banner:Destroy()
	end)
end

local function refresh(data: any)
	if not data then
		return
	end
	coinsLabel.Text = GameConfig.CurrencyEmoji .. " " .. Util.formatNumber(data.MemeCoin)
	levelLabel.Text = "Nv " .. data.Level
	local need = GameConfig.XPForLevel(data.Level)
	UIKit.tween(xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(data.XP / need, 0, 1), 1) })
end

function HUD.Init()
	local player = Players.LocalPlayer
	gui = UIKit.new("ScreenGui", { Name = "PescaHUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- monedas y nivel
	local stats = UIKit.new("Frame", { Name = "Stats", Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(250, 104),
		BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(stats)
	local coins = UIKit.new("Frame", { Size = UDim2.fromOffset(240, 48), BackgroundColor3 = T.PanelDark, Parent = stats })
	UIKit.corner(coins, 24)
	UIKit.stroke(coins, 3, T.Coin)
	coinsLabel = UIKit.label({ Text = "🪙 0", Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(14, 4),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Coin, Font = T.FontTitle, Parent = coins }, { Stroke = 2, MaxSize = 30 })

	local level = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 56), Size = UDim2.fromOffset(240, 40), BackgroundColor3 = T.PanelDark, Parent = stats })
	UIKit.corner(level, 20)
	UIKit.stroke(level, 3, T.Accent)
	levelLabel = UIKit.label({ Text = "Nv 1", Size = UDim2.fromOffset(70, 32), Position = UDim2.fromOffset(10, 4), Font = T.FontTitle,
		Parent = level }, { Stroke = 2, MaxSize = 24 })
	local bar = UIKit.new("Frame", { Position = UDim2.fromOffset(84, 13), Size = UDim2.fromOffset(140, 14), BackgroundColor3 = T.Panel, Parent = level })
	UIKit.corner(bar, 7)
	xpFill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = bar })
	UIKit.corner(xpFill, 7)

	-- botones de paneles
	local column = UIKit.new("Frame", { Name = "Buttons", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.42, 0),
		Size = UDim2.fromOffset(84, 380), BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(column)
	UIKit.list(column, Enum.FillDirection.Vertical, 10)
	local buttons = {
		{ "Backpack", "🎒", "Mochila", T.Primary },
		{ "Aquarium", "🐠", "Acuario", T.Accent },
		{ "Shop", "🛒", "Tienda", T.Secondary },
		{ "Bestiary", "📖", "Bestiario", T.Success },
	}
	for i, b in ipairs(buttons) do
		local btn = UIKit.button({ Name = b[1], LayoutOrder = i, Size = UDim2.fromOffset(80, 80), Parent = column }, { Color = b[4], Radius = 18 })
		UIKit.label({ Text = b[2], Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04), Parent = btn }, { Stroke = false })
		UIKit.label({ Text = b[3], Size = UDim2.new(1, -6, 0.3, 0), Position = UDim2.new(0, 3, 0.66, 0), Font = T.Font, Parent = btn }, { MaxSize = 16 })
		btn.Activated:Connect(function()
			HUD.ButtonPressed:Fire(b[1])
		end)
	end

	-- avisos
	toastHolder = UIKit.new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(460, 300), BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(toastHolder)
	UIKit.list(toastHolder, Enum.FillDirection.Vertical, 6)

	State.Changed:Connect(refresh)
	refresh(State.Data)
	Remotes.Get("Notify").OnClientEvent:Connect(function(text, kind)
		HUD.Toast(tostring(text), kind)
	end)
	Remotes.Get("Announce").OnClientEvent:Connect(function(text, rarityId)
		showAnnouncement(tostring(text), rarityId)
	end)
end

return HUD
