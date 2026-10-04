--[[
	V2MMW • Navigation (ModuleScript, cliente)
	Botón JUGAR → no cambia de pantalla: te guía FÍSICAMENTE a la Zona de Partidas.
	  - Un rayo de luz desde tu personaje hasta las cabinas.
	  - Camina solo usando PathfindingService. Si mueves el personaje tú mismo, el auto-caminar
	    se cancela pero la guía de luz se queda hasta que llegues.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")

local Navigation = {}

local player = Players.LocalPlayer
local active = 0 -- token de la navegación actual
local beamParts: { Instance } = {}

local MOVE_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Thumbstick1] = true,
}

local function findTarget(): BasePart?
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:GetAttribute("V2MMWLobby") then
			local t = child:FindFirstChild("NavTarget", true)
			if t and t:IsA("BasePart") then
				return t
			end
		end
	end
	return nil
end

local function clearBeam()
	for _, inst in ipairs(beamParts) do
		inst:Destroy()
	end
	table.clear(beamParts)
end

function Navigation.Stop()
	active += 1
	clearBeam()
end

function Navigation.Init(app)
	local State = app.State

	function Navigation.GoToMatchZone()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local target = findTarget()
		if not (hum and root and target) then
			State.Notify:Fire("La Zona de Partidas todavía está cargando...", "Error")
			return
		end
		if State.GameState() ~= "Lobby" then
			return
		end
		Navigation.Stop()
		local token = active
		app.ClosePanels()
		State.Notify:Fire("⚔️ ¡Vamos a la ZONA DE PARTIDAS! Entra a una cabina.", "Info")

		-- rayo guía
		local a0 = Instance.new("Attachment")
		a0.Name = "NavFrom"
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "NavTo"
		a1.Parent = target
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 205, 40), Color3.fromRGB(70, 195, 255))
		beam.Width0, beam.Width1 = 1.2, 3
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0.2)
		beam.Segments = 20
		beam.CurveSize0 = 8
		beam.Parent = root
		local marker = Instance.new("BillboardGui")
		marker.Size = UDim2.fromOffset(160, 60)
		marker.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
		marker.AlwaysOnTop = true
		marker.Parent = target
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.LuckiestGuy
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 205, 40)
		text.TextStrokeTransparency = 0
		text.Text = "⬇ CABINAS ⬇"
		text.Parent = marker
		beamParts = { a0, a1, beam, marker }

		-- auto-caminar (cancelable)
		local walking = true
		local inputConn
		inputConn = UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and MOVE_KEYS[input.KeyCode] then
				walking = false
			end
		end)
		task.spawn(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true })
			local ok = pcall(function()
				path:ComputeAsync(root.Position, target.Position)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				for _, wp in ipairs(path:GetWaypoints()) do
					if not walking or token ~= active or hum.Health <= 0 then
						break
					end
					if wp.Action == Enum.PathWaypointAction.Jump then
						hum.Jump = true
					end
					hum:MoveTo(wp.Position)
					local reached = hum.MoveToFinished:Wait()
					if not reached then
						break
					end
				end
			elseif walking then
				hum:MoveTo(target.Position)
			end
		end)

		-- fin: cuando llegas, entras a una cabina o pasan 40 s
		task.spawn(function()
			local t0 = os.clock()
			while token == active and os.clock() - t0 < 40 do
				task.wait(0.25)
				if not root.Parent or State.GameState() ~= "Lobby" then
					break
				end
				if (root.Position - target.Position).Magnitude < 16 then
					State.Notify:Fire("👉 Entra a una CABINA para configurar tu partida", "Info")
					break
				end
			end
			inputConn:Disconnect()
			if token == active then
				Navigation.Stop()
			end
		end)
	end
end

return Navigation
