--[[
	MemeGame • HUD (ModuleScript, cliente)
	Capa fija sobre el juego (no lo sustituye):
	  arriba-izquierda  ⚙ + perfil (avatar, nombre real, nivel, XP)
	  arriba-centro     saldo de MemeCoin + botón JUGAR (te guía a las cabinas)
	  lateral izquierdo TIENDA · INVENTARIO · TRADE
	  notificaciones    debajo del saldo
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local Util = require(Shared.Shared.Util)

local HUD = {}

local player = Players.LocalPlayer

function HUD.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme
	local gui = app.Gui

	-- ================================================= arriba-izquierda: ⚙ + perfil
	local topLeft = UI.new("Frame", { Name = "TopLeft", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(340, 78), Parent = gui })
	UI.responsive(topLeft)
	UI.list(topLeft, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local settingsBtn = UI.button({ Name = "SettingsButton", Size = UDim2.fromOffset(52, 52), LayoutOrder = 1, Parent = topLeft },
		{ Color = T.PanelLight, Text = "⚙", TextSize = 34, Radius = 14 })
	settingsBtn.Activated:Connect(function()
		app.TogglePanel("Settings")
	end)

	local card = UI.new("Frame", { Name = "Profile", Size = UDim2.fromOffset(270, 74), BackgroundColor3 = T.Panel, LayoutOrder = 2, Parent = topLeft })
	UI.corner(card, 16)
	UI.stroke(card, 3)
	local avatarRing = UI.new("Frame", { Name = "AvatarRing", Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = T.Primary, Parent = card })
	UI.corner(avatarRing, 31)
	UI.stroke(avatarRing, 2)
	local avatar = UI.new("ImageLabel", { Name = "Avatar", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = T.PanelDark, Image = "", Parent = avatarRing })
	UI.corner(avatar, 28)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then
			avatar.Image = img
		end
	end)
	UI.label({ Name = "PlayerName", Text = player.DisplayName, Size = UDim2.fromOffset(190, 24), Position = UDim2.fromOffset(76, 6),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { MaxSize = 22 })
	local levelPill = UI.new("Frame", { Name = "LevelPill", Size = UDim2.fromOffset(78, 20), Position = UDim2.fromOffset(76, 31),
		BackgroundColor3 = T.Primary, Parent = card })
	UI.corner(levelPill, 10)
	UI.stroke(levelPill, 2)
	local levelText = UI.label({ Name = "Level", Text = "Nivel 1", Size = UDim2.new(1, -8, 1, -2), Position = UDim2.fromOffset(4, 1),
		TextColor3 = T.Stroke, Font = T.FontTitle, Parent = levelPill }, { Stroke = false })
	local xpBar = UI.new("Frame", { Name = "XPBar", Size = UDim2.fromOffset(182, 14), Position = UDim2.fromOffset(76, 55),
		BackgroundColor3 = T.PanelDark, Parent = card })
	UI.corner(xpBar, 7)
	UI.stroke(xpBar, 2)
	local xpFill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = xpBar })
	UI.corner(xpFill, 7)
	local xpText = UI.label({ Name = "XPText", Text = "XP 0/100", Size = UDim2.fromOffset(100, 20), Position = UDim2.fromOffset(160, 31),
		TextColor3 = T.TextDim, Font = T.FontBody, TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, { Stroke = 1.5, MaxSize = 14 })

	-- ================================================= arriba-centro: MemeCoin + JUGAR
	local topCenter = UI.new("Frame", { Name = "TopCenter", AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(440, 56), Parent = gui })
	UI.responsive(topCenter)
	UI.list(topCenter, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

	local coinPill = UI.new("Frame", { Name = "MemeCoin", Size = UDim2.fromOffset(280, 52), BackgroundColor3 = T.Panel, LayoutOrder = 1, Parent = topCenter })
	UI.corner(coinPill, 26)
	local coinStroke = UI.stroke(coinPill, 3, T.Coin)
	UI.label({ Name = "Icon", Text = GameConfig.CurrencyEmoji, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 6), Parent = coinPill }, { Stroke = false })
	local coinText = UI.label({ Name = "Amount", Text = "0", Size = UDim2.new(1, -150, 0, 36), Position = UDim2.fromOffset(52, 8),
		Font = T.FontTitle, TextXAlignment = Enum.TextXAlignment.Left, Parent = coinPill }, { Stroke = 2.5, MaxSize = 30 })
	UI.label({ Name = "CurrencyName", Text = GameConfig.CurrencyName, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(96, 24),
		Position = UDim2.new(1, -14, 0, 14), TextColor3 = T.Coin, Parent = coinPill }, { Stroke = 2, MaxSize = 20 })

	local playBtn = UI.button({ Name = "PlayButton", Size = UDim2.fromOffset(140, 52), LayoutOrder = 2, Parent = topCenter },
		{ Color = T.Success, Text = "▶ JUGAR", Font = T.FontTitle, TextSize = 30, Radius = 16 })
	playBtn.Activated:Connect(function()
		app.Navigation.GoToMatchZone()
	end)
	HUD.PlayButton = playBtn

	-- ================================================= lateral izquierdo
	local side = UI.new("Frame", { Name = "SideMenu", AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0.45, 0), Size = UDim2.fromOffset(150, 200), Parent = gui })
	UI.responsive(side)
	UI.list(side, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left)
	local sideButtons = {
		{ "Shop", "🛒 TIENDA", Color3.fromRGB(230, 40, 50) },
		{ "Inventory", "🎒 INVENTARIO", T.Accent },
		{ "Trade", "🤝 TRADE", Color3.fromRGB(185, 90, 255) },
	}
	for i, def in ipairs(sideButtons) do
		local b = UI.button({ Name = def[1] .. "Button", Size = UDim2.fromOffset(150, 56), LayoutOrder = i, Parent = side },
			{ Color = def[3], Text = def[2], TextSize = 22, Radius = 14 })
		b.Activated:Connect(function()
			app.TogglePanel(def[1])
		end)
	end

	-- ================================================= notificaciones
	local toasts = UI.new("Frame", { Name = "Notifications", AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(460, 220), Parent = gui })
	UI.responsive(toasts)
	UI.list(toasts, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	local kindColor = { Success = T.Success, Error = T.Danger, Reward = T.Primary, Info = T.Accent }
	local order = 0
	State.Notify:Connect(function(text: string, kind: string?)
		if not text or text == "" then
			return
		end
		order += 1
		local toast = UI.new("Frame", { Name = "Toast", Size = UDim2.fromOffset(440, 40), BackgroundColor3 = T.PanelDark,
			LayoutOrder = order, Parent = toasts })
		UI.corner(toast, 12)
		UI.stroke(toast, 3, kindColor[kind or "Info"] or T.Accent)
		UI.label({ Text = text, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), Parent = toast }, { MaxSize = 20 })
		UI.pop(toast, 0.6)
		if kind == "Error" then
			UI.playSound("Error")
		elseif kind == "Reward" then
			UI.playSound("Purchase")
		end
		local items = {}
		for _, c in ipairs(toasts:GetChildren()) do
			if c:IsA("Frame") then
				table.insert(items, c)
			end
		end
		if #items > 4 then
			table.sort(items, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			items[1]:Destroy()
		end
		task.delay(3.2, function()
			if toast.Parent then
				UI.tween(toast, 0.25, { BackgroundTransparency = 1 })
				task.wait(0.25)
				toast:Destroy()
			end
		end)
	end)

	-- ================================================= datos → UI
	local shownCoins = 0
	local coinValue = UI.new("NumberValue", { Value = 0 })
	coinValue.Changed:Connect(function(v)
		coinText.Text = Util.formatNumber(v)
	end)
	State.DataChanged:Connect(function(data)
		levelText.Text = "Nivel " .. data.Level
		local need = GameConfig.XPForLevel(data.Level)
		xpText.Text = ("XP %d/%d"):format(data.XP, need)
		UI.tween(xpFill, 0.4, { Size = UDim2.fromScale(math.clamp(data.XP / need, 0, 1), 1) })
		if data.MemeCoin ~= shownCoins then
			local gained = data.MemeCoin > shownCoins
			shownCoins = data.MemeCoin
			UI.tween(coinValue, 0.6, { Value = data.MemeCoin })
			UI.pop(coinPill, gained and 1.12 or 0.9)
			coinStroke.Color = gained and T.Success or T.Danger
			task.delay(0.6, function()
				coinStroke.Color = T.Coin
			end)
		end
	end)

	-- En partida el botón JUGAR no tiene sentido
	local function onState(state)
		playBtn.Visible = state == "Lobby"
	end
	State.GameStateChanged:Connect(onState)
	onState(State.GameState())
end

return HUD
