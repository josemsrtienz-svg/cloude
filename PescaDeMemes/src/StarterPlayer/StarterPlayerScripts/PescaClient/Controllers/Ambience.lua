--[[
	PescaDeMemes • Ambience (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > Ambience

	Animaciones de ambiente, solo visuales y solo en tu pantalla (no gastan red ni servidor):
	  · Los memes expuestos en las parcelas (etiqueta "PescaMemeDisplay") botan y se balancean.
	  · Al cobrar tu parcela, una lluvia de monedas sale del cobrador.
	  · VIDA EN EL RÍO: peces de colores que saltan, delfines que hacen piruetas, una familia de patos
	    que pasea y gaviotas volando en círculos. Solo cerca de la cámara.
	  · GRAN TIENDA: el tendero saluda y, si tienes un boost gratis, el regalo gira, brilla y un rastro
	    verde te lleva hasta él.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)

local Ambience = {}

local TAG = "PescaMemeDisplay"
local NEAR = 160 -- studs: más lejos no se anima (rendimiento)

type Entry = { Base: CFrame, Phase: number, Speed: number }
local displays: { [Model]: Entry } = {}

local function track(inst: Instance)
	if inst:IsA("Model") and not displays[inst] then
		displays[inst] = { Base = inst:GetPivot(), Phase = math.random() * 6, Speed = 0.8 + math.random() * 0.6 }
	end
end

local function coinBurst(at: Vector3)
	for _ = 1, 14 do
		local coin = UIKit.new("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.1, 1.1), Color = Color3.fromRGB(255, 200, 50),
			Material = Enum.Material.SmoothPlastic, Reflectance = 0.2, CanCollide = false, CanQuery = false, CanTouch = false,
			CFrame = CFrame.new(at) * CFrame.Angles(0, math.random() * 6, math.rad(90)), Parent = Workspace })
		coin.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), math.random(18, 30), math.random(-10, 10))
		coin.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), 0)
		task.delay(1.4, function()
			coin:Destroy()
		end)
	end
	UIKit.playSound("Coins")
end

-- ===== Fauna del río (modelos de bloques, solo locales) =====

local RGB = Color3.fromRGB
local RIVER = GameConfig.River
local rng = Random.new()
local fauna: Folder

local function block(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

local function wedge(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = offset
	w.Color = color
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Parent = model
	return w
end

local FISH_COLORS = { RGB(255, 140, 40), RGB(70, 170, 255), RGB(255, 90, 150), RGB(255, 210, 60), RGB(90, 210, 110) }

-- Pez de colores: cuerpo, aleta dorsal, cola en V, ojos y franja (el frente es -Z).
local function makeFish(): Model
	local m = Instance.new("Model")
	m.Name = "JumpingFish"
	local color = FISH_COLORS[rng:NextInteger(1, #FISH_COLORS)]
	local body = block(m, "Body", Vector3.new(0.7, 0.9, 1.8), CFrame.new(), color)
	m.PrimaryPart = body
	block(m, "Stripe", Vector3.new(0.72, 0.92, 0.25), CFrame.new(0, 0, 0.2), RGB(250, 250, 250))
	block(m, "Belly", Vector3.new(0.6, 0.2, 1.4), CFrame.new(0, -0.4, 0), color:Lerp(Color3.new(1, 1, 1), 0.5))
	wedge(m, "Dorsal", Vector3.new(0.12, 0.5, 0.7), CFrame.new(0, 0.65, 0.1), color:Lerp(Color3.new(0, 0, 0), 0.25))
	block(m, "TailTop", Vector3.new(0.12, 0.6, 0.5), CFrame.new(0, 0.25, 1.1) * CFrame.Angles(math.rad(-35), 0, 0), color:Lerp(Color3.new(0, 0, 0), 0.25))
	block(m, "TailBottom", Vector3.new(0.12, 0.6, 0.5), CFrame.new(0, -0.25, 1.1) * CFrame.Angles(math.rad(35), 0, 0), color:Lerp(Color3.new(0, 0, 0), 0.25))
	for _, x in ipairs({ -0.36, 0.36 }) do
		block(m, "Eye", Vector3.new(0.05, 0.2, 0.2), CFrame.new(x, 0.15, -0.6), RGB(20, 20, 25))
	end
	return m
end

-- Delfín: cuerpo largo gris, vientre claro, hocico, aleta dorsal, aletas laterales y cola horizontal.
local function makeDolphin(): Model
	local m = Instance.new("Model")
	m.Name = "Dolphin"
	local grey, light = RGB(120, 140, 165), RGB(215, 225, 235)
	local body = block(m, "Body", Vector3.new(1.5, 1.4, 4.2), CFrame.new(), grey)
	m.PrimaryPart = body
	block(m, "Belly", Vector3.new(1.2, 0.4, 3.6), CFrame.new(0, -0.6, -0.1), light)
	block(m, "Head", Vector3.new(1.3, 1.2, 1.0), CFrame.new(0, 0.05, -2.5), grey)
	block(m, "Snout", Vector3.new(0.6, 0.4, 0.9), CFrame.new(0, -0.25, -3.3), grey)
	block(m, "Smile", Vector3.new(0.62, 0.06, 0.6), CFrame.new(0, -0.35, -3.1), RGB(60, 70, 85))
	for _, x in ipairs({ -1, 1 }) do
		block(m, "Eye", Vector3.new(0.05, 0.22, 0.22), CFrame.new(x * 0.66, 0.2, -2.6), RGB(20, 20, 25))
		block(m, "Flipper", Vector3.new(0.9, 0.12, 0.6), CFrame.new(x * 1.0, -0.4, -0.9) * CFrame.Angles(0, 0, x * -0.5), grey)
	end
	wedge(m, "Dorsal", Vector3.new(0.18, 0.9, 1.1), CFrame.new(0, 1.1, 0.3), grey)
	block(m, "Tail", Vector3.new(0.7, 0.7, 1.3), CFrame.new(0, 0.1, 2.6), grey)
	block(m, "Fluke", Vector3.new(2.0, 0.15, 0.7), CFrame.new(0, 0.1, 3.4), grey)
	return m
end

local function makeDuck(scale: number, isMother: boolean): Model
	local m = Instance.new("Model")
	m.Name = "Duck"
	local bodyColor = if isMother then RGB(245, 245, 240) else RGB(255, 225, 80)
	local body = block(m, "Body", Vector3.new(1.2, 0.9, 1.7) * scale, CFrame.new(), bodyColor)
	m.PrimaryPart = body
	block(m, "TailTip", Vector3.new(0.6, 0.4, 0.5) * scale, CFrame.new(0, 0.35 * scale, 0.9 * scale) * CFrame.Angles(math.rad(-30), 0, 0), bodyColor)
	block(m, "Head", Vector3.new(0.8, 0.8, 0.8) * scale, CFrame.new(0, 0.85 * scale, -0.75 * scale), if isMother then RGB(60, 140, 80) else bodyColor)
	block(m, "Beak", Vector3.new(0.5, 0.18, 0.5) * scale, CFrame.new(0, 0.75 * scale, -1.3 * scale), RGB(255, 150, 40))
	for _, x in ipairs({ -1, 1 }) do
		block(m, "Wing", Vector3.new(0.12, 0.5, 1.0) * scale, CFrame.new(x * 0.62 * scale, 0.1 * scale, 0.1 * scale), bodyColor:Lerp(Color3.new(0, 0, 0), 0.1))
		block(m, "Eye", Vector3.new(0.05, 0.14, 0.14) * scale, CFrame.new(x * 0.41 * scale, 0.95 * scale, -0.95 * scale), RGB(20, 20, 25))
	end
	return m
end

local function makeGull(): (Model, Part, Part)
	local m = Instance.new("Model")
	m.Name = "Seagull"
	local body = block(m, "Body", Vector3.new(0.7, 0.7, 1.8), CFrame.new(), RGB(245, 245, 245))
	m.PrimaryPart = body
	block(m, "Head", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0.25, -1.0), RGB(250, 250, 250))
	block(m, "Beak", Vector3.new(0.18, 0.15, 0.5), CFrame.new(0, 0.15, -1.5), RGB(255, 190, 40))
	block(m, "Tail", Vector3.new(0.6, 0.12, 0.6), CFrame.new(0, 0, 1.1), RGB(80, 80, 90))
	local left = block(m, "WingL", Vector3.new(2.4, 0.1, 0.8), CFrame.new(-1.5, 0.1, 0), RGB(190, 195, 205))
	local right = block(m, "WingR", Vector3.new(2.4, 0.1, 0.8), CFrame.new(1.5, 0.1, 0), RGB(190, 195, 205))
	block(m, "WingTipL", Vector3.new(0.6, 0.12, 0.6), CFrame.new(-2.5, 0.1, 0), RGB(60, 60, 70))
	block(m, "WingTipR", Vector3.new(0.6, 0.12, 0.6), CFrame.new(2.5, 0.1, 0), RGB(60, 60, 70))
	return m, left, right
end

local function ripple(at: Vector3, size: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 1, 1)
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = fauna
	UIKit.tween(ring, 0.8, { Size = Vector3.new(0.1, size, size), Transparency = 1 })
	task.delay(0.85, function()
		ring:Destroy()
	end)
end

-- Un salto en arco: sale del agua, gira según la velocidad y vuelve a entrar con salpicadura.
local function leap(model: Model, from: Vector3, to: Vector3, peak: number, duration: number)
	model.Parent = fauna
	ripple(from, 4)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) / duration
		if a >= 1 then
			conn:Disconnect()
			ripple(to, 5)
			model:Destroy()
			return
		end
		local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * peak, 0)
		local dir = (to - from).Unit
		local slope = math.cos(a * math.pi) * peak * math.pi / (to - from).Magnitude
		model:PivotTo(CFrame.lookAt(p, p + dir + Vector3.new(0, slope, 0)))
	end)
end

local function cameraNearRiver(): (boolean, Vector3)
	local camera = Workspace.CurrentCamera
	local pos = if camera then camera.CFrame.Position else Vector3.zero
	return math.abs(pos.X) < 220 and pos.Y < 400, pos
end

local function riverPointNear(z: number): Vector3
	local zz = math.clamp(z + rng:NextNumber(-70, 70), RIVER.MinZ + 8, RIVER.MaxZ - 8)
	return Vector3.new(rng:NextNumber(-RIVER.HalfWidth + 5, RIVER.HalfWidth - 5), RIVER.SurfaceY, zz)
end

local function startWildlife()
	fauna = Instance.new("Folder")
	fauna.Name = "PescaFauna"
	fauna.Parent = Workspace

	-- peces que saltan
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(1.2, 2.6))
			local near, cam = cameraNearRiver()
			if near then
				local from = riverPointNear(cam.Z)
				local angle = rng:NextNumber(0, math.pi * 2)
				local to = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(5, 9)
				to = Vector3.new(math.clamp(to.X, -RIVER.HalfWidth + 2, RIVER.HalfWidth - 2), to.Y, to.Z)
				leap(makeFish(), from, to, rng:NextNumber(3.5, 6.5), rng:NextNumber(0.8, 1.1))
			end
		end
	end)
	-- delfines (a veces en pareja)
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(14, 24))
			local near, cam = cameraNearRiver()
			if near then
				local from = Vector3.new(rng:NextNumber(-RIVER.HalfWidth * 0.4, RIVER.HalfWidth * 0.4), RIVER.SurfaceY, math.clamp(cam.Z - 30, RIVER.MinZ + 20, RIVER.MaxZ - 45))
				local to = from + Vector3.new(0, 0, 24)
				leap(makeDolphin(), from, to, 9, 2.2)
				if rng:NextNumber() < 0.5 then
					task.wait(0.35)
					leap(makeDolphin(), from + Vector3.new(4, 0, -3), to + Vector3.new(4, 0, -3), 7.5, 2.2)
				end
			end
		end
	end)
	-- familia de patos paseando en óvalo junto a una orilla
	local family = { makeDuck(1.3, true) }
	for _ = 1, 3 do
		table.insert(family, makeDuck(0.7, false))
	end
	for _, duck in ipairs(family) do
		duck.Parent = fauna
	end
	-- gaviotas en círculos
	local gulls = {}
	for k = 1, 3 do
		local m, left, right = makeGull()
		m.Parent = fauna
		table.insert(gulls, { Model = m, Left = left, Right = right, Radius = rng:NextNumber(30, 50), Height = rng:NextNumber(28, 40),
			Speed = rng:NextNumber(0.12, 0.2) * (if k % 2 == 0 then -1 else 1), Phase = rng:NextNumber(0, 6), CenterZ = rng:NextNumber(-80, 80) })
	end
	RunService.RenderStepped:Connect(function()
		if not cameraNearRiver() then
			return -- lejos del río no se anima nada
		end
		local now = os.clock()
		-- patos: la madre delante y los patitos en fila detrás
		for i, duck in ipairs(family) do
			local t = now * 0.05 - (i - 1) * 0.012
			local x = RIVER.HalfWidth * 0.55 + math.cos(t * math.pi * 2) * 9
			local z = math.sin(t * math.pi * 2) * 60
			local nx = RIVER.HalfWidth * 0.55 + math.cos((t + 0.002) * math.pi * 2) * 9
			local nz = math.sin((t + 0.002) * math.pi * 2) * 60
			local p = Vector3.new(x, RIVER.SurfaceY + 0.35 + math.sin(now * 3 + i) * 0.06, z)
			duck:PivotTo(CFrame.lookAt(p, Vector3.new(nx, p.Y, nz)))
		end
		-- gaviotas: vuelan en círculo y aletean
		for _, g in ipairs(gulls) do
			local a = now * g.Speed * math.pi * 2 + g.Phase
			local p = Vector3.new(math.cos(a) * g.Radius, g.Height + math.sin(now * 0.7 + g.Phase) * 2, g.CenterZ + math.sin(a) * g.Radius)
			local ahead = a + 0.05 * math.sign(g.Speed)
			local q = Vector3.new(math.cos(ahead) * g.Radius, p.Y, g.CenterZ + math.sin(ahead) * g.Radius)
			local base = CFrame.lookAt(p, q) * CFrame.Angles(0, 0, -0.25 * math.sign(g.Speed))
			g.Model:PivotTo(base)
			local flap = math.sin(now * 8 + g.Phase) * 0.5
			g.Left.CFrame = base * CFrame.new(-0.3, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.2, 0, 0)
			g.Right.CFrame = base * CFrame.new(0.3, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.2, 0, 0)
		end
	end)
end

-- ===== Gran Tienda: tendero que saluda y regalo del boost gratis =====

local function startShop()
	local map = Workspace:WaitForChild("Map", 30)
	local hub = map and map:WaitForChild("Hub", 30)
	local shop = hub and hub:WaitForChild("Shop", 30)
	if not shop then
		return
	end
	local player = Players.LocalPlayer
	local keeper = shop:FindFirstChild("Shopkeeper")
	local arm = keeper and keeper:FindFirstChild("ArmR") :: BasePart?
	local armBase = arm and arm.CFrame
	local gift = shop:FindFirstChild("GiftPedestal")
	local giftParts: { [BasePart]: CFrame } = {}
	local ring = gift and gift:FindFirstChild("Ring") :: BasePart?
	local pedestal = gift and gift:FindFirstChild("Pedestal") :: BasePart?
	if gift then
		for _, name in ipairs({ "Box", "RibbonA", "RibbonB", "Bow" }) do
			local p = gift:FindFirstChild(name) :: BasePart?
			if p then
				giftParts[p] = p.CFrame
			end
		end
	end
	local tag: BillboardGui? = nil
	if pedestal then
		tag = UIKit.new("BillboardGui", { Name = "FreeTag", Size = UDim2.fromOffset(240, 50), StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
			AlwaysOnTop = true, MaxDistance = 400, LightInfluence = 0, Enabled = false, Parent = pedestal })
		UIKit.label({ Text = "🎁 ¡TU BOOST GRATIS!", Size = UDim2.fromScale(1, 1), Font = UIKit.Theme.FontTitle, TextColor3 = UIKit.Theme.Success,
			Parent = tag }, { Stroke = 3 })
	end
	-- rastro verde desde el jugador hasta el regalo mientras haya uno esperando
	local beam: Beam? = nil
	local beamAtts: { Attachment } = {}
	local function setGuide(on: boolean)
		if beam then
			beam:Destroy()
			beam = nil
		end
		for _, a in ipairs(beamAtts) do
			a:Destroy()
		end
		table.clear(beamAtts)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if on and hrp and pedestal then
			local a0 = UIKit.new("Attachment", { Position = Vector3.new(0, -2.5, 0), Parent = hrp })
			local a1 = UIKit.new("Attachment", { Position = Vector3.new(0, 1, 0), Parent = pedestal })
			beamAtts = { a0, a1 }
			beam = UIKit.new("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 1, Width1 = 1, FaceCamera = true, LightInfluence = 0,
				Color = ColorSequence.new(UIKit.Theme.Success), Transparency = NumberSequence.new(0.4), Segments = 20, Parent = hrp })
		end
	end
	local function hasFree(): boolean
		return player:GetAttribute("FreeBoost") ~= nil
	end
	local function refreshFree()
		local on = hasFree()
		if tag then
			tag.Enabled = on
		end
		setGuide(on)
		if not on then
			for p, base in pairs(giftParts) do
				p.CFrame = base
			end
			if ring then
				ring.Transparency = 0.5
			end
		end
	end
	player:GetAttributeChangedSignal("FreeBoost"):Connect(refreshFree)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		refreshFree()
	end)
	refreshFree()

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera or not pedestal or (camera.CFrame.Position - pedestal.Position).Magnitude > 180 then
			return -- solo se anima si la tienda está cerca de la cámara
		end
		local now = os.clock()
		-- el tendero saluda 2 s de cada 6
		if arm and armBase then
			local phase = now % 6
			local wave = if phase < 2 then 2.2 + math.sin(phase * math.pi * 3) * 0.5 else 0
			local top = armBase * CFrame.new(0, arm.Size.Y / 2, 0)
			arm.CFrame = top * CFrame.Angles(0, 0, wave) * CFrame.new(0, -arm.Size.Y / 2, 0)
		end
		-- el regalo gira y bota si tienes un boost gratis esperando
		if hasFree() then
			for p, base in pairs(giftParts) do
				local center = base.Position
				p.CFrame = CFrame.new(center + Vector3.new(0, 0.6 + math.sin(now * 3) * 0.3, 0)) * CFrame.Angles(0, now * 1.5, 0) * base.Rotation
			end
			if ring then
				ring.Transparency = 0.2 + math.abs(math.sin(now * 3)) * 0.5
			end
		end
	end)
end

function Ambience.Init()
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		displays[inst :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local now = os.clock()
		for model, e in pairs(displays) do
			if not model.Parent then
				displays[model] = nil
			elseif (e.Base.Position - camPos).Magnitude < NEAR then
				local t = now * e.Speed + e.Phase
				local hop = math.abs(math.sin(t * 2)) * 0.5
				model:PivotTo(e.Base * CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(t) * 0.35, math.sin(t * 2) * 0.04))
			end
		end
	end)

	task.spawn(startWildlife)
	task.spawn(startShop)

	-- lluvia de monedas al cobrar (el servidor pone PlotBank a 0)
	local player = Players.LocalPlayer
	local lastBank = player:GetAttribute("PlotBank")
	player:GetAttributeChangedSignal("PlotBank"):Connect(function()
		local bank = player:GetAttribute("PlotBank")
		if type(lastBank) == "number" and lastBank > 0 and bank == 0 then
			local index = player:GetAttribute("PlotIndex")
			local map = Workspace:FindFirstChild("Map")
			local plots = map and map:FindFirstChild("Plots")
			local plot = plots and type(index) == "number" and plots:FindFirstChild("Plot" .. index)
			local collector = plot and plot:FindFirstChild("Collector") :: BasePart?
			if collector then
				coinBurst(collector.Position + Vector3.new(0, 1, 0))
			end
		end
		lastBank = bank
	end)
end

return Ambience
