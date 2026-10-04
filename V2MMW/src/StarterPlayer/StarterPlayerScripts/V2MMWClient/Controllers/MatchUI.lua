--[[
	V2MMW • MatchUI (ModuleScript, cliente)
	HUD de partida (debajo del saldo): mapa, dificultad, tiempo restante, objetivo y SALIR.
	Al terminar: resultado + recompensa y vuelta automática al lobby.
]]

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local Remotes = require(Shared.Shared.Remotes)
local Util = require(Shared.Shared.Util)

local MatchUI = {}

function MatchUI.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme

	local bar = UI.new("Frame", { Name = "MatchInfo", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(460, 92), BackgroundColor3 = T.Panel, Visible = false, Parent = app.Gui })
	UI.responsive(bar)
	UI.corner(bar, 16)
	UI.stroke(bar, 3, T.Secondary)
	local mapLbl = UI.label({ Text = "", Size = UDim2.new(1, -150, 0, 30), Position = UDim2.fromOffset(14, 6), Font = T.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = bar }, { MaxSize = 24 })
	local objLbl = UI.label({ Text = "", Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(14, 38), TextColor3 = T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = bar }, { MaxSize = 16 })
	local timerLbl = UI.label({ Text = "0:00", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(120, 40), Position = UDim2.new(1, -14, 0, 4),
		Font = T.FontTitle, TextColor3 = T.Primary, Parent = bar }, { MaxSize = 34 })
	local leave = UI.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(150, 30), Parent = bar },
		{ Color = T.Danger, Text = "SALIR DE LA PARTIDA", TextSize = 15, Radius = 8, StrokeThickness = 2 })
	leave.Activated:Connect(function()
		State.Request("LeaveMatch")
	end)
	UI.label({ Text = "Habilidades: teclas 1 · 2 · 3 (o toca los slots)", Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(14, 64),
		TextColor3 = T.Accent, Font = T.FontBody, TextXAlignment = Enum.TextXAlignment.Left, Parent = bar }, { Stroke = 1, MaxSize = 13 })

	local result = UI.new("Frame", { Name = "MatchResult", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(520, 230), BackgroundColor3 = T.Panel, Visible = false, Parent = app.Gui })
	UI.responsive(result)
	UI.corner(result, 20)
	local resultStroke = UI.stroke(result, 5, T.Primary)
	local resultTitle = UI.label({ Text = "", Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 10), Font = T.FontTitle, Parent = result }, { Stroke = 4 })
	local resultSub = UI.label({ Text = "", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 84), Parent = result }, { MaxSize = 24 })
	local resultReward = UI.label({ Text = "", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 122), TextColor3 = T.Primary, Font = T.FontTitle, Parent = result }, { MaxSize = 30 })
	local resultBack = UI.label({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 176), TextColor3 = T.TextDim, Parent = result }, { MaxSize = 20 })

	local toasts = app.Gui:FindFirstChild("Notifications")
	bar:GetPropertyChangedSignal("Visible"):Connect(function()
		-- las notificaciones bajan para no tapar la info de la partida
		if toasts then
			toasts.Position = UDim2.new(0.5, 0, 0, bar.Visible and 172 or 74)
		end
	end)

	local state = nil
	local timerConn: RBXScriptConnection? = nil

	Remotes.Get("MatchState").OnClientEvent:Connect(function(s)
		state = s
		if timerConn then
			timerConn:Disconnect()
			timerConn = nil
		end
		if not s then
			bar.Visible = false
			result.Visible = false
			return
		end
		app.ClosePanels()
		bar.Visible = s.Phase == "Playing"
		mapLbl.Text = ("%s · %s%s"):format(s.MapName, s.Difficulty, s.Placeholder and " · 🚧 PLACEHOLDER" or "")
		objLbl.Text = s.Placeholder and "Objetivo de prueba: ¡llega a la META 🏁 primero!" or "¡Gana la partida!"
		if s.Phase == "Playing" then
			result.Visible = false
			UI.pop(bar, 0.6)
			State.Notify:Fire(("🚀 ¡Bienvenido a %s!"):format(s.MapName), "Info")
			timerConn = RunService.Heartbeat:Connect(function()
				local left = (state and state.EndsAt or 0) - Workspace:GetServerTimeNow()
				timerLbl.Text = Util.formatTime(left)
				timerLbl.TextColor3 = left <= 10 and T.Danger or T.Primary
			end)
		elseif s.Phase == "Ended" then
			result.Visible = true
			resultTitle.Text = s.YouWon and "🏆 ¡GANASTE!" or "🏁 FIN DE LA PARTIDA"
			resultTitle.TextColor3 = s.YouWon and T.Primary or T.Text
			resultStroke.Color = s.YouWon and T.Primary or T.Accent
			resultSub.Text = s.Winner and ("Ganador: %s"):format(s.Winner) or "Se acabó el tiempo ⏰"
			resultReward.Text = s.Reward or ""
			UI.pop(result, 0.5)
			if s.YouWon then
				app.Confetti()
			end
			local t0 = os.clock()
			timerConn = RunService.Heartbeat:Connect(function()
				local left = math.max(0, math.ceil((s.ReturnIn or 5) - (os.clock() - t0)))
				resultBack.Text = ("Volviendo al lobby en %d..."):format(left)
			end)
		end
	end)
end

return MatchUI
