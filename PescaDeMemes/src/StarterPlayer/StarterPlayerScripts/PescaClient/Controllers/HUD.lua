--[[
	PescaDeMemes • HUD (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > HUD

	Lo que siempre está en pantalla (estilo de los juegos de "steal"):
	  · Abajo a la izquierda: nivel/XP, capacidad de la mochila-acuario y el dinero en grande
	  · Izquierda: botones grandes Tienda e Índice · Derecha: botones cuadrados Acuario y Parcela
	  · Avisos (toasts) y anuncios de capturas épicas de otros jugadores
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Remotes = require(Root.Shared.Remotes)
local Util = require(Root.Shared.Util)
local Inventory = require(Root.Shared.Inventory)
local GearModels = require(Root.Shared.GearModels)
local Rods = require(Root.Config.Rods)
local Boosts = require(Root.Config.Boosts)

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
local aquariumLabel: TextLabel
local aquariumFill: Frame
local RGB = Color3.fromRGB
local shownCoins: number? = nil -- nil = aún no se ha mostrado nada (la primera vez no se anima)
local coinTween = 0
local coinTarget: number? = nil

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

-- El dinero sube contando (y el número da un saltito si ganas). La primera vez se pone directo.
local function animateCoins(target: number)
	if target == coinTarget then
		return -- llegan datos nuevos a menudo (ingresos, etc.): solo se anima si cambió el dinero
	end
	coinTarget = target
	coinTween += 1
	if shownCoins == nil then
		shownCoins = target
		coinsLabel.Text = Util.formatShort(target)
		return
	end
	local from = shownCoins :: number
	local myTween = coinTween
	if target > from then
		UIKit.pop(coinsLabel, 1.15)
	end
	task.spawn(function()
		local t0 = os.clock()
		while myTween == coinTween do
			local a = math.min(1, (os.clock() - t0) / 0.5)
			local value = math.floor(from + (target - from) * (1 - (1 - a) ^ 3))
			shownCoins = value
			coinsLabel.Text = Util.formatShort(value)
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
end

local function refresh(data: any)
	if not data then
		return
	end
	animateCoins(data.MemeCoin)
	levelLabel.Text = "Nv " .. data.Level
	local need = GameConfig.XPForLevel(data.Level)
	UIKit.tween(xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(data.XP / need, 0, 1), 1) })
	local used, cap = Inventory.Used(data), Inventory.Capacity(data)
	aquariumLabel.Text = ("%d / %d kg"):format(used, cap)
	local ratio = math.clamp(used / math.max(1, cap), 0, 1)
	UIKit.tween(aquariumFill, 0.3, { Size = UDim2.fromScale(ratio, 1) })
	aquariumFill.BackgroundColor3 = if ratio >= 1 then T.Danger elseif ratio > 0.75 then T.PrimaryDark else T.Accent
end

function HUD.Init()
	local player = Players.LocalPlayer
	gui = UIKit.new("ScreenGui", { Name = "PescaHUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- ===== Abajo a la izquierda: cifras grandes (estilo de la referencia) =====
	local stats = UIKit.new("Frame", { Name = "Stats", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -16),
		Size = UDim2.fromOffset(330, 170), BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(stats)
	-- nivel + XP
	local level = UIKit.new("Frame", { Size = UDim2.fromOffset(230, 34), BackgroundColor3 = T.PanelDark, Parent = stats })
	UIKit.corner(level, 17)
	UIKit.stroke(level, 3, T.Accent)
	levelLabel = UIKit.label({ Text = "Nv 1", Size = UDim2.fromOffset(64, 28), Position = UDim2.fromOffset(8, 3), Font = T.FontTitle,
		Parent = level }, { Stroke = 2, MaxSize = 22 })
	local bar = UIKit.new("Frame", { Position = UDim2.fromOffset(76, 10), Size = UDim2.fromOffset(140, 14), BackgroundColor3 = T.Panel, Parent = level })
	UIKit.corner(bar, 7)
	xpFill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = bar })
	UIKit.corner(xpFill, 7)
	-- mochila-acuario: kg usados / capacidad
	local tankIcon = UIKit.viewport(GearModels.Tank(Rods.Aquariums[1], { "NoobFeliz" }), { Position = UDim2.fromOffset(0, 40),
		Size = UDim2.fromOffset(50, 50), Parent = stats }, { Angle = 160, Zoom = 1.3 })
	tankIcon.Name = "TankIcon"
	local aqBar = UIKit.new("Frame", { Position = UDim2.fromOffset(52, 52), Size = UDim2.fromOffset(200, 26), BackgroundColor3 = T.PanelDark, Parent = stats })
	UIKit.corner(aqBar, 13)
	UIKit.stroke(aqBar, 3)
	aquariumFill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = aqBar })
	UIKit.corner(aquariumFill, 13)
	aquariumLabel = UIKit.label({ Text = "0 / 25 kg", Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Font = T.FontTitle,
		ZIndex = 3, Parent = aqBar }, { Stroke = 2, MaxSize = 20 })
	-- dinero gigante
	UIKit.viewport(GearModels.Coin(), { Name = "CoinIcon", Position = UDim2.fromOffset(0, 96), Size = UDim2.fromOffset(62, 62), Parent = stats },
		{ Spin = 1.5, Angle = 0, Zoom = 1.25 })
	coinsLabel = UIKit.label({ Text = "0", Size = UDim2.fromOffset(260, 66), Position = UDim2.fromOffset(66, 94), Font = T.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = RGB(90, 255, 90), Parent = stats }, { Stroke = 4, MaxSize = 64 })

	-- ===== Izquierda: botones grandes rectangulares =====
	local left = UIKit.new("Frame", { Name = "LeftButtons", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.42, 0),
		Size = UDim2.fromOffset(200, 170), BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(left)
	UIKit.list(left, Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Left)
	-- iconos 3D en vez de emojis: la caña para la tienda y el libro para el índice
	local leftButtons = {
		{ "Shop", function()
			return GearModels.Rod(Rods.List[3])
		end, "Tienda", RGB(60, 200, 80), 60 },
		{ "Bestiary", GearModels.Book, "Índice", RGB(40, 170, 255), 20 },
	}
	for i, b in ipairs(leftButtons) do
		local btn = UIKit.button({ Name = b[1], LayoutOrder = i, Size = UDim2.fromOffset(190, 74), Parent = left },
			{ Color = b[4], Radius = 10, StrokeThickness = 4 })
		UIKit.viewport(b[2](), { Name = "Icon", Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(4, 6), Parent = btn },
			{ Angle = b[5], Zoom = 1.3 })
		UIKit.label({ Text = b[3], Size = UDim2.new(1, -74, 0, 52), Position = UDim2.fromOffset(66, 11), Font = T.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = btn }, { Stroke = 3, MaxSize = 38 })
		btn.Activated:Connect(function()
			HUD.ButtonPressed:Fire(b[1])
		end)
	end

	-- ===== Derecha: botones cuadrados =====
	local right = UIKit.new("Frame", { Name = "RightButtons", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.4, 0),
		Size = UDim2.fromOffset(84, 190), BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(right)
	UIKit.list(right, Enum.FillDirection.Vertical, 12)
	local rightButtons = {
		{ "Aquarium", function()
			return GearModels.Tank(Rods.Aquariums[3], { "PerroBonk", "NoobFeliz" })
		end, RGB(255, 140, 40), 160, "Acuario" },
		{ "Plot", GearModels.House, RGB(235, 60, 60), 30, "Parcela" },
	}
	for i, b in ipairs(rightButtons) do
		local btn = UIKit.button({ Name = b[1], LayoutOrder = i, Size = UDim2.fromOffset(80, 80), Parent = right },
			{ Color = b[3], Radius = 10, StrokeThickness = 4 })
		UIKit.viewport(b[2](), { Name = "Icon", Size = UDim2.fromScale(0.9, 0.78), Position = UDim2.fromScale(0.05, 0.02), Parent = btn },
			{ Angle = b[4], Zoom = 1.25 })
		UIKit.label({ Text = b[5], AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0.5, 0, 1, -2),
			Font = T.FontTitle, Parent = btn }, { Stroke = 2, MaxSize = 16 })
		btn.Activated:Connect(function()
			HUD.ButtonPressed:Fire(b[1])
		end)
	end

	-- boosts activos (con cuenta atrás) y aviso del boost gratis, arriba a la izquierda
	local boostRow = UIKit.new("Frame", { Name = "Boosts", Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(520, 40),
		BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(boostRow)
	UIKit.list(boostRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
	local chips: { [string]: TextLabel } = {}
	local function chip(id: string, color: Color3, order: number): TextLabel
		local c = UIKit.label({ Name = id, LayoutOrder = order, Size = UDim2.fromOffset(150, 36), BackgroundTransparency = 0,
			BackgroundColor3 = T.PanelDark, Font = T.FontTitle, Visible = false, Parent = boostRow }, { Stroke = 2, MaxSize = 20 })
		UIKit.corner(c, 18)
		UIKit.stroke(c, 3, color)
		chips[id] = c
		return c
	end
	for i, id in ipairs(Boosts.Order) do
		chip(id, Boosts.List[id].Color, i)
	end
	local freeChip = chip("Free", T.Coin, 99)
	freeChip.Size = UDim2.fromOffset(260, 36)
	task.spawn(function()
		while gui.Parent do
			-- hora del SERVIDOR (los boosts caducan según el reloj del servidor, no el del PC)
			local now = math.floor(workspace:GetServerTimeNow())
			local data = State.Data
			for _, id in ipairs(Boosts.Order) do
				local untilTime = data and data.Boosts and data.Boosts[id]
				local left = if type(untilTime) == "number" then untilTime - now else 0
				local c = chips[id]
				c.Visible = left > 0
				if left > 0 then
					c.Text = ("%s %s %d:%02d"):format(Boosts.List[id].Emoji, string.match(Boosts.List[id].Name, "×[%d%.]+") or "", left // 60, left % 60)
				end
			end
			local freeId = player:GetAttribute("FreeBoost")
			local freeUntil = player:GetAttribute("FreeBoostUntil")
			freeChip.Visible = Boosts.Get(freeId) ~= nil
			if freeChip.Visible then
				local left = math.max(0, (if type(freeUntil) == "number" then freeUntil else now) - now)
				freeChip.Text = ("🎁 Boost gratis en la TIENDA %d:%02d"):format(left // 60, left % 60)
				freeChip.TextColor3 = if now % 2 == 0 then T.Coin else T.Text
			end
			task.wait(1)
		end
	end)

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
