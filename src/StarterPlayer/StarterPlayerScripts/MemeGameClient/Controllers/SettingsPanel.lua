--[[
	MemeGame • SettingsPanel (ModuleScript, cliente)
	CONFIGURACIÓN: Música, Sonidos, Volumen, Efectos, Calidad gráfica y Sensibilidad.
	Todo se aplica al momento en tu cliente y se guarda en tu perfil (DataStore).
	  - Calidad gráfica controla lo que dibuja ESTE juego (sombras, partículas, luces).
	    La calidad del motor de Roblox se cambia en el menú de Roblox (Esc → Configuración).
	  - Música: pon tu ID en Config > Assets > Sounds.LobbyMusic.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local Assets = require(Shared.Config.Assets)
local Remotes = require(Shared.Shared.Remotes)

local SettingsPanel = {}

local player = Players.LocalPlayer

function SettingsPanel.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme

	local settings = { Music = true, SFX = true, Volume = 0.8, Effects = true, Quality = "High", Sensitivity = 1 }
	local originalShadows = Lighting.GlobalShadows

	-- ================================================= sonido
	local musicGroup = UI.new("SoundGroup", { Name = "MemeMusic", Volume = 0.5, Parent = SoundService })
	local sfxGroup = UI.new("SoundGroup", { Name = "MemeSFX", Volume = 0.8, Parent = SoundService })
	UI.SFXGroup = sfxGroup
	local music = UI.new("Sound", { Name = "Music", Looped = true, Volume = 0.6, SoundGroup = musicGroup, Parent = SoundService })

	local function updateMusic()
		local id = State.GameState() == "Match" and Assets.Sounds.MatchMusic or Assets.Sounds.LobbyMusic
		if id == "" then
			id = Assets.Sounds.LobbyMusic
		end
		if settings.Music and id ~= "" then
			if music.SoundId ~= id then
				music.SoundId = id
			end
			if not music.IsPlaying then
				music:Play()
			end
		else
			music:Stop()
		end
	end

	-- ================================================= aplicar
	local function setEffects(enabled: boolean)
		for _, rootName in ipairs({ "MatchStations", "Maps" }) do
			local root = Workspace:FindFirstChild(rootName)
			if root then
				for _, d in ipairs(root:GetDescendants()) do
					if d:IsA("ParticleEmitter") then
						d.Enabled = enabled
					end
				end
			end
		end
		for _, child in ipairs(Workspace:GetChildren()) do
			if child:GetAttribute("MemeGameLobby") then
				for _, d in ipairs(child:GetDescendants()) do
					if d:IsA("ParticleEmitter") then
						d.Enabled = enabled
					elseif d:IsA("PointLight") then
						d.Enabled = settings.Quality ~= "Low"
					end
				end
			end
		end
	end

	local function apply()
		musicGroup.Volume = settings.Volume * 0.6
		sfxGroup.Volume = settings.SFX and settings.Volume or 0
		UI.SFXEnabled = settings.SFX
		updateMusic()
		Lighting.GlobalShadows = settings.Quality == "High" and originalShadows
		setEffects(settings.Effects and settings.Quality ~= "Low")
		pcall(function()
			UserSettings():GetService("UserGameSettings").MouseSensitivity = settings.Sensitivity
		end)
	end

	local pendingSend = false
	local function changed()
		apply()
		if not pendingSend then
			pendingSend = true
			task.delay(0.6, function()
				pendingSend = false
				Remotes.Get("UpdateSettings"):FireServer(settings)
			end)
		end
	end

	-- ================================================= UI
	local panel, content, close = UI.panel(app.Gui, "SettingsPanel", "⚙ CONFIGURACIÓN", Vector2.new(520, 520), T.PanelLight)
	app.RegisterPanel("Settings", panel, close)
	UI.list(content, Enum.FillDirection.Vertical, 10)
	local refreshers = {}

	local function row(order: number, title: string)
		local r = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.PanelDark, LayoutOrder = order, Parent = content })
		UI.corner(r, 12)
		UI.label({ Text = title, Size = UDim2.new(0.42, -12, 1, -12), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, Parent = r }, { MaxSize = 22 })
		return r
	end

	local function toggle(order: number, title: string, key: string)
		local r = row(order, title)
		local btn, lbl = UI.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 38), Parent = r },
			{ Text = "ON", TextSize = 22, Radius = 19 })
		local function refresh()
			btn.BackgroundColor3 = settings[key] and T.Success or T.Danger
			lbl.Text = settings[key] and "ON" or "OFF"
		end
		btn.Activated:Connect(function()
			settings[key] = not settings[key]
			refresh()
			changed()
		end)
		table.insert(refreshers, refresh)
	end

	local function slider(order: number, title: string, key: string, min: number, max: number, fmt: string)
		local r = row(order, title)
		local valueLbl = UI.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(60, 30), Parent = r }, { MaxSize = 20 })
		local bar = UI.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.42, 0, 0.5, 0), Size = UDim2.new(0.58, -84, 0, 12),
			BackgroundColor3 = T.Panel, Parent = r })
		UI.corner(bar, 6)
		UI.stroke(bar, 2)
		local fill = UI.new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = T.Accent, Parent = bar })
		UI.corner(fill, 6)
		local knob = UI.new("TextButton", { Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(26, 26), BackgroundColor3 = T.Primary, AutoButtonColor = false, Parent = bar })
		UI.corner(knob, 13)
		UI.stroke(knob, 2)
		local function refresh()
			local a = (settings[key] - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
			if fmt == "%" then
				valueLbl.Text = ("%d%%"):format(math.floor(settings[key] * 100 + 0.5))
			else
				valueLbl.Text = ("%.1f"):format(settings[key])
			end
		end
		local dragging = false
		local function setFromX(x: number)
			local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
			settings[key] = math.floor((min + a * (max - min)) * 100 + 0.5) / 100
			refresh()
			changed()
		end
		local function begin(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end
		knob.InputBegan:Connect(begin)
		bar.InputBegan:Connect(begin)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		table.insert(refreshers, refresh)
	end

	local function segmented(order: number, title: string, key: string, options: { { string } })
		local r = row(order, title)
		local holder = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.58, -10, 0, 38),
			BackgroundTransparency = 1, Parent = r })
		UI.list(holder, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		local buttons = {}
		for i, opt in ipairs(options) do
			local b = UI.button({ Size = UDim2.fromOffset(84, 36), LayoutOrder = i, Parent = holder }, { Text = opt[2], TextSize = 18, Radius = 10 })
			b.Activated:Connect(function()
				settings[key] = opt[1]
				for _, f in ipairs(refreshers) do
					f()
				end
				changed()
			end)
			buttons[opt[1]] = b
		end
		table.insert(refreshers, function()
			for value, b in pairs(buttons) do
				b.BackgroundColor3 = settings[key] == value and T.Primary or T.PanelLight
			end
		end)
	end

	toggle(1, "🎵 Música", "Music")
	toggle(2, "🔊 Sonidos", "SFX")
	slider(3, "🔉 Volumen", "Volume", 0, 1, "%")
	toggle(4, "✨ Efectos", "Effects")
	segmented(5, "🖥️ Calidad", "Quality", { { "Low", "BAJA" }, { "Medium", "MEDIA" }, { "High", "ALTA" } })
	slider(6, "🖱️ Sensibilidad", "Sensitivity", 0.2, 3, "x")
	local closeBig = UI.button({ Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 7, Parent = content }, { Color = T.Danger, Text = "CERRAR", TextSize = 24 })
	closeBig.Activated:Connect(function()
		app.ClosePanels()
	end)

	-- ================================================= cargar desde el perfil (una vez)
	local loaded = false
	State.DataChanged:Connect(function(data)
		if loaded or not data or type(data.Settings) ~= "table" then
			return
		end
		loaded = true
		for k, v in pairs(data.Settings) do
			if settings[k] ~= nil and type(v) == type(settings[k]) then
				settings[k] = v
			end
		end
		for _, f in ipairs(refreshers) do
			f()
		end
		apply()
	end)
	State.GameStateChanged:Connect(updateMusic)
	-- las partículas de las cabinas/mapas aparecen después: reaplicar al cargar el mundo
	Workspace.ChildAdded:Connect(function()
		task.wait(1)
		apply()
	end)
	for _, f in ipairs(refreshers) do
		f()
	end
	apply()
	player.CharacterAdded:Connect(function()
		task.wait(1)
		apply()
	end)
end

return SettingsPanel
