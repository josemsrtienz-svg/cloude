--[[
	PescaDeMemes • DiveScene (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > DiveScene

	La escena SUBMARINA de cada lanzamiento (como en los juegos de pescar huevos): una columna de agua
	vista de lado, con los memes flotando a distintas profundidades, su rareza y sus kg encima, y el anzuelo
	bajando. Es SOLO LOCAL (cada jugador tiene la suya, lejos del mapa): nadie choca con nadie.

	DIRECCIÓN DE ARTE
	  Agua:      fondo en franjas de azul claro → azul marino según la profundidad; rayos de luz arriba.
	  Paredes:   rocas de bloques a los lados, algas verdes y corales rosas/morados/amarillos de bloques.
	  Fondo:     arena con cofre, ancla, conchas y burbujas subiendo.
	  Etiquetas: "RAREZA / 12.4 kg" en el color de la rareza; los kg en verde (se engancha), naranja ⚔️
	             (pelea: pesa más que tu caña) o rojo ⛔ (demasiado pesado: el anzuelo lo atraviesa).

	Unidades: la lógica va en METROS (x de -LaneHalfWidth a +LaneHalfWidth, profundidad hacia abajo);
	la escena usa Dive.StudsPerMeter studs por metro.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local FishMath = require(Root.Shared.FishMath)
local MemeModels = require(Root.Shared.MemeModels)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)

local D = GameConfig.Dive
local T = UIKit.Theme
local RGB = Color3.fromRGB
local S = D.StudsPerMeter
local ORIGIN = Vector3.new(4000, 3000, 0) -- lejos del mapa: escena privada de este jugador
local MEME_SCALE = 0.42
local CAM_DIST = 30
local WIDE = 220 -- ancho del fondo para que nunca se vea el cielo por los lados

local DiveScene = {}

type MemeView = {
	Spec: any,
	Model: Model,
	Height: number,
	Label: BillboardGui,
	State: string, -- "free" | "attached" | "gone" | "blocked"
	Bob: number,
	Slot: number,
}

local folder: Folder? = nil
local memeViews: { MemeView } = {}
local hook: Model? = nil
local lineTop: BasePart? = nil
local capacity = 1
local maxDepth = 15
local attachedCount = 0
local savedCamera: { Type: Enum.CameraType, CFrame: CFrame, FOV: number, Subject: Instance? }? = nil
local tint: ColorCorrectionEffect? = nil

local rng = Random.new()

local function world(x: number, depth: number): Vector3
	return ORIGIN + Vector3.new(x * S, -depth * S, 0)
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ===== Decorado =====

local WATER_TOP = RGB(70, 190, 230)
local WATER_DEEP = RGB(10, 40, 95)
local CORALS = { RGB(255, 110, 170), RGB(190, 90, 255), RGB(255, 200, 60), RGB(255, 140, 90) }
local WEEDS = { RGB(60, 190, 90), RGB(40, 160, 80), RGB(90, 210, 110) }

-- Alga de bloques: una columna de cubos que se tuerce un poco.
local function seaweed(parent: Instance, base: Vector3, height: number)
	local x = 0
	for k = 0, height - 1 do
		x += rng:NextNumber(-0.35, 0.35)
		block(parent, "Weed", Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(x, k + 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			WEEDS[rng:NextInteger(1, #WEEDS)], Enum.Material.SmoothPlastic)
	end
end

-- Coral de bloques: tronco con ramas cortas.
local function coral(parent: Instance, base: Vector3)
	local color = CORALS[rng:NextInteger(1, #CORALS)]
	local h = rng:NextInteger(2, 4)
	for k = 0, h - 1 do
		block(parent, "Coral", Vector3.new(0.8, 1, 0.8), CFrame.new(base + Vector3.new(0, k + 0.5, 0)), color)
	end
	for _, side in ipairs({ -1, 1 }) do
		local by = rng:NextInteger(1, h - 1)
		block(parent, "Branch", Vector3.new(0.8, 0.6, 0.6), CFrame.new(base + Vector3.new(side * 0.8, by + 0.3, 0)), color)
		block(parent, "BranchTip", Vector3.new(0.6, 1, 0.6), CFrame.new(base + Vector3.new(side * 1.2, by + 1.1, 0)), color:Lerp(Color3.new(1, 1, 1), 0.25))
	end
end

local function rock(parent: Instance, center: Vector3, size: Vector3)
	local c = RGB(70, 85, 110):Lerp(RGB(40, 50, 75), rng:NextNumber())
	block(parent, "Rock", size, CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), c, Enum.Material.Slate)
	block(parent, "RockTop", size * Vector3.new(0.6, 0.5, 0.7), CFrame.new(center + Vector3.new(rng:NextNumber(-0.5, 0.5), size.Y * 0.6, 0)),
		c:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Slate)
end

local function chest(parent: Instance, base: Vector3)
	block(parent, "Chest", Vector3.new(3, 2, 2), CFrame.new(base + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0.3, 0), RGB(120, 75, 40), Enum.Material.WoodPlanks)
	block(parent, "ChestLid", Vector3.new(3.1, 0.8, 2.1), CFrame.new(base + Vector3.new(0, 2.3, -0.2)) * CFrame.Angles(-0.4, 0.3, 0), RGB(140, 90, 50), Enum.Material.WoodPlanks)
	block(parent, "Gold", Vector3.new(2.4, 0.4, 1.4), CFrame.new(base + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0.3, 0), RGB(255, 205, 40), Enum.Material.Neon)
end

local function anchor(parent: Instance, base: Vector3)
	local c = RGB(45, 50, 60)
	block(parent, "AnchorShaft", Vector3.new(0.6, 5, 0.6), CFrame.new(base + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, 0.25), c, Enum.Material.Metal)
	block(parent, "AnchorBar", Vector3.new(3, 0.5, 0.6), CFrame.new(base + Vector3.new(-0.6, 4.6, 0)) * CFrame.Angles(0, 0, 0.25), c, Enum.Material.Metal)
	block(parent, "AnchorFluke", Vector3.new(4, 0.6, 0.6), CFrame.new(base + Vector3.new(0.6, 0.4, 0)) * CFrame.Angles(0, 0, 0.25), c, Enum.Material.Metal)
end

local function buildDecor(parent: Instance)
	local lane = D.LaneHalfWidth * S
	local depthStuds = (maxDepth + 2) * S
	local floorY = ORIGIN.Y - depthStuds
	-- fondo en franjas: de azul claro a azul marino
	local bands = 12
	local bandH = (depthStuds + 30) / bands
	for k = 0, bands - 1 do
		local depthFrac = math.clamp((k * bandH) / (60 * S + 30), 0, 1)
		local color = WATER_TOP:Lerp(WATER_DEEP, depthFrac)
		block(parent, "Water", Vector3.new(WIDE, bandH + 0.2, 2), CFrame.new(ORIGIN + Vector3.new(0, 10 - (k + 0.5) * bandH, 18)), color)
	end
	-- superficie vista desde abajo
	block(parent, "Surface", Vector3.new(WIDE, 1, 70), CFrame.new(ORIGIN + Vector3.new(0, 1.5, -15)), RGB(170, 235, 255), Enum.Material.Glass, 0.25)
	-- rayos de luz
	for k = 1, 7 do
		local x = rng:NextNumber(-lane * 1.6, lane * 1.6)
		block(parent, "LightRay", Vector3.new(rng:NextNumber(3, 7), 50, 0.2), CFrame.new(ORIGIN + Vector3.new(x, -22, 12 - k * 0.3))
			* CFrame.Angles(0, 0, math.rad(rng:NextNumber(12, 22))), RGB(220, 250, 255), Enum.Material.Neon, 0.88)
	end
	-- suelo de arena
	block(parent, "Sand", Vector3.new(WIDE, 4, 70), CFrame.new(Vector3.new(ORIGIN.X, floorY - 2, ORIGIN.Z - 15)), RGB(225, 205, 150), Enum.Material.Sand)
	-- rocas y algas en los laterales, a lo largo de toda la profundidad
	for _, side in ipairs({ -1, 1 }) do
		local y = ORIGIN.Y - 4
		while y > floorY do
			local w = rng:NextNumber(5, 9)
			rock(parent, Vector3.new(ORIGIN.X + side * (lane + 3 + w / 2), y, ORIGIN.Z + rng:NextNumber(-2, 6)), Vector3.new(w, rng:NextNumber(4, 7), 6))
			if rng:NextNumber() < 0.5 then
				seaweed(parent, Vector3.new(ORIGIN.X + side * (lane + 1.5), y - 2, ORIGIN.Z + 4), rng:NextInteger(3, 6))
			end
			y -= rng:NextNumber(5, 8)
		end
	end
	-- fondo: algas, corales, cofre, ancla
	for k = 1, 12 do
		local x = ORIGIN.X + rng:NextNumber(-lane * 1.4, lane * 1.4)
		local base = Vector3.new(x, floorY, ORIGIN.Z + rng:NextNumber(0, 10))
		if k % 3 == 0 then
			coral(parent, base)
		else
			seaweed(parent, base, rng:NextInteger(3, 7))
		end
	end
	chest(parent, Vector3.new(ORIGIN.X - lane * 0.5, floorY, ORIGIN.Z + 6))
	anchor(parent, Vector3.new(ORIGIN.X + lane * 0.6, floorY, ORIGIN.Z + 7))
	-- marcas de profundidad cada 10 m en el fondo
	for m = 10, maxDepth, 10 do
		local mark = block(parent, "DepthMark", Vector3.new(lane * 2, 0.15, 0.2), CFrame.new(world(0, m) + Vector3.new(0, 0, 16.8)), RGB(200, 240, 255), Enum.Material.Neon, 0.75)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(80, 30)
		bb.StudsOffsetWorldSpace = Vector3.new(-lane - 2, 0, 0)
		bb.LightInfluence = 0
		bb.Parent = mark
		UIKit.label({ Text = m .. " m", Size = UDim2.fromScale(1, 1), Font = T.FontTitle, TextColor3 = RGB(200, 240, 255), Parent = bb }, { Stroke = 2 })
	end
	-- burbujas subiendo
	for k = 1, 4 do
		local emitterPart = block(parent, "Bubbles", Vector3.new(1, 1, 1), CFrame.new(Vector3.new(ORIGIN.X + (k - 2.5) * lane * 0.7, floorY + 1, ORIGIN.Z + 4)),
			Color3.new(1, 1, 1), nil, 1)
		local e = Instance.new("ParticleEmitter")
		e.Rate = 3
		e.Lifetime = NumberRange.new(6, 9)
		e.Speed = NumberRange.new(4, 7)
		e.SpreadAngle = Vector2.new(8, 8)
		e.Size = NumberSequence.new(0.35)
		e.Transparency = NumberSequence.new(0.4)
		e.LightEmission = 0.4
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = emitterPart
	end
end

-- ===== Anzuelo =====

local function buildHook(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Hook"
	local sinker = block(m, "Sinker", Vector3.one * 0.9, CFrame.new(), RGB(230, 60, 60), Enum.Material.SmoothPlastic)
	sinker.Shape = Enum.PartType.Ball
	m.PrimaryPart = sinker
	local metal = RGB(200, 205, 215)
	block(m, "Shank", Vector3.new(0.18, 1.6, 0.18), CFrame.new(0, -1.2, 0), metal, Enum.Material.Metal)
	block(m, "Bend", Vector3.new(0.9, 0.18, 0.18), CFrame.new(0.36, -1.95, 0), metal, Enum.Material.Metal)
	block(m, "Point", Vector3.new(0.18, 0.7, 0.18), CFrame.new(0.72, -1.65, 0), metal, Enum.Material.Metal)
	block(m, "Barb", Vector3.new(0.3, 0.15, 0.15), CFrame.new(0.6, -1.35, 0) * CFrame.Angles(0, 0, 0.7), metal, Enum.Material.Metal)
	local att = Instance.new("Attachment")
	att.Name = "LineEnd"
	att.Parent = sinker
	m.Parent = parent
	-- el sedal baja desde la superficie, justo encima del anzuelo
	local top = block(parent, "LineTop", Vector3.one * 0.2, CFrame.new(ORIGIN), Color3.new(1, 1, 1), nil, 1)
	local a0 = Instance.new("Attachment")
	a0.Parent = top
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = att
	beam.Width0 = 0.12
	beam.Width1 = 0.12
	beam.FaceCamera = true
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(RGB(245, 245, 245))
	beam.Parent = top
	lineTop = top
	return m
end

-- ===== Memes =====

local function labelText(spec: any): (string, Color3)
	local kind = FishMath.GrabKind(spec.Weight, capacity)
	local kg = FishMath.FormatWeight(spec.Weight)
	if kind == "fight" then
		return "⚔️ " .. kg, T.PrimaryDark
	elseif kind == "heavy" then
		return "⛔ " .. kg, T.Danger
	end
	return kg, T.Success
end

local function buildMeme(parent: Instance, spec: any, index: number): MemeView?
	if not MemeModels.Has(spec.MemeId) then
		return nil
	end
	local model = MemeModels.Build(spec.MemeId, MEME_SCALE, spec.Golden)
	model.Name = "DiveMeme" .. index
	local height = MemeModels.Height(spec.MemeId, MEME_SCALE)
	local rarity = Memes.GetRarity(spec.MemeId)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Tag"
	bb.Size = UDim2.fromOffset(130, 52)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height + 1.2, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	UIKit.label({ Name = "Rarity", Text = (if spec.Golden then "✨ " else "") .. rarity.Name, Size = UDim2.new(1, 0, 0.5, 0),
		Font = T.FontTitle, TextColor3 = if spec.Golden then T.Coin else rarity.Color, Parent = bb }, { Stroke = 2 })
	local text, color = labelText(spec)
	UIKit.label({ Name = "Weight", Text = text, Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.5),
		Font = T.FontTitle, TextColor3 = color, Parent = bb }, { Stroke = 2 })
	model.Parent = parent
	return { Spec = spec, Model = model, Height = height, Label = bb, State = "free", Bob = rng:NextNumber(0, 6), Slot = 0 }
end

-- ===== API =====

-- spec = respuesta de Cast (Memes, Capacity, MaxDepth…)
function DiveScene.Build(spec: any)
	DiveScene.Destroy()
	capacity = spec.Capacity
	maxDepth = spec.MaxDepth
	attachedCount = 0
	local f = Instance.new("Folder")
	f.Name = "DiveScene"
	folder = f
	buildDecor(f)
	hook = buildHook(f)
	memeViews = {}
	for i, m in ipairs(spec.Memes) do
		local view = buildMeme(f, m, i)
		if view then
			memeViews[i] = view
		end
	end
	f.Parent = Workspace
	DiveScene.Update(0, 0, 0)
end

function DiveScene.Destroy()
	if folder then
		folder:Destroy()
		folder = nil
	end
	memeViews = {}
	hook = nil
	lineTop = nil
end

-- Mueve anzuelo, memes y cámara. t = segundos de inmersión (para el nado), x/depth en metros.
function DiveScene.Update(t: number, x: number, depth: number)
	if not hook or not lineTop then
		return
	end
	local hookPos = world(x, depth)
	hook:PivotTo(CFrame.new(hookPos) * CFrame.Angles(0, 0, math.sin(t * 2) * 0.08))
	lineTop.CFrame = CFrame.new(world(x, -1))
	local now = os.clock()
	for _, view in pairs(memeViews) do
		if view.State == "free" or view.State == "blocked" then
			-- solo se animan los que están cerca de la cámara
			if math.abs(view.Spec.Depth - depth) < 22 then
				local mx = FishMath.SwimX(view.Spec, t)
				local vx = math.cos(view.Spec.Freq * t + view.Spec.Phase) -- hacia dónde nada
				local bob = math.sin(now * 1.6 + view.Bob) * 0.25
				local base = world(mx, view.Spec.Depth) - Vector3.new(0, view.Height / 2 - bob, 0)
				view.Model:PivotTo(CFrame.new(base) * CFrame.Angles(0, -vx * 0.45 * math.sign(view.Spec.Amp), math.sin(now * 2 + view.Bob) * 0.05))
			end
		elseif view.State == "attached" then
			-- colgando del anzuelo, uno debajo de otro, balanceándose
			local below = 1.6 + (view.Slot - 1) * (view.Height + 0.4)
			local sway = math.sin(now * 3 + view.Slot) * 0.15
			view.Model:PivotTo(CFrame.new(hookPos - Vector3.new(0, below + view.Height, 0)) * CFrame.Angles(0, now * 1.5, sway))
		end
	end
	-- la cámara sigue al anzuelo, un poco por debajo para ver lo que viene
	local camera = Workspace.CurrentCamera
	if camera and savedCamera then
		local floorY = ORIGIN.Y - (maxDepth + 2) * S
		local camY = math.clamp(hookPos.Y - 3, floorY + 12, ORIGIN.Y - 10)
		local focus = Vector3.new(ORIGIN.X + x * S * 0.25, camY, ORIGIN.Z)
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 1.5, -CAM_DIST), focus - Vector3.new(0, 1, 0))
	end
end

-- Meme (índice) que toca el anzuelo en (x, depth), o nil. Ignora los ya probados (`tried`).
function DiveScene.Touching(t: number, x: number, depth: number, tried: { [number]: boolean }): number?
	for i, view in pairs(memeViews) do
		if view.State == "free" and not tried[i] then
			local dx = FishMath.SwimX(view.Spec, t) - x
			local dy = view.Spec.Depth - depth
			if dx * dx + dy * dy <= D.GrabRadius * D.GrabRadius then
				return i
			end
		end
	end
	return nil
end

function DiveScene.Attach(index: number)
	local view = memeViews[index]
	if not view then
		return
	end
	attachedCount += 1
	view.State = "attached"
	view.Slot = attachedCount
	view.Label.Enabled = false
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 0
	sparkle.Speed = NumberRange.new(6, 10)
	sparkle.Lifetime = NumberRange.new(0.4, 0.7)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Color = ColorSequence.new(Memes.GetRarity(view.Spec.MemeId).Color)
	sparkle.LightEmission = 1
	sparkle.Parent = view.Model.PrimaryPart or view.Model:FindFirstChildWhichIsA("BasePart")
	sparkle:Emit(25)
end

-- El meme se va nadando (soltado o escapado) y desaparece.
function DiveScene.Remove(index: number)
	local view = memeViews[index]
	if not view or view.State == "gone" then
		return
	end
	view.State = "gone"
	view.Label.Enabled = false
	local model = view.Model
	local from = model:GetPivot()
	local dir = if rng:NextNumber() < 0.5 then -1 else 1
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.7 and model.Parent do
			local a = (os.clock() - t0) / 0.7
			model:PivotTo(from * CFrame.new(dir * a * 14, -a * 3, 0) * CFrame.Angles(0, dir * a * 2, 0))
			task.wait()
		end
		model:Destroy()
	end)
end

-- Aviso visual sobre un meme que no se puede enganchar (no cabe, demasiado pesado…).
function DiveScene.Block(index: number, text: string)
	local view = memeViews[index]
	if not view then
		return
	end
	view.State = "blocked"
	local weight = view.Label:FindFirstChild("Weight") :: TextLabel?
	if weight then
		weight.Text = text
		weight.TextColor3 = T.Danger
	end
end

function DiveScene.Grabbed(): number
	return attachedCount
end

-- Posición horizontal (m) bajo un punto de la pantalla (InputObject.Position del ratón o del dedo).
function DiveScene.ScreenToX(screen: Vector2): number?
	local camera = Workspace.CurrentCamera
	if not camera or not savedCamera then
		return nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	if math.abs(ray.Direction.Z) < 1e-4 then
		return nil
	end
	local t = (ORIGIN.Z - ray.Origin.Z) / ray.Direction.Z
	local px = ray.Origin.X + ray.Direction.X * t
	return (px - ORIGIN.X) / S
end

-- Datos para el medidor de profundidad: [índice] = { Depth, Color, Free } de cada meme.
function DiveScene.Markers(): { [number]: { Depth: number, Color: Color3, Free: boolean } }
	local list = {}
	for i, view in pairs(memeViews) do
		list[i] = { Depth = view.Spec.Depth, Color = Memes.GetRarity(view.Spec.MemeId).Color, Free = view.State == "free" }
	end
	return list
end

-- ===== Cámara y ambiente =====

function DiveScene.Enter()
	local camera = Workspace.CurrentCamera
	if not camera or savedCamera then
		return
	end
	savedCamera = { Type = camera.CameraType, CFrame = camera.CFrame, FOV = camera.FieldOfView, Subject = camera.CameraSubject }
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "PescaDiveTint"
	cc.TintColor = RGB(200, 235, 255)
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Parent = Lighting
	tint = cc
end

function DiveScene.Exit()
	local camera = Workspace.CurrentCamera
	if tint then
		tint:Destroy()
		tint = nil
	end
	if camera and savedCamera then
		camera.CameraType = savedCamera.Type
		camera.FieldOfView = savedCamera.FOV
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = humanoid or savedCamera.Subject
	end
	savedCamera = nil
end

function DiveScene.Active(): boolean
	return savedCamera ~= nil
end

return DiveScene
