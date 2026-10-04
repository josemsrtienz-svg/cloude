--[[
	V2MMW • StationUI (ModuleScript, cliente)
	Aparece SOLO cuando estás físicamente dentro de una cabina (lo decide el servidor).
	Panel lateral (no tapa el mundo): jugadores dentro, DIFICULTAD, MAPA, LISTO y SALIR.
	El anfitrión (el primero en entrar) elige; los demás ven la selección en vivo.
	Después: cuenta regresiva grande "PARTIDA EN: 10 … 1 · GO!".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Shared.Remotes)

local StationUI = {}

function StationUI.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme

	local panel = UI.new("Frame", { Name = "StationPanel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(350, 500), BackgroundColor3 = T.Panel, Visible = false, Parent = app.Gui })
	UI.responsive(panel)
	UI.corner(panel, 18)
	local panelStroke = UI.stroke(panel, 4, T.Accent)
	UI.padding(panel, 12)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local title = UI.label({ Name = "Title", Text = "CABINA", Size = UDim2.new(1, 0, 0, 40), Font = T.FontTitle, LayoutOrder = 1, Parent = panel }, { Stroke = 3, MaxSize = 34 })
	local countLbl = UI.label({ Name = "Count", Text = "0/0", Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.Primary, LayoutOrder = 2, Parent = panel }, { MaxSize = 20 })
	local playersLbl = UI.label({ Name = "Players", Text = "", Size = UDim2.new(1, 0, 0, 40), TextColor3 = T.TextDim, Font = T.FontBody, LayoutOrder = 3, Parent = panel }, { Stroke = 1, MaxSize = 15 })

	local function section(order: number, text: string)
		UI.label({ Text = text, Size = UDim2.new(1, 0, 0, 22), Font = T.FontTitle, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = panel }, { MaxSize = 20 })
		local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 92), LayoutOrder = order + 1, Parent = panel })
		UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 42), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		return grid
	end

	local current = nil -- último estado del servidor
	local diffButtons, mapButtons = {}, {}

	local diffGrid = section(4, "DIFICULTAD")
	for i, d in ipairs(GameConfig.Difficulties) do
		local b = UI.button({ Name = d.Id, LayoutOrder = i, Parent = diffGrid }, { Color = d.Color, Text = d.Name, TextSize = 22, Radius = 10 })
		b.Activated:Connect(function()
			if current and current.IsHost then
				State.Request("ConfigureStation", d.Id, nil)
			end
		end)
		diffButtons[d.Id] = b
	end
	local mapGrid = section(6, "MAPA")
	for i, m in ipairs(GameConfig.Maps) do
		local b = UI.button({ Name = m.Id, LayoutOrder = i, Parent = mapGrid }, { Color = m.Color, Text = m.Name, TextSize = 22, Radius = 10 })
		b.Activated:Connect(function()
			if current and current.IsHost then
				State.Request("ConfigureStation", nil, m.Id)
			end
		end)
		mapButtons[m.Id] = b
	end

	local waitLbl = UI.label({ Name = "Waiting", Text = "", Size = UDim2.new(1, 0, 0, 34), TextColor3 = T.TextDim, LayoutOrder = 8, Parent = panel }, { MaxSize = 17 })
	local readyBtn, readyLbl = UI.button({ Name = "Ready", Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 9, Parent = panel },
		{ Color = T.Success, Text = "✅ ¡LISTO!", Font = T.FontTitle, TextSize = 30 })
	local leaveBtn = UI.button({ Name = "Leave", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 10, Parent = panel },
		{ Color = T.Danger, Text = "SALIR DE LA CABINA", TextSize = 20 })
	readyBtn.Activated:Connect(function()
		if current and current.IsHost and current.Phase == "Config" then
			State.Request("StationReady")
		end
	end)
	leaveBtn.Activated:Connect(function()
		State.Request("LeaveStation")
	end)

	-- ================================================= cuenta regresiva
	local overlay = UI.new("Frame", { Name = "Countdown", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(460, 260), BackgroundTransparency = 1, Visible = false, Parent = app.Gui })
	UI.responsive(overlay)
	UI.label({ Text = "PARTIDA EN:", Size = UDim2.new(1, 0, 0, 50), Font = T.FontTitle, Parent = overlay }, { Stroke = 4 })
	local number = UI.label({ Name = "Number", Text = "10", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(300, 150), Font = T.FontTitle, TextColor3 = T.Primary, Parent = overlay }, { Stroke = 6 })
	local info = UI.label({ Name = "Info", Text = "", Position = UDim2.fromOffset(0, 205), Size = UDim2.new(1, 0, 0, 40), Parent = overlay }, { Stroke = 3, MaxSize = 28 })

	local lastShown = nil
	local function nameOf(list, id)
		for _, x in ipairs(list) do
			if x.Id == id then
				return x.Name
			end
		end
		return "—"
	end

	local function render(state)
		current = state
		if not state then
			panel.Visible = false
			overlay.Visible = false
			lastShown = nil
			return
		end
		if not panel.Visible then
			app.ClosePanels()
		end
		panel.Visible = true
		local cfg = GameConfig.GetStation(state.StationId)
		panelStroke.Color = cfg and cfg.Color or T.Accent
		title.Text = state.Name
		countLbl.Text = ("JUGADORES %d/%d"):format(#state.Players, state.Capacity)
		playersLbl.Text = "👥 " .. table.concat(state.Players, " · ") .. "\n👑 Anfitrión: " .. state.HostName
		for id, b in pairs(diffButtons) do
			local selected = state.Difficulty == id
			b.Stroke.Color = selected and Color3.new(1, 1, 1) or T.Stroke
			b.Stroke.Thickness = selected and 5 or 3
			b.AutoButtonColor = false
			b.Active = state.IsHost and state.Phase == "Config"
		end
		for id, b in pairs(mapButtons) do
			local selected = state.Map == id
			b.Stroke.Color = selected and Color3.new(1, 1, 1) or T.Stroke
			b.Stroke.Thickness = selected and 5 or 3
			b.Active = state.IsHost and state.Phase == "Config"
		end
		local ready = state.Difficulty ~= nil and state.Map ~= nil
		readyBtn.Visible = state.IsHost and state.Phase == "Config"
		readyBtn.BackgroundColor3 = ready and T.Success or Color3.fromRGB(110, 110, 120)
		readyLbl.Text = ready and "✅ ¡LISTO!" or "ELIGE DIFICULTAD Y MAPA"
		leaveBtn.Visible = state.Phase ~= "Launching"
		if state.Phase == "Config" then
			waitLbl.Text = state.IsHost and "Eres el anfitrión: elige y pulsa LISTO"
				or ("Esperando a que %s elija y pulse LISTO..."):format(state.HostName)
		elseif state.Phase == "Countdown" then
			waitLbl.Text = "¡Prepárate! La partida está por empezar"
		else
			waitLbl.Text = "🚀 ¡Transportando al mapa!"
		end

		-- overlay de cuenta regresiva
		if state.Phase == "Countdown" and state.TimeLeft then
			overlay.Visible = true
			info.Text = ("%s · %s"):format(nameOf(GameConfig.Difficulties, state.Difficulty), nameOf(GameConfig.Maps, state.Map))
			if state.TimeLeft ~= lastShown then
				lastShown = state.TimeLeft
				number.Text = tostring(state.TimeLeft)
				number.TextColor3 = state.TimeLeft <= 3 and T.Danger or T.Primary
				UI.pop(number, 1.6)
				UI.playSound("Countdown")
			end
		elseif state.Phase == "Launching" then
			overlay.Visible = true
			number.Text = "GO!"
			number.TextColor3 = T.Success
			UI.pop(number, 2)
			UI.playSound("Go")
		else
			overlay.Visible = false
			lastShown = nil
		end
	end

	Remotes.Get("StationState").OnClientEvent:Connect(render)
end

return StationUI
