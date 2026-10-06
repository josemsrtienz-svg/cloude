--[[
	PescaDeMemes • FishingController (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > FishingController

	Todo lo que el jugador ve y toca al pescar:
	  1. LANZAR: mantener el botón (o F) llena la barra de fuerza; al soltar se lanza el corcho.
	  2. ESPERA: el corcho flota y hace amagos. Tocar antes de tiempo lo asusta.
	  3. PICADA: aparece "!" → hay 0,6 s para tocar.
	  4. DECISIÓN (solo si pesa más que tu caña): PELEAR o SOLTAR, viendo el % de aguante.
	  5. PELEA: mantener = más tensión. Indicador en la zona verde = el progreso sube.
	     Zona roja demasiado tiempo = se rompe. Con sobrecarga hay 3 tirones fuertes.
	  6. RESULTADO: tarjeta de captura.
	El servidor decide qué pica, valida los tiempos y los tirones (FishingService).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local FishMath = require(Root.Shared.FishMath)
local FishBehaviors = require(Root.Shared.FishBehaviors)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local HUD = require(Controllers.HUD)
local CatchCard = require(Controllers.CatchCard)

local F = GameConfig.Fishing
local T = UIKit.Theme
local player = Players.LocalPlayer

local FishingController = {}

-- ===== Estado =====
-- "Idle" | "Charging" | "Casting" | "Waiting" | "Bite" | "Deciding" | "Fighting" | "Ending"
local phase: string = "Idle"

-- leer la fase a través de una función evita que el analizador "congele" su valor dentro de los bucles
local function currentPhase(): string
	return phase
end
local runId = 0 -- se incrementa en cada lanzamiento; invalida esperas de lanzamientos anteriores
local useReinforced = false

local bobber: BasePart? = nil
local bobberBase: Vector3 = Vector3.zero
local beam: Beam? = nil
local savedMovement: { WalkSpeed: number, JumpPower: number, JumpHeight: number }? = nil

-- ===== UI =====
local gui: ScreenGui
local castButton: TextButton
local castLabel: TextLabel
local reinforcedButton: TextButton
local reinforcedLabel: TextLabel
local powerFrame: Frame
local powerFill: Frame
local biteLabel: TextLabel
local decision: Frame
local fight: Frame
local fightRefs: { [string]: any } = {}

local function setCastText(text: string, color: Color3?)
	castLabel.Text = text
	castButton.BackgroundColor3 = color or T.Primary
end

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

local function rodTip(): Attachment?
	local character = player.Character
	local rod = character and character:FindFirstChild("FishingRod")
	local shaft = rod and rod:FindFirstChild("Shaft")
	return shaft and shaft:FindFirstChild("RodTip") :: Attachment?
end

-- ===== Corcho y sedal (solo visual, en el cliente) =====

local function destroyBobber()
	if bobber then
		bobber:Destroy()
		bobber = nil
	end
	if beam then
		beam:Destroy()
		beam = nil
	end
end

local function makeBobber(at: Vector3): BasePart
	destroyBobber()
	local b = UIKit.new("Part", { Name = "Bobber", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = Color3.fromRGB(235, 60, 60),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CFrame = CFrame.new(at), Parent = Workspace })
	UIKit.new("Part", { Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CFrame = CFrame.new(at + Vector3.new(0, 0.4, 0)), Parent = b })
	b:SetAttribute("TopOffset", 0.4)
	local att = UIKit.new("Attachment", { Name = "LineEnd", Parent = b })
	local tip = rodTip()
	if tip then
		beam = UIKit.new("Beam", { Attachment0 = tip, Attachment1 = att, Width0 = 0.06, Width1 = 0.06, Segments = 12, CurveSize0 = -1,
			CurveSize1 = 1, Color = ColorSequence.new(Color3.fromRGB(240, 240, 240)), LightInfluence = 0.5, FaceCamera = true, Parent = b })
	end
	bobber = b
	return b
end

local function setBobberPos(pos: Vector3)
	if bobber then
		bobber.CFrame = CFrame.new(pos)
		local top = bobber:FindFirstChild("Top") :: BasePart?
		if top then
			top.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0))
		end
	end
end

local function splash(at: Vector3, size: number)
	local ring = UIKit.new("Part", { Name = "Ripple", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1, 1),
		CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic, Transparency = 0.3, Anchored = true, CanCollide = false, CanQuery = false, Parent = Workspace })
	UIKit.tween(ring, 0.8, { Size = Vector3.new(0.1, size, size), Transparency = 1 })
	task.delay(0.85, function()
		ring:Destroy()
	end)
end

-- Meme saltando del agua hacia el jugador (celebración rápida).
local function memeJump(memeId: string, from: Vector3)
	local meme = Memes.Get(memeId)
	local _, _, hrp = getCharacter()
	if not meme or not hrp then
		return
	end
	local rarity = Memes.Rarities[meme.Rarity]
	local orb = UIKit.new("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Color = rarity.Color, Material = Enum.Material.Neon,
		Transparency = 0.35, Anchored = true, CanCollide = false, CanQuery = false, CFrame = CFrame.new(from), Parent = Workspace })
	local bb = UIKit.new("BillboardGui", { Size = UDim2.fromOffset(90, 90), AlwaysOnTop = true, LightInfluence = 0, Parent = orb })
	UIKit.label({ Text = meme.Emoji, Size = UDim2.fromScale(1, 1), Parent = bb }, { Stroke = false })
	local to = hrp.Position + Vector3.new(0, 4, 0)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.min(1, (os.clock() - t0) / 0.8)
		local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 10, 0)
		orb.CFrame = CFrame.new(p)
		if a >= 1 then
			conn:Disconnect()
			UIKit.tween(orb, 0.3, { Transparency = 1, Size = Vector3.one * 5 })
			task.delay(0.35, function()
				orb:Destroy()
			end)
		end
	end)
	splash(from, 8)
end

-- ===== Final común de cualquier lanzamiento =====

local function finish()
	runId += 1
	phase = "Idle"
	State.Busy = false
	destroyBobber()
	unlockMovement()
	powerFrame.Visible = false
	biteLabel.Visible = false
	decision.Visible = false
	fight.Visible = false
	setCastText("🎣\nLANZAR")
	FishingController.RefreshReinforced()
end

local function release(message: string?, kind: string?)
	task.spawn(State.Call, "Release")
	if message then
		HUD.Toast(message, kind or "Info")
	end
	finish()
end

-- ===== Pelea =====

local fightConn: RBXScriptConnection? = nil
local holding = false

local function stopFightLoop()
	if fightConn then
		fightConn:Disconnect()
		fightConn = nil
	end
end

local function endFight(success: boolean, reason: string?)
	if phase ~= "Fighting" then
		return
	end
	phase = "Ending"
	stopFightLoop()
	local myRun = runId
	if reason == "snap" then
		UIKit.playSound("Snap")
		UIKit.shake(fight)
	end
	local result = State.Call("FinishFight", success)
	if myRun ~= runId then
		return
	end
	local from = if bobber then bobber.Position else Vector3.zero
	if success and result.ok and result.Catch then
		memeJump(result.Catch.MemeId, from)
		finish()
		task.wait(0.6)
		CatchCard.Show(result)
		return
	end
	if success and not result.ok then
		HUD.Toast(result.err or "Algo salió mal", "Error")
	elseif reason == "snap" then
		HUD.Toast("💥 ¡El sedal se rompió!", "Error")
	else
		HUD.Toast("😢 Se escapó…", "Warning")
	end
	finish()
end

local function startFight(info: any)
	phase = "Fighting"
	decision.Visible = false
	biteLabel.Visible = false
	fight.Visible = true
	setCastText("💪\nTIRAR", T.Secondary)
	holding = false

	local params = info.Params
	local behavior = FishBehaviors.new(info.Personality, params.GreenWidth, F.RedZoneStart)
	local tugs = info.Tugs or 0
	local nextTug = 1
	local tugState: string = "none" -- "none" | "warning" | "waiting"
	local tugTimer = 0
	local pos, vel = 0.3, 0
	local progress = F.StartProgress
	local redTime = 0
	local myRun = runId

	local refs = fightRefs
	refs.Green.Size = UDim2.fromScale(params.GreenWidth, 1)
	refs.Red.Size = UDim2.fromScale(1 - F.RedZoneStart, 1)
	refs.Red.Position = UDim2.fromScale(F.RedZoneStart, 0)
	for i, marker in ipairs(refs.TugMarkers) do
		marker.Visible = i <= tugs
		marker.BackgroundColor3 = T.Primary
	end
	refs.Survival.Text = if tugs > 0 then ("Aguante del sedal: %s"):format(FishMath.FormatPercent(info.Survival)) else "Dentro de la capacidad de tu caña ✅"
	refs.Survival.TextColor3 = if tugs > 0 then T.PrimaryDark else T.Success
	refs.Tug.Visible = false

	fightConn = RunService.RenderStepped:Connect(function(dt)
		if phase ~= "Fighting" or myRun ~= runId then
			stopFightLoop()
			return
		end
		dt = math.min(dt, 0.05)
		local center, behaviorPull, event = behavior:Update(dt)
		if event == "jump" then
			UIKit.shake(refs.Bar)
		end

		if tugState ~= "waiting" then
			local push = math.min(2.8, params.Pull * behaviorPull * 0.9)
			local accel = (if holding then 3.4 else -2.0) - push
			vel = math.clamp((vel + accel * dt) * (0.9 ^ (dt * 60)), -1.4, 1.4)
			pos += vel * dt
			if pos <= 0 then
				pos, vel = 0, 0
			elseif pos >= 1 then
				pos, vel = 1, 0
			end
		end

		local inGreen = math.abs(pos - center) <= params.GreenWidth / 2
		if tugState ~= "waiting" then
			local rate = if inGreen then params.FillRate else -params.FillRate * F.DrainFactor * (if pos <= 0 then 1.5 else 1)
			progress = math.clamp(progress + rate * dt, 0, 1)
			if nextTug <= tugs then
				progress = math.min(progress, 0.97)
			end
			if pos >= F.RedZoneStart then
				redTime += dt
			else
				redTime = math.max(0, redTime - dt)
			end
		end

		-- tirones fuertes (solo con sobrecarga)
		if nextTug <= tugs then
			if tugState == "none" and progress >= F.TugThresholds[nextTug] then
				tugState = "warning"
				tugTimer = F.TugWarning
				refs.Tug.Text = "⚡ ¡TIRÓN! Quédate en la zona verde"
				refs.Tug.Visible = true
				UIKit.pop(refs.Tug, 1.4)
			elseif tugState == "warning" then
				tugTimer -= dt
				if tugTimer <= 0 then
					tugState = "waiting"
					local wasGreen = inGreen
					UIKit.playSound("Tug")
					UIKit.shake(refs.Bar)
					task.spawn(function()
						local r = State.Call("Tug", wasGreen)
						if currentPhase() ~= "Fighting" or myRun ~= runId then
							return
						end
						if r.ok and r.Survived then
							refs.TugMarkers[nextTug].BackgroundColor3 = T.Success
							refs.Tug.Text = "✅ ¡AGUANTÓ!"
							nextTug += 1
							tugState = "none"
							task.delay(0.8, function()
								-- solo se oculta si no ha empezado otro tirón mientras tanto
								if refs.Tug.Text == "✅ ¡AGUANTÓ!" then
									refs.Tug.Visible = false
								end
							end)
						elseif r.ok then
							refs.TugMarkers[nextTug].BackgroundColor3 = T.Danger
							endFight(false, "snap")
						else
							-- el servidor rechazó el tirón (latencia/validación): termina sin culpar al jugador
							HUD.Toast(r.err or "Error de conexión", "Error")
							endFight(false, "escape")
						end
					end)
				end
			end
		end

		-- dibujar
		refs.Green.Position = UDim2.fromScale(center - params.GreenWidth / 2, 0)
		refs.Green.BackgroundColor3 = if inGreen then T.Success else Color3.fromRGB(60, 150, 80)
		refs.Indicator.Position = UDim2.new(pos, 0, 0.5, 0)
		refs.Red.BackgroundTransparency = if redTime > 0 then 0.1 + 0.3 * math.abs(math.sin(os.clock() * 20)) else 0.35
		refs.ProgressFill.Size = UDim2.fromScale(progress, 1)
		refs.ProgressFill.BackgroundColor3 = if progress > 0.66 then T.Success elseif progress > 0.33 then T.Primary else T.Danger

		if redTime > params.RedTolerance then
			task.spawn(endFight, false, "snap")
		elseif progress <= 0 then
			task.spawn(endFight, false, "escape")
		elseif progress >= 1 and nextTug > tugs then
			task.spawn(endFight, true)
		end
	end)
end

local function showDecision(info: any)
	phase = "Deciding"
	biteLabel.Visible = false
	local rarity = Memes.Rarities[info.Rarity]
	local meme = info.MemeId and Memes.Get(info.MemeId)
	local refs = fightRefs.Decision
	refs.Name.Text = if meme then meme.Name else "???"
	refs.Name.TextColor3 = rarity.Color
	refs.Weight.Text = ("⚖️ ~%s   /   🎣 %s"):format(FishMath.FormatWeight(info.EstimatedWeight), FishMath.FormatWeight(info.Capacity))
	local survival = info.Survival
	refs.SurvivalFill.Size = UDim2.fromScale(math.max(0.02, survival), 1)
	refs.SurvivalFill.BackgroundColor3 = if survival > 0.4 then T.Primary elseif survival > 0.1 then T.PrimaryDark else T.Danger
	refs.SurvivalText.Text = "Aguante del sedal: " .. FishMath.FormatPercent(survival)
	refs.Fight.Visible = not info.Snapped
	refs.Release.Visible = not info.Snapped
	refs.Title.Text = if info.Snapped then "💥 ¡DEMASIADO PESADO!" else "¡HA PICADO ALGO GORDO!"
	decision.Visible = true
	UIKit.pop(decision, 0.7)

	if info.Snapped then
		UIKit.playSound("Snap")
		local myRun = runId
		task.delay(2.2, function()
			if myRun == runId then
				HUD.Toast("💥 El sedal se rompió nada más picar. ¡Necesitas una caña mejor!", "Error")
				finish()
			end
		end)
	end
end

local function onHooked(info: any)
	if not info.ok then
		if info.Lost then
			HUD.Toast(info.err or "Se escapó", "Warning")
			finish()
		else
			release(info.err, "Error")
		end
		return
	end
	local rarity = Memes.Rarities[info.Rarity]
	local meme = info.MemeId and Memes.Get(info.MemeId)
	fightRefs.Name.Text = (if meme then meme.Name else "???") .. "  ·  " .. (Memes.PersonalityNames[info.Personality] or "")
	fightRefs.Name.TextColor3 = rarity.Color
	fightRefs.Weight.Text = ("⚖️ ~%s / 🎣 %s"):format(FishMath.FormatWeight(info.EstimatedWeight), FishMath.FormatWeight(info.Capacity))
	if info.Snapped or info.Survival < 1 then
		fightRefs.PendingInfo = info
		showDecision(info)
	else
		startFight(info)
	end
end

-- ===== Lanzar y esperar =====

local function waterTarget(power: number): Vector3?
	local _, _, hrp = getCharacter()
	if not hrp then
		return nil
	end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return nil
	end
	flat = flat.Unit
	local dist = F.CastMinDistance + (F.CastMaxDistance - F.CastMinDistance) * power
	local pond = GameConfig.Pond
	local target = Vector3.new(hrp.Position.X, pond.SurfaceY, hrp.Position.Z) + flat * dist
	local fromCenter = Vector3.new(target.X - pond.Center.X, 0, target.Z - pond.Center.Z)
	if fromCenter.Magnitude > pond.WaterRadius - 2 then
		return nil
	end
	return target
end

local function waitForBite(delay: number, myRun: number)
	phase = "Waiting"
	setCastText("⏳\nESPERA…", T.PanelLight)
	local t0 = os.clock()
	local nextNibble = t0 + math.random() * 1.2 + 0.8
	while os.clock() - t0 < delay do
		if myRun ~= runId or currentPhase() ~= "Waiting" then
			return
		end
		local now = os.clock()
		local dip = 0
		if now >= nextNibble and now < nextNibble + 0.15 and delay - (now - t0) > 0.6 then
			dip = 0.3 -- amago
		elseif now >= nextNibble + 0.15 then
			nextNibble = now + 0.7 + math.random() * 1.6
		end
		setBobberPos(bobberBase + Vector3.new(0, 0.12 * math.sin(now * 2.2) - dip, 0))
		RunService.RenderStepped:Wait()
	end
	if myRun ~= runId or currentPhase() ~= "Waiting" then
		return
	end

	-- ¡PICADA!
	phase = "Bite"
	setCastText("❗\n¡YA!", T.Danger)
	biteLabel.Visible = true
	UIKit.pop(biteLabel, 1.6)
	UIKit.playSound("Bite")
	if bobber then
		splash(bobberBase, 4)
	end
	local biteStart = os.clock()
	while os.clock() - biteStart < F.HookWindow do
		if myRun ~= runId or currentPhase() ~= "Bite" then
			return
		end
		setBobberPos(bobberBase + Vector3.new(0, -0.8 + 0.1 * math.sin(os.clock() * 30), 0))
		RunService.RenderStepped:Wait()
	end
	if myRun == runId and currentPhase() == "Bite" then
		release("🐟 Se escapó… ¡toca más rápido cuando salga el \"!\"!", "Warning")
	end
end

local function cast(power: number)
	local target = waterTarget(power)
	if not target then
		HUD.Toast("🌊 Apunta al agua (mira hacia la charca)", "Warning")
		finish()
		return
	end
	phase = "Casting"
	runId += 1
	local myRun = runId
	setCastText("🎣", T.PanelLight)
	local result = State.Call("Cast", power, useReinforced)
	if myRun ~= runId then
		return
	end
	if not result.ok then
		HUD.Toast(result.err or "No se pudo lanzar", "Error")
		finish()
		return
	end
	if result.Perfect then
		HUD.Toast("✨ ¡Lanzamiento PERFECTO! +suerte", "Success")
	end
	if result.Reinforced then
		useReinforced = false
	end

	-- vuelo del corcho
	local tip = rodTip()
	local from = if tip then tip.WorldPosition else target
	makeBobber(from)
	local t0 = os.clock()
	while os.clock() - t0 < 0.55 do
		if myRun ~= runId then
			return
		end
		local a = (os.clock() - t0) / 0.55
		setBobberPos(from:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 8, 0))
		RunService.RenderStepped:Wait()
	end
	bobberBase = target + Vector3.new(0, 0.25, 0)
	setBobberPos(bobberBase)
	splash(target, 5)
	UIKit.playSound("Splash")
	-- el servidor empezó a contar al recibir el lanzamiento; descontamos el vuelo
	waitForBite(math.max(0.3, result.BiteDelay - 0.55 - (os.clock() - t0 - 0.55)), myRun)
end

local chargeStart = 0
local chargeConn: RBXScriptConnection? = nil

local function chargePower(): number
	-- ida y vuelta 0 → 1 → 0
	local x = ((os.clock() - chargeStart) * 0.9) % 2
	return if x <= 1 then x else 2 - x
end

local function startCharging()
	if phase ~= "Idle" or CatchCard.IsOpen() then
		return
	end
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) == "string" and carrying ~= "" then
		HUD.Toast("🏠 Primero lleva el meme a tu parcela (o guárdalo en la mochila)", "Warning")
		return
	end
	local _, _, hrp = getCharacter()
	if not hrp then
		return
	end
	local offset = hrp.Position - GameConfig.Pond.Center
	if Vector2.new(offset.X, offset.Z).Magnitude > GameConfig.Pond.FishingRadius then
		HUD.Toast("🚶 Acércate al agua para pescar", "Warning")
		return
	end
	phase = "Charging"
	State.Busy = true
	lockMovement()
	chargeStart = os.clock()
	powerFrame.Visible = true
	setCastText("🎣\nSUELTA", T.Primary)
	chargeConn = RunService.RenderStepped:Connect(function()
		powerFill.Size = UDim2.fromScale(1, chargePower())
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

-- ===== Entrada =====

local function onPrimaryDown()
	if phase == "Idle" then
		startCharging()
	elseif phase == "Waiting" then
		release("😱 ¡Demasiado pronto! Lo has asustado.", "Warning")
	elseif phase == "Bite" then
		phase = "Hooking"
		biteLabel.Visible = false
		local myRun = runId
		task.spawn(function()
			local info = State.Call("Hook")
			if myRun == runId then
				onHooked(info)
			end
		end)
	elseif phase == "Fighting" then
		holding = true
	end
end

local function onPrimaryUp()
	holding = false
	if phase == "Charging" then
		stopCharging()
	end
end

local function isPrimary(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.F
end

-- ===== Construcción de la UI =====

local function buildUI()
	gui = UIKit.new("ScreenGui", { Name = "PescaFishing", ResetOnSpawn = false, DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- botón principal
	local corner = UIKit.new("Frame", { Name = "CastArea", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(240, 220), BackgroundTransparency = 1, Parent = gui })
	UIKit.responsive(corner)
	castButton = UIKit.button({ Name = "Cast", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(150, 150), Parent = corner }, { Color = T.Primary, Radius = 75, StrokeThickness = 5, HoverScale = 1.04 })
	castLabel = UIKit.label({ Text = "🎣\nLANZAR", Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10),
		Font = T.FontTitle, Parent = castButton }, { Stroke = 3, MaxSize = 34 })
	castButton.MouseButton1Down:Connect(onPrimaryDown)

	reinforcedButton = UIKit.button({ Name = "Reinforced", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -160, 1, -4),
		Size = UDim2.fromOffset(74, 54), Parent = corner }, { Color = T.PanelLight, Radius = 14 })
	reinforcedLabel = UIKit.label({ Text = "🧵 0", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), Font = T.Font,
		Parent = reinforcedButton }, { MaxSize = 20 })
	reinforcedButton.Activated:Connect(function()
		if phase ~= "Idle" then
			return
		end
		useReinforced = not useReinforced
		HUD.Toast(if useReinforced then "🧵 Sedal Reforzado ACTIVADO para el próximo lanzamiento (+25 % capacidad)" else "🧵 Sedal Reforzado desactivado", "Info")
		FishingController.RefreshReinforced()
	end)

	-- barra de fuerza (vertical, junto al botón)
	powerFrame = UIKit.new("Frame", { Name = "Power", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -164, 1, -64),
		Size = UDim2.fromOffset(34, 150), BackgroundColor3 = T.PanelDark, Visible = false, Parent = corner })
	UIKit.corner(powerFrame, 10)
	UIKit.stroke(powerFrame, 3)
	UIKit.new("Frame", { Name = "Perfect", AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1 - F.PerfectPower.Min), Size = UDim2.fromScale(1, F.PerfectPower.Max - F.PerfectPower.Min),
		BackgroundColor3 = T.Coin, BackgroundTransparency = 0.2, ZIndex = 3, Parent = powerFrame })
	powerFill = UIKit.new("Frame", { Name = "Fill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0), BackgroundColor3 = T.Accent, ZIndex = 2, Parent = powerFrame })
	UIKit.corner(powerFill, 10)

	-- aviso de picada
	biteLabel = UIKit.label({ Name = "Bite", Text = "❗ ¡TOCA YA! ❗", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(520, 90), Font = T.FontTitle, TextColor3 = T.Danger, Visible = false, Parent = gui }, { Stroke = 5, MaxSize = 72 })
	UIKit.responsive(biteLabel)

	-- panel de decisión (PELEAR / SOLTAR)
	decision = UIKit.new("Frame", { Name = "Decision", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 300), BackgroundColor3 = T.Panel, Visible = false, Parent = gui })
	UIKit.corner(decision, 22)
	UIKit.stroke(decision, 5, T.PrimaryDark)
	UIKit.responsive(decision)
	local d = {}
	d.Title = UIKit.label({ Text = "¡HA PICADO ALGO GORDO!", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 10),
		Font = T.FontTitle, TextColor3 = T.Primary, Parent = decision }, { Stroke = 3, MaxSize = 34 })
	d.Name = UIKit.label({ Text = "???", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 58), Font = T.FontTitle,
		Parent = decision }, { Stroke = 3, MaxSize = 30 })
	d.Weight = UIKit.label({ Text = "", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 96), Font = T.Font,
		Parent = decision }, { MaxSize = 26 })
	local survBar = UIKit.new("Frame", { Size = UDim2.new(1, -60, 0, 26), Position = UDim2.fromOffset(30, 136), BackgroundColor3 = T.PanelDark, Parent = decision })
	UIKit.corner(survBar, 13)
	UIKit.stroke(survBar, 3)
	d.SurvivalFill = UIKit.new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = T.Primary, Parent = survBar })
	UIKit.corner(d.SurvivalFill, 13)
	d.SurvivalText = UIKit.label({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 168), Font = T.Font,
		Parent = decision }, { MaxSize = 22 })
	local row = UIKit.new("Frame", { Size = UDim2.new(1, -40, 0, 70), Position = UDim2.new(0, 20, 1, -86), BackgroundTransparency = 1, Parent = decision })
	UIKit.list(row, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	d.Fight = UIKit.button({ LayoutOrder = 1, Size = UDim2.fromOffset(190, 66), Parent = row }, { Color = T.Danger, Text = "⚔️ PELEAR", TextSize = 30 })
	d.Release = UIKit.button({ LayoutOrder = 2, Size = UDim2.fromOffset(190, 66), Parent = row }, { Color = T.PanelLight, Text = "✂️ SOLTAR", TextSize = 30 })
	d.Fight.Activated:Connect(function()
		if phase ~= "Deciding" or not fightRefs.PendingInfo then
			return
		end
		phase = "Engaging"
		local myRun = runId
		local r = State.Call("Engage")
		if myRun ~= runId then
			return
		end
		if r.ok then
			startFight(fightRefs.PendingInfo)
		else
			HUD.Toast(r.err or "Se escapó", "Warning")
			finish()
		end
	end)
	d.Release.Activated:Connect(function()
		if phase == "Deciding" then
			release("✂️ Lo has soltado. ¡Mejor suerte con el siguiente!", "Info")
		end
	end)
	fightRefs.Decision = d

	-- panel de pelea
	fight = UIKit.new("Frame", { Name = "Fight", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(640, 190), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Visible = false, Parent = gui })
	UIKit.corner(fight, 20)
	UIKit.stroke(fight, 4)
	UIKit.responsive(fight)
	fightRefs.Name = UIKit.label({ Text = "", Size = UDim2.new(0.62, -10, 0, 30), Position = UDim2.fromOffset(16, 8), Font = T.FontTitle,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = fight }, { Stroke = 2, MaxSize = 26 })
	fightRefs.Weight = UIKit.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0.38, -10, 0, 30),
		Position = UDim2.new(1, -16, 0, 8), Font = T.Font, TextXAlignment = Enum.TextXAlignment.Right, Parent = fight }, { MaxSize = 22 })

	local bar = UIKit.new("Frame", { Name = "Bar", Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -40, 0, 46),
		BackgroundColor3 = T.PanelDark, ClipsDescendants = false, Parent = fight })
	UIKit.corner(bar, 12)
	UIKit.stroke(bar, 3)
	fightRefs.Bar = bar
	fightRefs.Green = UIKit.new("Frame", { Name = "Green", Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = T.Success, Parent = bar })
	UIKit.corner(fightRefs.Green, 10)
	fightRefs.Red = UIKit.new("Frame", { Name = "Red", BackgroundColor3 = T.Danger, BackgroundTransparency = 0.35, Parent = bar })
	UIKit.corner(fightRefs.Red, 10)
	UIKit.label({ Text = "💥", Size = UDim2.fromScale(1, 1), Parent = fightRefs.Red }, { Stroke = false })
	fightRefs.Indicator = UIKit.new("Frame", { Name = "Indicator", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 10, 1, 18),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = bar })
	UIKit.corner(fightRefs.Indicator, 5)
	UIKit.stroke(fightRefs.Indicator, 3)

	local progress = UIKit.new("Frame", { Name = "Progress", Position = UDim2.fromOffset(20, 106), Size = UDim2.new(1, -40, 0, 22),
		BackgroundColor3 = T.PanelDark, Parent = fight })
	UIKit.corner(progress, 11)
	UIKit.stroke(progress, 3)
	fightRefs.ProgressFill = UIKit.new("Frame", { Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = T.Primary, Parent = progress })
	UIKit.corner(fightRefs.ProgressFill, 11)
	fightRefs.TugMarkers = {}
	for i, threshold in ipairs(F.TugThresholds) do
		local m = UIKit.new("Frame", { Name = "Tug" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(threshold, 0.5),
			Size = UDim2.fromOffset(16, 30), BackgroundColor3 = T.Primary, ZIndex = 4, Parent = progress })
		UIKit.corner(m, 4)
		UIKit.stroke(m, 2)
		fightRefs.TugMarkers[i] = m
	end

	fightRefs.Survival = UIKit.label({ Text = "", Size = UDim2.new(0.6, -20, 0, 24), Position = UDim2.fromOffset(16, 140), Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = fight }, { MaxSize = 20 })
	UIKit.label({ Text = "Mantén pulsado = más tensión", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0.4, 0, 0, 24),
		Position = UDim2.new(1, -16, 0, 140), Font = T.Font, TextColor3 = T.TextDim, TextXAlignment = Enum.TextXAlignment.Right,
		Parent = fight }, { MaxSize = 18 })
	fightRefs.Tug = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(560, 50), Font = T.FontTitle, TextColor3 = T.Coin, Visible = false, Parent = fight }, { Stroke = 4, MaxSize = 40 })
end

function FishingController.RefreshReinforced()
	local data = State.Data
	local count = data and data.Items and data.Items.SedalReforzado or 0
	if not reinforcedButton then
		return
	end
	reinforcedButton.Visible = count > 0
	if count <= 0 then
		useReinforced = false
	end
	reinforcedLabel.Text = "🧵 " .. count
	reinforcedButton.BackgroundColor3 = if useReinforced then T.Success else T.PanelLight
end

function FishingController.Init()
	buildUI()
	State.Changed:Connect(FishingController.RefreshReinforced)
	FishingController.RefreshReinforced()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isPrimary(input) then
			return
		end
		-- clic/toque en el mundo: solo cuenta a partir de la espera (para lanzar se usa el botón o F)
		if phase == "Idle" and input.KeyCode ~= Enum.KeyCode.F then
			return
		end
		onPrimaryDown()
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPrimary(input) then
			onPrimaryUp()
		end
	end)

	player.CharacterRemoving:Connect(function()
		if phase ~= "Idle" then
			savedMovement = nil
			release(nil)
		end
	end)
end

return FishingController
