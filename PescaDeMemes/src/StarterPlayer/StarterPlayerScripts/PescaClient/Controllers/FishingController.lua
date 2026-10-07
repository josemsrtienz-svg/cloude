--[[
	PescaDeMemes • FishingController (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > FishingController

	Pescar en la v0.4 (sin botón LANZAR: se controla con el CLICK directamente):
	  1. LANZAR: con la caña en la mano y en tu muelle, MANTÉN click (o el dedo, o F) → barra de fuerza;
	     al soltar, el personaje da el latigazo y el corcho vuela al agua.
	  2. INMERSIÓN: chapuzón y la cámara se mete bajo el agua (DiveScene). El anzuelo baja solo;
	     tú lo GUÍAS a izquierda/derecha con A/D, el ratón o el dedo. Tocar un meme lo engancha.
	     Medidor de profundidad a la derecha y anzuelos usados abajo (0/3).
	  3. PELEA: si el meme pesa más que tu caña, se para todo: ⚔️ PELEAR o ✂️ SOLTAR (FightUI).
	     Perder = el sedal sube de golpe (y la caña puede romperse).
	  4. SUBIR: al llenar los anzuelos, tocar el fondo o pulsar SUBIR (E). Los memes salen volando
	     del agua hasta tu mochila-acuario y aparece la tarjeta con todo lo pescado.
	El servidor genera la inmersión y valida cada enganche (FishingService).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Rods = require(Root.Config.Rods)
local Inventory = require(Root.Shared.Inventory)
local FishMath = require(Root.Shared.FishMath)
local MemeModels = require(Root.Shared.MemeModels)
local Memes = require(Root.Config.Memes)
local Util = require(Root.Shared.Util)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)
local CatchCard = require(Controllers.CatchCard)
local DiveScene = require(Controllers.DiveScene)
local FightUI = require(Controllers.FightUI)

local F = GameConfig.Fishing
local D = GameConfig.Dive
local T = UIKit.Theme
local RGB = Color3.fromRGB
local player = Players.LocalPlayer
local TOOL_NAME = GameConfig.RodToolName
local STEER_SPEED = D.SteerSpeed -- m/s máximos del anzuelo hacia los lados (el servidor valida lo mismo)

local FishingController = {}
FishingController.FiltersRequested = Util.Signal() -- el botón ⚙️ Filtros (lo escucha Panels)

-- "Idle" | "Charging" | "Casting" | "Diving" | "Ending"
local phase: string = "Idle"
local function currentPhase(): string
	return phase
end
local runId = 0
-- dirección de la inmersión: el ratón o el dedo marcan una x objetivo; el teclado la anula
local pointerX: number? = nil
local wantSurface = false
local serverSession = false -- hay una inmersión abierta en el servidor (Cast respondió ok y aún no se cerró)
local hookX = 0 -- x (m) actual del anzuelo, para mandarla con cada enganche
local savedMovement: { WalkSpeed: number, JumpPower: number, JumpHeight: number }? = nil

-- ===== UI =====
local gui: ScreenGui
local hint: Frame
local hintLabel: TextLabel
local rodChip: TextLabel
local itemsLabel: TextLabel
local powerFrame: Frame
local powerFill: Frame
local wipe: Frame
local diveHud: Frame
local depthBar: Frame
local depthHook: Frame
local depthHookLabel: TextLabel
local depthMax: TextLabel
local markerHolder: Frame
local hookCounter: TextLabel
local layerLabel: TextLabel
local surfaceButton: TextButton
local brakeButton: TextButton
local brakeHeld = false
local diveHint: TextLabel

-- ===== Personaje =====

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not hrp or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, humanoid, hrp
end

local function lockMovement()
	local _, humanoid = getCharacter()
	if humanoid and not savedMovement then
		savedMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
end

local function unlockMovement()
	local _, humanoid = getCharacter()
	if humanoid and savedMovement then
		humanoid.WalkSpeed = savedMovement.WalkSpeed
		humanoid.JumpPower = savedMovement.JumpPower
		humanoid.JumpHeight = savedMovement.JumpHeight
	end
	savedMovement = nil
end

local function rodTool(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(TOOL_NAME)
	return if tool and tool:IsA("Tool") then tool else nil
end

local function rodTip(): Attachment?
	local rod = rodTool()
	local shaft = rod and rod:FindFirstChild("Shaft")
	return shaft and shaft:FindFirstChild("RodTip") :: Attachment?
end

local function equippedRod(): any
	local data = State.Data
	return Rods.Get(data and data.EquippedRod) or Rods.List[1]
end

local function onOwnDock(): (boolean, string?)
	local _, _, hrp = getCharacter()
	if not hrp then
		return false, nil
	end
	local index = player:GetAttribute("PlotIndex")
	if type(index) ~= "number" or index < 1 then
		return false, "No tienes parcela (ni muelle) en este servidor"
	end
	local offset = hrp.Position - GameConfig.DockSpot(index)
	if Vector2.new(offset.X, offset.Z).Magnitude > GameConfig.Plots.FishingRange then
		return false, "🚶 Ve al final de TU muelle para pescar"
	end
	return true, nil
end

-- ===== Animaciones del personaje (locales) =====

-- Latigazo del lanzamiento: el brazo derecho va atrás y luego adelante.
local function castSwing()
	local character = player.Character
	local motor = character and (character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true))
	if not motor or not motor:IsA("Motor6D") then
		return
	end
	local base = motor.C0
	UIKit.tween(motor, 0.22, { C0 = base * CFrame.Angles(math.rad(70), 0, 0) }, Enum.EasingStyle.Quad)
	task.wait(0.22)
	UIKit.tween(motor, 0.12, { C0 = base * CFrame.Angles(math.rad(-50), 0, 0) }, Enum.EasingStyle.Back)
	task.wait(0.14)
	UIKit.tween(motor, 0.35, { C0 = base }, Enum.EasingStyle.Quad)
end

local function splash(at: Vector3, size: number)
	local ring = UIKit.new("Part", { Name = "Ripple", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1, 1),
		CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic, Transparency = 0.3, Anchored = true, CanCollide = false, CanQuery = false, Parent = Workspace })
	UIKit.tween(ring, 0.8, { Size = Vector3.new(0.1, size, size), Transparency = 1 })
	task.delay(0.85, function()
		ring:Destroy()
	end)
	for _ = 1, 8 do
		local drop = UIKit.new("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = RGB(200, 240, 255),
			Material = Enum.Material.SmoothPlastic, Transparency = 0.2, CanCollide = false, CanQuery = false, CanTouch = false,
			CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)), Parent = Workspace })
		drop.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), math.random(14, 22), math.random(-8, 8))
		task.delay(0.9, function()
			drop:Destroy()
		end)
	end
end

-- La caña se parte: trozos que saltan desde la punta.
local function rodBreakEffect(at: Vector3?)
	local tip = rodTip()
	local origin = at or (tip and tip.WorldPosition)
	if not origin then
		return
	end
	for _ = 1, 8 do
		local shard = UIKit.new("Part", { Size = Vector3.new(0.2, 0.2, 0.7), Color = RGB(120, 85, 50), Material = Enum.Material.Wood,
			CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), CanCollide = false,
			CanQuery = false, Parent = Workspace })
		shard.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(10, 22), math.random(-12, 12))
		task.delay(1.5, function()
			shard:Destroy()
		end)
	end
end

-- El corcho vuela desde la punta de la caña hasta el agua. Devuelve dónde cayó.
local function throwBobber(): Vector3?
	local _, _, hrp = getCharacter()
	local tip = rodTip()
	if not hrp then
		return nil
	end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	local target = Vector3.new(hrp.Position.X, GameConfig.River.SurfaceY, hrp.Position.Z) + flat * 12
	local from = if tip then tip.WorldPosition else hrp.Position
	local bobber = UIKit.new("Part", { Name = "Bobber", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = RGB(235, 60, 60),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CFrame = CFrame.new(from), Parent = Workspace })
	local att = UIKit.new("Attachment", { Parent = bobber })
	if tip then
		UIKit.new("Beam", { Attachment0 = tip, Attachment1 = att, Width0 = 0.06, Width1 = 0.06, Segments = 12, CurveSize0 = -1,
			CurveSize1 = 1, Color = ColorSequence.new(RGB(240, 240, 240)), LightInfluence = 0.5, FaceCamera = true, Parent = bobber })
	end
	local t0 = os.clock()
	while os.clock() - t0 < 0.5 do
		local a = (os.clock() - t0) / 0.5
		bobber.CFrame = CFrame.new(from:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 7, 0))
		RunService.RenderStepped:Wait()
	end
	bobber:Destroy()
	splash(target, 6)
	UIKit.playSound("Splash")
	return target
end

-- Los memes pescados saltan del agua y entran en la mochila-acuario de la espalda.
local function flyToBackpack(catches: { any }, from: Vector3?)
	local _, _, hrp = getCharacter()
	if not hrp or not from then
		return
	end
	for i, catch in ipairs(catches) do
		if i > 5 then
			break
		end
		if MemeModels.Has(catch.MemeId) then
			local model = MemeModels.Build(catch.MemeId, 0.35, catch.Golden, false)
			model.Parent = Workspace
			task.spawn(function()
				local t0 = os.clock()
				local start = from + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
				while os.clock() - t0 < 0.75 and model.Parent do
					local a = (os.clock() - t0) / 0.75
					local back = hrp.CFrame * CFrame.new(0, 1, 1.2)
					local p = start:Lerp(back.Position, a) + Vector3.new(0, math.sin(a * math.pi) * 9, 0)
					local s = 1 - a * 0.7
					model:PivotTo(CFrame.new(p) * CFrame.Angles(0, a * 8, 0))
					for _, d in ipairs(model:GetDescendants()) do
						if d:IsA("BasePart") then
							d.LocalTransparencyModifier = math.max(0, a - 0.75) * 4
						end
					end
					if s <= 0 then
						break
					end
					RunService.RenderStepped:Wait()
				end
				model:Destroy()
			end)
			splash(from, 4)
			task.wait(0.18)
		end
	end
end

-- ===== Fundido de pantalla (chapuzón) =====

local function wipeTo(alpha: number, time: number)
	UIKit.tween(wipe, time, { BackgroundTransparency = alpha })
	task.wait(time)
end

-- ===== Inmersión =====

local function setDiveHudVisible(on: boolean)
	diveHud.Visible = on
	hint.Visible = not on and rodTool() ~= nil and phase == "Idle"
end

-- Puntos del medidor (uno por meme, del color de su rareza): se crean una vez por inmersión
-- y solo se esconden cuando el meme ya no está libre.
local markerDots: { [number]: Frame } = {}

local function buildMarkers(maxDepth: number)
	for _, child in ipairs(markerHolder:GetChildren()) do
		child:Destroy()
	end
	table.clear(markerDots)
	for i, m in pairs(DiveScene.Markers()) do
		local dot = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, math.clamp(m.Depth / maxDepth, 0, 1)),
			Size = UDim2.fromOffset(14, 14), BackgroundColor3 = m.Color, Parent = markerHolder })
		UIKit.corner(dot, 7)
		UIKit.stroke(dot, 2)
		markerDots[i] = dot
	end
end

local function updateMarkers()
	for i, m in pairs(DiveScene.Markers()) do
		local dot = markerDots[i]
		if dot then
			dot.Visible = m.Free
		end
	end
end

local function updateCounter(count: number, hooks: number)
	hookCounter.Text = ("🎣 %d/%d"):format(count, hooks)
	UIKit.pop(hookCounter, 1.25)
end

type DiveResult = { Summary: any?, How: string, Broke: boolean? }

-- Bucle de la inmersión. Devuelve cómo terminó y el resumen del servidor.
local function runDive(spec: any, myRun: number, castTime: number): DiveResult
	local data = State.Data
	local skip = data and data.Settings and data.Settings.CatchSkip or {}
	DiveScene.Build(spec, skip)
	DiveScene.Enter()
	UIKit.playSound("Dive")
	wipeTo(1, 0.35)
	setDiveHudVisible(true)
	depthMax.Text = spec.MaxDepth .. " m"
	updateCounter(0, spec.Hooks)
	buildMarkers(spec.MaxDepth)
	diveHint.Visible = true
	diveHint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "¡Arrastra el dedo para guiar el anzuelo! Mantén 🐢 FRENAR para ir despacio"
		else "¡Guía el anzuelo con A / D o el ratón! Mantén S para FRENAR"
	task.delay(4, function()
		diveHint.Visible = false
	end)

	local diveStart = castTime + spec.IntroTime
	local paused = 0
	local x, targetX = 0, 0
	hookX = 0
	brakeHeld = false
	pointerX = nil
	wantSurface = false
	local tried: { [number]: boolean } = {}
	local busy = false -- esperando al servidor por una pelea
	local result: DiveResult? = nil
	local bottomAt: number? = nil
	local fullAt: number? = nil
	local lastMarkers = 0
	local grabbed = 0
	local lastToast = 0
	local currentDepth = 0

	local function diveTime(): number
		return math.max(0, os.clock() - diveStart - paused)
	end

	local function endWith(summary: any, how: string, broke: boolean?)
		if not result then
			result = { Summary = summary, How = how, Broke = broke }
		end
	end

	local function blockToast(text: string)
		if os.clock() - lastToast > 1.5 then
			lastToast = os.clock()
			HUD.Toast(text, "Warning")
		end
	end

	-- pelea con un meme que pesa más que la caña (el anzuelo se queda quieto mientras tanto)
	local function handleFight(index: number, info: any)
		local pauseStart = os.clock()
		local data = State.Data
		local memeInfo = Memes.Get(info.MemeId)
		local canNet = spec.Net == true and data ~= nil and (data.Items.RedDorada or 0) > 0
			and memeInfo ~= nil and Memes.Rarities[memeInfo.Rarity].Order < 7
		local choice = FightUI.Decide(info, canNet)
		if result or myRun ~= runId then
			return
		end
		if choice == "net" then
			local r = State.Call("UseNet")
			if r.ok and r.Grabbed then
				DiveScene.Attach(index)
				grabbed = r.Count or grabbed + 1
				updateCounter(grabbed, spec.Hooks)
				UIKit.playSound("Catch")
				UIKit.combo(grabbed)
				HUD.Toast(("🥅 ¡Atrapado con la red! (te quedan %d)"):format(r.NetsLeft or 0), "Success")
			else
				HUD.Toast(r.err or "La red falló", "Warning")
				State.Call("Release")
				DiveScene.Remove(index)
			end
			paused += os.clock() - pauseStart
			return
		end
		if choice ~= "fight" then
			State.Call("Release")
			DiveScene.Remove(index)
			paused += os.clock() - pauseStart
			return
		end
		local engaged = State.Call("Engage")
		if not engaged.ok then
			HUD.Toast(engaged.err or "Se escapó", "Warning")
			DiveScene.Remove(index)
			paused += os.clock() - pauseStart
			return
		end
		local won, reason, tug = FightUI.Run(info, function(inGreen: boolean)
			return State.Call("Tug", inGreen)
		end)
		if result or myRun ~= runId then
			return
		end
		if won then
			local r = State.Call("FinishFight", true)
			if r.ok and r.Grabbed then
				DiveScene.Attach(index)
				grabbed = r.Count or grabbed + 1
				updateCounter(grabbed, spec.Hooks)
				UIKit.playSound("Catch")
				UIKit.combo(grabbed)
				HUD.Toast("💪 ¡Lo has sacado! Sigue bajando", "Success")
			else
				HUD.Toast(r.err or "Se escapó", "Warning")
				DiveScene.Remove(index)
			end
			paused += os.clock() - pauseStart
		elseif reason == "tug" and tug and tug.Summary then
			DiveScene.Remove(index)
			endWith(tug.Summary, "lost", tug.Broke)
		elseif reason == "error" then
			endWith(State.Call("Surface"), "lost")
		else
			DiveScene.Remove(index)
			local r = State.Call("FinishFight", false)
			endWith(r.Summary or State.Call("Surface"), "lost", r.Broke)
		end
	end

	local function tryGrab(index: number)
		tried[index] = true
		task.spawn(function()
			local r = State.Call("Grab", index, hookX)
			if result or myRun ~= runId then
				return
			end
			if r.ok and r.Grabbed then
				DiveScene.Attach(index)
				grabbed = r.Count or grabbed + 1
				updateCounter(grabbed, spec.Hooks)
				UIKit.playSound("Bite")
				UIKit.combo(grabbed) -- cada meme del mismo lanzamiento suena más agudo
			elseif r.ok and r.Fight then
				busy = true
				handleFight(index, r)
				busy = false
			else
				local err = r.err or ""
				if string.find(err, "pesado") then
					DiveScene.Block(index, "⛔ Muy pesado")
					blockToast("⛔ ¡Demasiado pesado para tu caña! Mejora tu caña en la tienda")
				elseif string.find(err, "Filtrado") then
					DiveScene.Block(index, "🚫 filtrado")
				elseif string.find(err, "cabe") then
					DiveScene.Block(index, "🐠 No cabe")
					blockToast("🐠 No cabe en tu acuario")
				else
					-- otro motivo (latencia, otra pelea en curso…): se puede volver a intentar en un momento
					task.delay(0.8, function()
						tried[index] = nil
					end)
				end
			end
		end)
	end

	surfaceButton.Visible = true

	while not result do
		local dt = RunService.RenderStepped:Wait()
		if myRun ~= runId then
			return { How = "cancel" }
		end
		if busy then
			continue
		end
		local now = os.clock()
		local t = diveTime()
		-- bajada: a tope con la velocidad de la caña, o despacio mientras mantienes FRENAR
		local braking = brakeHeld or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
		local fallSpeed = if braking then math.min(spec.Speed, D.BrakeSpeed) else spec.Speed
		if now >= diveStart then
			currentDepth = math.min(spec.MaxDepth, currentDepth + fallSpeed * dt)
		end
		local depth = currentDepth
		brakeButton.BackgroundColor3 = if braking then T.Success else T.PanelLight

		-- dirección: teclado (A/D, flechas) o ratón/dedo
		local axis = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			axis -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			axis += 1
		end
		if axis ~= 0 then
			pointerX = nil
			targetX = x + axis * STEER_SPEED * 0.25
		elseif pointerX then
			targetX = pointerX
		end
		targetX = math.clamp(targetX, -D.LaneHalfWidth, D.LaneHalfWidth)
		-- un pelín más lento que el máximo del servidor para que nunca rechace un movimiento legal
		local maxStep = STEER_SPEED * 0.95 * dt
		x += math.clamp(targetX - x, -maxStep, maxStep)
		hookX = x
		DiveScene.Update(t, x, depth)

		-- medidor de profundidad
		depthHook.Position = UDim2.fromScale(0.5, depth / spec.MaxDepth)
		depthHookLabel.Text = ("%d m"):format(math.floor(depth))
		local layer = GameConfig.LayerAt(math.min(depth, spec.MaxDepth - 0.01))
		if layerLabel.Text ~= layer.Name then
			layerLabel.Text = layer.Name
			layerLabel.TextColor3 = layer.Glow or T.Primary
			UIKit.pop(layerLabel, 1.3)
		end
		if now - lastMarkers > 0.4 then
			lastMarkers = now
			updateMarkers()
		end

		-- ¿toca algún meme?
		if grabbed < spec.Hooks and now >= diveStart then
			local index = DiveScene.Touching(t, x, depth, tried, skip)
			if index then
				tryGrab(index)
			end
		end

		-- ¿hay que subir?
		if grabbed >= spec.Hooks then
			fullAt = fullAt or now
		end
		if depth >= spec.MaxDepth then
			bottomAt = bottomAt or now
		end
		if wantSurface or (fullAt and now - fullAt > 0.6) or (bottomAt and now - bottomAt > D.BottomWait) or t > D.Timeout - 5 then
			endWith(State.Call("Surface"), "normal")
		end
	end
	surfaceButton.Visible = false
	local final = result :: DiveResult

	-- subida: normal (rápida) o "el sedal sube de golpe" (rapidísima, con temblor)
	local fromDepth = currentDepth
	local duration = if final.How == "lost" then 0.45 else math.clamp(fromDepth / 25, 0.6, 1.6)
	if final.How == "lost" then
		HUD.Toast(if final.Broke then "💥 ¡Se ROMPIÓ tu caña! Repárala en la tienda (llevas la de palo)" else "😢 ¡Se escapó! El sedal ha subido de golpe", "Error")
	end
	local t0 = os.clock()
	local tFrozen = diveTime()
	while os.clock() - t0 < duration do
		local a = (os.clock() - t0) / duration
		local depth = fromDepth * (1 - a * a)
		local shakeX = if final.How == "lost" then math.sin(os.clock() * 60) * 0.4 else 0
		DiveScene.Update(tFrozen, x + shakeX, depth)
		depthHook.Position = UDim2.fromScale(0.5, depth / spec.MaxDepth)
		depthHookLabel.Text = ("%d m"):format(math.floor(depth))
		RunService.RenderStepped:Wait()
	end
	wipeTo(0, 0.25)
	return final
end

-- ===== Flujo completo de un lanzamiento =====

local function finish()
	phase = "Idle"
	State.Busy = false
	FightUI.Hide()
	if DiveScene.Active() then
		DiveScene.Exit()
	end
	DiveScene.Destroy()
	setDiveHudVisible(false)
	surfaceButton.Visible = false
	powerFrame.Visible = false
	brakeHeld = false
	wipe.BackgroundTransparency = 1
	unlockMovement()
	FishingController.RefreshHint()
end

local function cast(power: number)
	phase = "Casting"
	runId += 1
	local myRun = runId
	local castTime = os.clock()
	local result = State.Call("Cast", power)
	if myRun ~= runId then
		return
	end
	if not result.ok then
		HUD.Toast(result.err or "No se pudo lanzar", "Error")
		finish()
		return
	end
	castTime = os.clock() -- el servidor empieza a contar al recibir; respondió ahora
	serverSession = true
	if result.Reinforced then
		HUD.Toast("🧵 Sedal Reforzado usado: tu caña aguanta +25 % en este lanzamiento", "Info")
	end
	if result.Perfect then
		HUD.Toast("✨ ¡Lanzamiento PERFECTO! Más memes raros", "Success")
	end
	hint.Visible = false
	castSwing()
	UIKit.playSound("Cast")
	local splashAt = throwBobber()
	if myRun ~= runId then
		return
	end
	wipeTo(0, 0.2)
	phase = "Diving"
	local dive = runDive(result, myRun, castTime)
	if myRun ~= runId or dive.How == "cancel" then
		return
	end
	serverSession = false -- Surface/FinishFight/Tug ya cerraron la inmersión en el servidor
	-- de vuelta arriba: se sale de la escena y los memes vuelan a la mochila
	DiveScene.Exit()
	DiveScene.Destroy()
	setDiveHudVisible(false)
	wipeTo(1, 0.35)
	phase = "Ending"
	local summary = dive.Summary or {}
	if dive.Broke then
		rodBreakEffect(nil)
		UIKit.playSound("Snap")
	end
	local catches = summary.Catches or {}
	if #catches > 0 then
		flyToBackpack(catches, splashAt)
		task.wait(0.5)
	end
	finish()
	if #catches > 0 then
		CatchCard.ShowResults(summary)
	elseif summary.ok ~= false then
		HUD.Toast(if dive.How == "lost" then "Esta vez no hubo suerte… ¡otra!" else "🌊 Nada enganchado esta vez", "Info")
	else
		HUD.Toast(summary.err or "Error de conexión", "Error")
	end
end

-- Cancela (guardaste la caña, moriste…): el servidor guarda lo enganchado.
local function abort(message: string?)
	if phase == "Idle" then
		return
	end
	local hadSession = serverSession
	serverSession = false
	runId += 1
	finish()
	if message then
		HUD.Toast(message, "Info")
	end
	if hadSession then
		task.spawn(function()
			local summary = State.Call("Surface")
			if summary.ok and summary.Catches and #summary.Catches > 0 then
				CatchCard.ShowResults(summary)
			end
		end)
	end
end

-- ===== Cargar el lanzamiento (mantener click) =====

local chargeStart = 0
local chargeConn: RBXScriptConnection? = nil

local function chargePower(): number
	local x = ((os.clock() - chargeStart) * 0.9) % 2 -- ida y vuelta 0 → 1 → 0
	return if x <= 1 then x else 2 - x
end

local function startCharging()
	if phase ~= "Idle" or CatchCard.IsOpen() then
		return
	end
	if not rodTool() then
		return
	end
	local data = State.Data
	if data and data.BrokenRods and data.BrokenRods[data.EquippedRod] then
		HUD.Toast("💥 Tu caña está rota: repárala en la tienda", "Error")
		return
	end
	if data and Inventory.Free(data) < 1 then
		HUD.Toast("🐠 Tu acuario está lleno: vuelve a tu parcela para descargarlo", "Warning")
		return
	end
	local ok, err = onOwnDock()
	if not ok then
		if err then
			HUD.Toast(err, "Warning")
		end
		return
	end
	phase = "Charging"
	State.Busy = true
	lockMovement()
	chargeStart = os.clock()
	powerFrame.Visible = true
	hint.Visible = false
	UIKit.pop(powerFrame, 0.8)
	chargeConn = RunService.RenderStepped:Connect(function()
		powerFill.Size = UDim2.fromScale(chargePower(), 1)
	end)
end

local function stopCharging()
	if phase ~= "Charging" then
		return
	end
	if chargeConn then
		chargeConn:Disconnect()
		chargeConn = nil
	end
	local power = chargePower()
	powerFrame.Visible = false
	task.spawn(cast, power)
end

local function isCastInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.F
end

-- ===== UI =====

local function buildUI()
	gui = UIKit.new("ScreenGui", { Name = "PescaFishing", ResetOnSpawn = false, DisplayOrder = 6, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- pista con la caña en la mano: cómo se lanza y qué hace tu caña
	hint = UIKit.new("Frame", { Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(420, 78), BackgroundTransparency = 1, Visible = false, Parent = gui })
	UIKit.responsive(hint)
	hintLabel = UIKit.label({ Text = "🖱️ Mantén CLICK para lanzar", Size = UDim2.new(1, 0, 0, 40), Font = T.FontTitle,
		TextColor3 = T.Primary, Parent = hint }, { Stroke = 3, MaxSize = 30 })
	rodChip = UIKit.label({ Text = "", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 44), Font = T.Font,
		Parent = hint }, { Stroke = 2, MaxSize = 20 })
	local filtersButton = UIKit.button({ Name = "Filters", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -8, 0, 20),
		Size = UDim2.fromOffset(110, 44), Parent = hint }, { Color = T.Primary, Text = "⚙️ Filtros", TextSize = 18, Radius = 12 })
	filtersButton.Activated:Connect(function()
		if phase == "Idle" then
			FishingController.FiltersRequested:Fire()
		end
	end)
	-- objetos equipados (los que funcionan en este lanzamiento)
	itemsLabel = UIKit.label({ Name = "Items", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 8, 0, 20), Size = UDim2.fromOffset(200, 40),
		Font = T.Font, TextXAlignment = Enum.TextXAlignment.Left, Parent = hint }, { Stroke = 2, MaxSize = 20 })

	-- barra de fuerza (horizontal, bajo el personaje)
	powerFrame = UIKit.new("Frame", { Name = "Power", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(360, 34), BackgroundColor3 = T.PanelDark, Visible = false, Parent = gui })
	UIKit.corner(powerFrame, 12)
	UIKit.stroke(powerFrame, 4)
	UIKit.responsive(powerFrame)
	UIKit.new("Frame", { Name = "Perfect", Position = UDim2.fromScale(F.PerfectPower.Min, 0), Size = UDim2.fromScale(F.PerfectPower.Max - F.PerfectPower.Min, 1),
		BackgroundColor3 = T.Coin, BackgroundTransparency = 0.15, ZIndex = 3, Parent = powerFrame })
	powerFill = UIKit.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, ZIndex = 2, Parent = powerFrame })
	UIKit.corner(powerFill, 12)
	UIKit.label({ Text = "SUELTA en la zona dorada = PERFECTO", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(420, 30), Font = T.FontTitle, TextColor3 = T.Coin, Parent = powerFrame }, { Stroke = 3, MaxSize = 24 })

	-- fundido del chapuzón
	wipe = UIKit.new("Frame", { Name = "Wipe", Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(60, 170, 220), BackgroundTransparency = 1,
		ZIndex = 50, Parent = gui })

	-- HUD de la inmersión
	diveHud = UIKit.new("Frame", { Name = "DiveHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	diveHint = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(760, 44),
		Font = T.FontTitle, Parent = diveHud }, { Stroke = 3, MaxSize = 34 })
	UIKit.responsive(diveHint)
	-- medidor de profundidad (derecha)
	local meter = UIKit.new("Frame", { Name = "DepthMeter", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(120, 420), BackgroundTransparency = 1, Parent = diveHud })
	UIKit.responsive(meter)
	depthBar = UIKit.new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.new(0, 8, 1, -40), BackgroundColor3 = Color3.new(1, 1, 1), Parent = meter })
	UIKit.corner(depthBar, 4)
	UIKit.stroke(depthBar, 2)
	UIKit.label({ Text = "0 m", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(60, 20),
		Font = T.FontTitle, Parent = depthBar }, { Stroke = 2, MaxSize = 16 })
	depthMax = UIKit.label({ Text = "15 m", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(60, 20),
		Font = T.FontTitle, TextColor3 = T.Danger, Parent = depthBar }, { Stroke = 2, MaxSize = 16 })
	layerLabel = UIKit.label({ Name = "Layer", Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -26),
		Size = UDim2.fromOffset(220, 30), Font = T.FontTitle, TextXAlignment = Enum.TextXAlignment.Right, Parent = depthBar }, { Stroke = 3, MaxSize = 22 })
	markerHolder = UIKit.new("Frame", { Name = "Markers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = depthBar })
	depthHook = UIKit.new("Frame", { Name = "HookMarker", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = T.Danger, ZIndex = 4, Parent = depthBar })
	UIKit.corner(depthHook, 10)
	UIKit.stroke(depthHook, 3)
	local pill = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -8, 0.5, 0), Size = UDim2.fromOffset(72, 32),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = depthHook })
	UIKit.corner(pill, 8)
	UIKit.stroke(pill, 3)
	depthHookLabel = UIKit.label({ Text = "0 m", Size = UDim2.fromScale(1, 1), Font = T.FontTitle, TextColor3 = T.PanelDark, ZIndex = 5,
		Parent = pill }, { Stroke = false, MaxSize = 22 })
	-- anzuelos usados (abajo, grande)
	hookCounter = UIKit.label({ Name = "Hooks", Text = "🎣 0/1", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(260, 70), Font = T.FontTitle, Parent = diveHud }, { Stroke = 4, MaxSize = 60 })
	UIKit.responsive(hookCounter)
	-- botón SUBIR
	surfaceButton = UIKit.button({ Name = "Surface", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(170, 76), Visible = false, Parent = diveHud }, { Color = T.Accent, Text = "⬆️ SUBIR (E)", TextSize = 28, Radius = 16 })
	UIKit.responsive(surfaceButton)
	-- FRENAR (mantener): botón para móvil; en PC también S o ↓
	brakeButton = UIKit.button({ Name = "Brake", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -112),
		Size = UDim2.fromOffset(170, 76), Parent = diveHud }, { Color = T.PanelLight, Text = "🐢 FRENAR (S)", TextSize = 26, Radius = 16 })
	UIKit.responsive(brakeButton)
	brakeButton.MouseButton1Down:Connect(function()
		brakeHeld = true
	end)
	brakeButton.MouseButton1Up:Connect(function()
		brakeHeld = false
	end)
	brakeButton.MouseLeave:Connect(function()
		brakeHeld = false
	end)
	surfaceButton.Activated:Connect(function()
		wantSurface = true
	end)
end

function FishingController.RefreshHint()
	if not hint then
		return
	end
	local data = State.Data
	local parts = {}
	for _, id in ipairs(data and data.EquippedItems or {}) do
		local item = Rods.Items[id]
		local count = data.Items[id] or 0
		if item and count > 0 then
			table.insert(parts, if item.Kind == "Consumable" then ("%s×%d"):format(item.Emoji, count) else item.Emoji)
		end
	end
	itemsLabel.Text = if #parts > 0 then "🎒 " .. table.concat(parts, " ") else "🎒 sin objetos"
	local rod = equippedRod()
	local broken = data and data.BrokenRods and data.BrokenRods[rod.Id]
	hintLabel.Text = if broken then "💥 Caña rota: repárala en la tienda"
		elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "👆 Mantén pulsado para lanzar"
		else "🖱️ Mantén CLICK para lanzar"
	local unlocked, locked = GameConfig.UnlockedDepth(data and data.Level or 1)
	local depthText = if rod.MaxDepth > unlocked and locked
		then ("%d m (🔒 nivel %d para bajar más)"):format(unlocked, locked.RequiredLevel)
		else ("%d m"):format(rod.MaxDepth)
	rodChip.Text = ("%s · ⚖️ %s · 🎣 %d anzuelo%s · ⬇️ %s"):format(rod.Name, FishMath.FormatWeight(rod.Capacity), rod.Hooks,
		if rod.Hooks == 1 then "" else "s", depthText)
	hint.Visible = phase == "Idle" and rodTool() ~= nil and not diveHud.Visible
end

function FishingController.Init()
	FightUI.Init()
	buildUI()
	State.Changed:Connect(FishingController.RefreshHint)
	FishingController.RefreshHint()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if phase == "Diving" then
			if input.KeyCode == Enum.KeyCode.E then
				wantSurface = true
			elseif input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pointerX = DiveScene.ScreenToX(Vector2.new(input.Position.X, input.Position.Y))
			end
		elseif phase == "Idle" and isCastInput(input) and rodTool() then
			startCharging()
		end
	end)
	-- el ratón (o el dedo arrastrando) marca hacia dónde va el anzuelo
	UserInputService.InputChanged:Connect(function(input, processed)
		-- sobre un botón (FRENAR, SUBIR) el ratón no mueve el anzuelo
		if not processed and phase == "Diving" and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			pointerX = DiveScene.ScreenToX(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			brakeHeld = false -- soltar el dedo/click en cualquier sitio deja de frenar
		end
		if isCastInput(input) and phase == "Charging" then
			stopCharging()
		end
	end)

	player.CharacterRemoving:Connect(function()
		if phase ~= "Idle" then
			savedMovement = nil
			abort(nil)
		end
	end)

	-- si guardas la caña a mitad de lanzamiento, se cancela (lo enganchado se guarda)
	local function watchCharacter(character: Model)
		local function update()
			FishingController.RefreshHint()
			if rodTool() == nil and phase ~= "Idle" and phase ~= "Ending" then
				-- el servidor cambia la caña al romperse/repararse: esperamos un poco antes de cancelar
				task.delay(0.4, function()
					if rodTool() == nil and currentPhase() ~= "Idle" and currentPhase() ~= "Ending" then
						abort("🎣 Has guardado la caña")
					end
				end)
			end
		end
		character.ChildAdded:Connect(function(child)
			if child.Name == TOOL_NAME then
				update()
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child.Name == TOOL_NAME then
				update()
			end
		end)
		update()
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return FishingController
