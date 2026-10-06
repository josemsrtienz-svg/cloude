--[[
	PescaDeMemes • WorldBuilder (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > WorldBuilder

	Construye el mapa por script (estilo "en fila" de los juegos de steal).

	DIRECCIÓN DE ARTE (referencia: captura del jugador, juegos tipo Steal a Brainrot/Egg)
	  Estilo:        Roblox clásico de juguete: casillas con STUDS, colores vivos, formas cuadradas.
	  Suelo:         césped en tablero de ajedrez de dos verdes, con studs. Camino de arena junto al río.
	  Paredes:       muros altos de tierra en casillas marrones (cierran el mapa como en la referencia).
	  Composición:   pasillo largo; RÍO en el centro; 4 parcelas a cada lado mirando al río.
	  Parcelas:      plataforma de césped más claro, valla de madera en X, 8 huecos en el césped para los
	                 memes (sin estantes), cartel del dueño con su color, círculo cobrador verde y
	                 SU PROPIO MUELLE que entra en el río (solo se pesca desde el tuyo).
	  Entrada:       arco "PESCA DE MEMES", spawn y tienda con toldo a rayas (al norte).
	  Detalle:       puentes con barandilla, nenúfares y boyas en el río, arbustos junto a las paredes.

	Jerarquía: Workspace > Map > { Ground, Walls, River, Plots > PlotN { Spots, Displays, ... }, Hub, Nature }
	Las medidas salen de GameConfig.River y GameConfig.Plots (no las dupliques aquí).
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local GearModels = require(Root.Shared.GearModels)

local WorldBuilder = {}


local RGB = Color3.fromRGB
local rng = Random.new(20261006) -- semilla fija: el mapa sale siempre igual

local PALETTE = {
	Wood = RGB(150, 104, 66),
	WoodDark = RGB(105, 70, 45),
	WoodLight = RGB(196, 150, 100),
	Roof = RGB(196, 82, 64),
	Brand = RGB(255, 205, 40),
	Pink = RGB(255, 90, 150),
	White = RGB(245, 240, 230),
	Leaf = { RGB(92, 168, 72), RGB(70, 145, 62), RGB(120, 186, 80) },
	Rock = RGB(128, 128, 136),
	Glass = RGB(190, 235, 255),
}

-- ===== Helpers de construcción =====

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	local p = new("Part", {
		Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic,
		Anchored = true, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, Parent = parent,
	})
	for k, v in pairs(extra or {}) do
		(p :: any)[k] = v
	end
	return p
end

-- cilindro vertical (los cilindros de Roblox van a lo largo del eje X)
local function post(parent: Instance, name: string, diameter: number, height: number, base: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material or Enum.Material.Wood)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function disc(parent: Instance, name: string, diameter: number, thickness: number, center: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, Vector3.new(thickness, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, Vector3.one * diameter, CFrame.new(center), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function folder(parent: Instance, name: string): Folder
	return new("Folder", { Name = name, Parent = parent })
end

local function sign(parent: Instance, name: string, size: Vector3, cf: CFrame, text: string, bg: Color3, fg: Color3): Part
	local board = part(parent, name, size, cf, bg, Enum.Material.WoodPlanks)
	local gui = new("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40, LightInfluence = 0.6, Parent = board })
	local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text,
		Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = fg, Parent = gui })
	new("UIStroke", { Thickness = 4, Color = RGB(40, 25, 15), Parent = label })
	new("UIPadding", { PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0),
		PaddingTop = UDim.new(0.08, 0), PaddingBottom = UDim.new(0.08, 0), Parent = label })
	return board
end

local function lantern(parent: Instance, base: Vector3, height: number)
	local m = folder(parent, "Lantern")
	post(m, "Pole", 0.5, height, base, PALETTE.WoodDark)
	part(m, "Arm", Vector3.new(1.6, 0.3, 0.3), CFrame.new(base + Vector3.new(0.6, height - 0.2, 0)), PALETTE.WoodDark, Enum.Material.Wood)
	local cage = part(m, "Cage", Vector3.new(0.9, 1.1, 0.9), CFrame.new(base + Vector3.new(1.2, height - 1, 0)), RGB(50, 45, 40), Enum.Material.Metal)
	cage.Transparency = 0.2
	local bulb = ball(m, "Bulb", 0.6, base + Vector3.new(1.2, height - 1, 0), RGB(255, 210, 130), Enum.Material.Neon)
	new("PointLight", { Color = RGB(255, 200, 130), Range = 16, Brightness = 1.4, Parent = bulb })
end

-- ===== Estilo de casillas con studs =====

local GRASS = { RGB(96, 200, 70), RGB(84, 184, 60) }
local PLOT_GRASS = { RGB(128, 222, 92), RGB(112, 208, 80) }
local SAND = { RGB(236, 210, 150), RGB(222, 194, 134) }
local DIRT = { RGB(186, 128, 84), RGB(168, 112, 72) }

-- Pieza con studs en todas las caras (material Plastic: así Roblox dibuja los studs clásicos).
local function studded(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return part(parent, name, size, cf, color, Enum.Material.Plastic, {
		TopSurface = Enum.SurfaceType.Studs, FrontSurface = Enum.SurfaceType.Studs, BackSurface = Enum.SurfaceType.Studs,
		LeftSurface = Enum.SurfaceType.Studs, RightSurface = Enum.SurfaceType.Studs, BottomSurface = Enum.SurfaceType.Smooth,
	})
end

-- Límites del mapa: salen del río y de las parcelas (redondeados a casillas de 10)
local function roundUp(v: number): number
	return math.ceil(v / 10) * 10
end
local MAP = {
	MaxX = roundUp(GameConfig.Plots.CenterX + GameConfig.Plots.Size / 2 + 14),
	MinX = -roundUp(GameConfig.Plots.CenterX + GameConfig.Plots.Size / 2 + 14),
	MinZ = -roundUp(-GameConfig.River.MinZ + 30),
	MaxZ = roundUp(GameConfig.River.MaxZ + 60),
	Tile = 10,
}

-- ===== Suelo, paredes y río =====

local function buildGround(map: Instance)
	local ground = folder(map, "Ground")
	local river = GameConfig.River
	local T = MAP.Tile
	for x = MAP.MinX + T / 2, MAP.MaxX - T / 2, T do
		for z = MAP.MinZ + T / 2, MAP.MaxZ - T / 2, T do
			local inRiver = math.abs(x) < river.HalfWidth + 1 and z > river.MinZ and z < river.MaxZ
			if not inRiver then
				local checker = (math.floor(x / T) + math.floor(z / T)) % 2 + 1
				local bank = math.abs(x) <= river.HalfWidth + 11 and z > river.MinZ - 6 and z < river.MaxZ + 6
				local palette = if bank then SAND else GRASS
				studded(ground, "Tile", Vector3.new(T, 2, T), CFrame.new(x, -1, z), palette[checker])
			end
		end
	end
end

local function buildWalls(map: Instance)
	local walls = folder(map, "Walls")
	local T, H = 10, 3 -- casillas de 10 studs, 3 filas de alto
	local function wallRun(fixed: number, from: number, to: number, alongX: boolean)
		for a = from + T / 2, to - T / 2, T do
			for row = 0, H - 1 do
				local checker = (math.floor(a / T) + row) % 2 + 1
				local pos = if alongX then Vector3.new(a, row * T + T / 2, fixed) else Vector3.new(fixed, row * T + T / 2, a)
				local size = if alongX then Vector3.new(T, T, 4) else Vector3.new(4, T, T)
				studded(walls, "Wall", size, CFrame.new(pos), DIRT[checker])
			end
		end
		-- borde de césped encima del muro, como en la referencia
		local mid = (from + to) / 2
		local len = to - from
		local pos = if alongX then Vector3.new(mid, H * T + 0.5, fixed) else Vector3.new(fixed, H * T + 0.5, mid)
		local size = if alongX then Vector3.new(len, 1, 4.4) else Vector3.new(4.4, 1, len)
		studded(walls, "WallGrass", size, CFrame.new(pos), GRASS[1])
	end
	wallRun(MAP.MinZ - 2, MAP.MinX, MAP.MaxX, true)
	wallRun(MAP.MaxZ + 2, MAP.MinX, MAP.MaxX, true)
	wallRun(MAP.MinX - 2, MAP.MinZ, MAP.MaxZ, false)
	wallRun(MAP.MaxX + 2, MAP.MinZ, MAP.MaxZ, false)
end

local function buildRiver(map: Instance)
	local riverFolder = folder(map, "River")
	local r = GameConfig.River
	local terrain = Workspace.Terrain
	terrain:Clear()
	local length = r.MaxZ - r.MinZ
	local width = r.HalfWidth * 2 + 2
	terrain:FillBlock(CFrame.new(0, -11, (r.MinZ + r.MaxZ) / 2), Vector3.new(width, 4, length), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -5 + r.SurfaceY / 2, (r.MinZ + r.MaxZ) / 2), Vector3.new(width, 10 + r.SurfaceY, length), Enum.Material.Water)
	terrain.WaterColor = RGB(40, 180, 210)
	terrain.WaterTransparency = 0.3
	terrain.WaterWaveSize = 0.1
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.35
	-- orillas de arena en casillas
	for _, side in ipairs({ -1, 1 }) do
		for z = r.MinZ + 5, r.MaxZ - 5, 10 do
			local checker = (math.floor(z / 10) + (if side > 0 then 1 else 0)) % 2 + 1
			studded(riverFolder, "Bank", Vector3.new(2, 10, 10), CFrame.new(side * (r.HalfWidth + 1), -5, z), SAND[checker])
		end
	end
	for _, z in ipairs({ r.MinZ - 1, r.MaxZ + 1 }) do
		studded(riverFolder, "BankEnd", Vector3.new(r.HalfWidth * 2 + 4, 10, 2), CFrame.new(0, -5, z), SAND[1])
	end
	-- puente central con barandilla
	local bridge = folder(riverFolder, "Bridge")
	local bw = 10
	for x = -r.HalfWidth - 4, r.HalfWidth + 4, 2 do
		local color = PALETTE.Wood:Lerp(PALETTE.WoodDark, rng:NextNumber(0, 0.3))
		part(bridge, "Plank", Vector3.new(1.8, 0.5, bw), CFrame.new(x, 0.25, 0), color, Enum.Material.WoodPlanks)
	end
	for _, z in ipairs({ -bw / 2, bw / 2 }) do
		part(bridge, "Rail", Vector3.new(r.HalfWidth * 2 + 10, 0.4, 0.4), CFrame.new(0, 3, z), PALETTE.Wood, Enum.Material.Wood)
		for x = -r.HalfWidth - 4, r.HalfWidth + 4, 6 do
			part(bridge, "RailPost", Vector3.new(0.5, 3, 0.5), CFrame.new(x, 1.5, z), PALETTE.WoodDark, Enum.Material.Wood)
		end
	end
	for x = -r.HalfWidth + 10, r.HalfWidth - 10, 20 do
		for _, z in ipairs({ -bw / 2 + 1, bw / 2 - 1 }) do
			post(bridge, "Pillar", 1.2, 10, Vector3.new(x, -10, z), PALETTE.WoodDark)
		end
	end
end

-- ===== Parcelas =====

-- Color de acento de cada parcela (cartel y muelle) para reconocerla de lejos.
local PLOT_ACCENTS = {
	RGB(255, 205, 40), RGB(255, 90, 150), RGB(70, 170, 255), RGB(90, 210, 110),
	RGB(185, 90, 255), RGB(255, 140, 0), RGB(40, 200, 200), RGB(240, 80, 80),
}

local SPOT_X = { -15, -5, 5, 15 }
local SPOT_Z = { -4, 10 }

-- Valla de madera con cruces en X (como en la referencia).
local function xFence(parent: Instance, a: Vector3, b: Vector3)
	local fence = folder(parent, "Fence")
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local steps = math.max(1, math.floor(length / 5 + 0.5))
	local yaw = math.atan2(dir.X, dir.Z)
	local h = 3
	for k = 0, steps do
		local p = a + dir * (length * k / steps)
		part(fence, "Post", Vector3.new(0.6, h + 0.4, 0.6), CFrame.new(p + Vector3.new(0, (h + 0.4) / 2, 0)), PALETTE.WoodDark, Enum.Material.Wood)
		if k < steps then
			local q = a + dir * (length * (k + 1) / steps)
			local mid = (p + q) / 2
			local seg = (q - p).Magnitude
			local diag = math.sqrt(seg ^ 2 + (h - 0.6) ^ 2)
			local angle = math.atan2(h - 0.6, seg)
			local base = CFrame.new(mid + Vector3.new(0, h / 2 + 0.2, 0)) * CFrame.Angles(0, yaw, 0)
			part(fence, "Cross", Vector3.new(0.3, 0.35, diag), base * CFrame.Angles(angle, 0, 0), RGB(200, 90, 40), Enum.Material.Wood)
			part(fence, "Cross", Vector3.new(0.3, 0.35, diag), base * CFrame.Angles(-angle, 0, 0), RGB(200, 90, 40), Enum.Material.Wood)
		end
	end
	part(fence, "TopRail", Vector3.new(0.4, 0.35, length), CFrame.new((a + b) / 2 + Vector3.new(0, h + 0.2, 0)) * CFrame.Angles(0, yaw, 0),
		RGB(200, 90, 40), Enum.Material.Wood)
	part(fence, "BottomRail", Vector3.new(0.4, 0.35, length), CFrame.new((a + b) / 2 + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, yaw, 0),
		RGB(200, 90, 40), Enum.Material.Wood)
end

local function buildDock(plot: Instance, at: (number, number, number) -> CFrame, accent: Color3)
	local dock = folder(plot, "Dock")
	local half = GameConfig.Plots.Size / 2
	local startZ = -half
	local endZ = -(GameConfig.Plots.CenterX - GameConfig.Plots.DockEndX)
	local z = startZ
	local i = 0
	while z > endZ do
		i += 1
		local color = if i % 4 == 0 then PALETTE.WoodLight else PALETTE.Wood:Lerp(PALETTE.WoodDark, rng:NextNumber(0, 0.3))
		part(dock, "Plank", Vector3.new(7, 0.5, 1.8), at(rng:NextNumber(-0.08, 0.08), 0.25, z - 0.9)
			* CFrame.Angles(0, math.rad(rng:NextNumber(-1, 1)), 0), color, Enum.Material.WoodPlanks)
		-- pilotes del pasillo cada 8 studs (el muelle es largo: el río es ancho)
		if i % 4 == 0 then
			for _, x in ipairs({ -3.2, 3.2 }) do
				local base = at(x, 0, z - 0.9).Position
				post(dock, "Pile", 0.6, 9.6, Vector3.new(base.X, -9.2, base.Z), PALETTE.WoodDark)
			end
		end
		z -= 2
	end
	-- plataforma final para pescar (aquí está GameConfig.DockSpot)
	part(dock, "FishingDeck", Vector3.new(12, 0.6, 7), at(0, 0.3, endZ - 3.5), PALETTE.Wood, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -5.5, 5.5 }) do
		for _, pz in ipairs({ endZ - 0.5, endZ - 6.5 }) do
			local base = at(x, 0, pz).Position
			post(dock, "Post", 0.8, 9.5, Vector3.new(base.X, -9, base.Z), PALETTE.WoodDark)
		end
		part(dock, "Rail", Vector3.new(0.35, 0.35, 6.5), at(x, 2.6, endZ - 3.5), PALETTE.Wood, Enum.Material.Wood)
	end
	-- banderín con el color de la parcela: así se ve de quién es el muelle
	local poleBase = at(5.5, 0.5, endZ - 6.5).Position
	post(dock, "FlagPole", 0.3, 7, poleBase, PALETTE.WoodDark)
	part(dock, "Flag", Vector3.new(0.15, 1.6, 2.4), CFrame.new(poleBase + Vector3.new(0, 6.1, 0)) * at(0, 0, 0).Rotation
		* CFrame.new(0, 0, 1.2), accent, Enum.Material.Fabric)
	lantern(dock, at(-5.5, 0.6, endZ - 6.5).Position, 5.5)
	post(dock, "Bucket", 1.4, 1.2, at(-3.5, 0.6, endZ - 2).Position, RGB(80, 120, 200))
end

local function buildPlot(plots: Instance, index: number)
	local plot = folder(plots, "Plot" .. index)
	plot:SetAttribute("PlotIndex", index)
	local o = GameConfig.PlotCFrame(index)
	local function at(x: number, y: number, z: number): CFrame
		return o * CFrame.new(x, y, z)
	end
	local half = GameConfig.Plots.Size / 2
	local accent = PLOT_ACCENTS[(index - 1) % #PLOT_ACCENTS + 1]

	-- plataforma de césped en casillas
	local tile = GameConfig.Plots.Size / 4
	for ix = 0, 3 do
		for iz = 0, 3 do
			local x = -half + tile * (ix + 0.5)
			local z = -half + tile * (iz + 0.5)
			studded(plot, "PlotTile", Vector3.new(tile, 0.6, tile), at(x, 0.3, z), PLOT_GRASS[(ix + iz) % 2 + 1])
		end
	end
	-- borde de color de la parcela
	for _, side in ipairs({ -1, 1 }) do
		studded(plot, "Border", Vector3.new(0.8, 0.7, half * 2), at(side * (half - 0.4), 0.35, 0), accent)
	end
	studded(plot, "Border", Vector3.new(half * 2, 0.7, 0.8), at(0, 0.35, half - 0.4), accent)

	-- valla en X con entrada hacia el río
	local y = 0.6
	local c = function(x: number, z: number): Vector3
		return at(x, y, z).Position
	end
	xFence(plot, c(-half + 0.5, -half + 0.5), c(-6, -half + 0.5))
	xFence(plot, c(6, -half + 0.5), c(half - 0.5, -half + 0.5))
	xFence(plot, c(half - 0.5, -half + 0.5), c(half - 0.5, half - 0.5))
	xFence(plot, c(half - 0.5, half - 0.5), c(-half + 0.5, half - 0.5))
	xFence(plot, c(-half + 0.5, half - 0.5), c(-half + 0.5, -half + 0.5))

	-- huecos para los memes, directamente sobre el césped (nada de estantes)
	local spots = folder(plot, "Spots")
	local slot = 0
	for _, z in ipairs(SPOT_Z) do
		for _, x in ipairs(SPOT_X) do
			slot += 1
			local spot = part(spots, "Spot" .. slot, Vector3.new(7, 0.1, 7), at(x, 0.65, z), RGB(70, 160, 55), Enum.Material.SmoothPlastic,
				{ Transparency = 0.5, CanCollide = false })
			spot:SetAttribute("Occupied", false)
			new("ProximityPrompt", { Name = "PickupPrompt", ActionText = "Recoger", ObjectText = "Hueco " .. slot,
				HoldDuration = 0.3, MaxActivationDistance = 9, RequiresLineOfSight = false, Parent = spot })
		end
	end
	folder(plot, "Displays")

	-- cartel del dueño al fondo
	for _, x in ipairs({ -7, 7 }) do
		part(plot, "SignPost", Vector3.new(0.8, 9, 0.8), at(x, 5, half - 3), PALETTE.WoodDark, Enum.Material.Wood)
	end
	local ownerSign = sign(plot, "OwnerSign", Vector3.new(16, 3.8, 0.6), at(0, 7.4, half - 3.2), "Parcela libre", accent, PALETTE.White)
	local gui = ownerSign:FindFirstChildWhichIsA("SurfaceGui")
	local label = gui and gui:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Name = "Label"
	end
	part(plot, "SignRoof", Vector3.new(17.5, 0.5, 2.4), at(0, 9.6, half - 3.2) * CFrame.Angles(math.rad(-10), 0, 0), PALETTE.Roof, Enum.Material.Slate)

	-- círculo cobrador (se pisa para cobrar)
	local collector = disc(plot, "Collector", 7, 0.4, at(-half + 6, 0.8, -half + 6).Position, RGB(90, 255, 110), Enum.Material.Neon)
	collector.Transparency = 0.25
	collector.CanCollide = false
	disc(plot, "CollectorRing", 8, 0.3, at(-half + 6, 0.65, -half + 6).Position, RGB(40, 140, 50), Enum.Material.SmoothPlastic)
	local bb = new("BillboardGui", { Name = "Bank", Size = UDim2.fromScale(9, 3.4), StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		MaxDistance = 120, LightInfluence = 0, Parent = collector })
	local bankLabel = new("TextLabel", { Name = "BankLabel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "Cobrador",
		Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = RGB(90, 255, 110), Parent = bb })
	new("UIStroke", { Thickness = 3, Color = RGB(20, 40, 20), Parent = bankLabel })

	-- aparición: en la entrada, mirando al río
	new("Part", { Name = "Spawn", Size = Vector3.new(4, 1, 4), CFrame = at(0, 1.5, -half + 6), Transparency = 1,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })

	-- faroles en la entrada
	lantern(plot, at(-7, 0.6, -half + 1).Position, 6.5)
	lantern(plot, at(7, 0.6, -half + 1).Position, 6.5)

	buildDock(plot, at, accent)
end

local function buildPlots(map: Instance)
	local plots = folder(map, "Plots")
	for index = 1, GameConfig.Plots.Count do
		buildPlot(plots, index)
	end
end

-- ===== Entrada: spawn, arco y tienda =====

-- Cartel legible por las DOS caras (el del arco se ve desde la entrada y desde el río).
local function doubleSign(parent: Instance, name: string, size: Vector3, cf: CFrame, text: string, bg: Color3, fg: Color3, stroke: Color3?): Part
	local board = part(parent, name, size, cf, bg, Enum.Material.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = new("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40,
			LightInfluence = 0, Parent = board })
		new("UIGradient", { Color = ColorSequence.new(bg:Lerp(Color3.new(1, 1, 1), 0.2), bg:Lerp(Color3.new(0, 0, 0), 0.25)), Rotation = 90, Parent = gui })
		local label = new("TextLabel", { Name = "Label", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text,
			Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = fg, Parent = gui })
		new("UIStroke", { Thickness = 6, Color = stroke or RGB(40, 25, 15), Parent = label })
		new("UIPadding", { PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0),
			PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0), Parent = label })
	end
	return board
end

-- Fila de bombillas de colores (marquesina de feria) entre dos puntos.
local function bulbs(parent: Instance, a: Vector3, b: Vector3, count: number)
	local colors = { PALETTE.Brand, PALETTE.Pink, RGB(70, 200, 255), RGB(90, 230, 110) }
	for i = 0, count - 1 do
		local p = a:Lerp(b, i / math.max(1, count - 1))
		ball(parent, "Bulb", 0.7, p, colors[i % #colors + 1], Enum.Material.Neon)
	end
end

-- Pez de bloques gigante para lo alto del arco.
local function bigFish(parent: Instance, cf: CFrame)
	local f = folder(parent, "ArchFish")
	local body, belly, fin = RGB(255, 140, 40), RGB(255, 225, 160), RGB(230, 90, 30)
	part(f, "Body", Vector3.new(2.6, 3.4, 6), cf, body)
	part(f, "Belly", Vector3.new(2.2, 1.2, 4.8), cf * CFrame.new(0, -1.3, 0), belly)
	for k = -1, 1 do
		part(f, "Stripe", Vector3.new(2.65, 3.45, 0.4), cf * CFrame.new(0, 0, k * 1.5), RGB(250, 250, 250))
	end
	part(f, "Tail", Vector3.new(0.5, 3.2, 1.6), cf * CFrame.new(0, 0.9, 3.6) * CFrame.Angles(math.rad(-30), 0, 0), fin)
	part(f, "Tail", Vector3.new(0.5, 3.2, 1.6), cf * CFrame.new(0, -0.9, 3.6) * CFrame.Angles(math.rad(30), 0, 0), fin)
	part(f, "Dorsal", Vector3.new(0.4, 1.4, 2.4), cf * CFrame.new(0, 2.2, 0.4), fin)
	for _, x in ipairs({ -1.32, 1.32 }) do
		part(f, "Eye", Vector3.new(0.12, 0.9, 0.9), cf * CFrame.new(x, 0.6, -2.2), RGB(250, 250, 250))
		part(f, "Pupil", Vector3.new(0.14, 0.5, 0.5), cf * CFrame.new(x * 1.01, 0.55, -2.35), RGB(20, 20, 25))
	end
	part(f, "Mouth", Vector3.new(1.4, 0.3, 0.2), cf * CFrame.new(0, -0.4, -3.05), RGB(120, 30, 40))
end

local function buildHub(map: Instance)
	local hub = folder(map, "Hub")
	local r = GameConfig.River
	local spawnZ = r.MaxZ + 24
	local spawnLoc = new("SpawnLocation", {
		Name = "Spawn", Size = Vector3.new(12, 1, 12), CFrame = CFrame.new(0, 0.5, spawnZ),
		Color = PALETTE.Brand, Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs,
		Anchored = true, Neutral = true, Duration = 0, Parent = hub,
	})
	local decal = spawnLoc:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- ===== ARCO "PESCA DE MEMES" =====
	-- Pilares de piedra en bloques con base y remate, viga gruesa, cartel legible por las dos caras,
	-- marquesina de bombillas y un pez gigante encima: la primera imagen del juego.
	local arch = folder(hub, "Arch")
	local archZ = r.MaxZ + 10
	local stone, stoneDark = RGB(180, 170, 160), RGB(140, 130, 120)
	for _, x in ipairs({ -22, 22 }) do
		studded(arch, "PillarBase", Vector3.new(6, 2, 6), CFrame.new(x, 1, archZ), stoneDark)
		for k = 0, 5 do
			studded(arch, "PillarBlock", Vector3.new(4.4, 3, 4.4), CFrame.new(x, 3.5 + k * 3, archZ) * CFrame.Angles(0, (k % 2) * math.rad(6), 0),
				if k % 2 == 0 then stone else stoneDark)
		end
		studded(arch, "PillarCap", Vector3.new(6, 1.4, 6), CFrame.new(x, 20.7, archZ), stoneDark)
		ball(arch, "Orb", 2.4, Vector3.new(x, 22.6, archZ), PALETTE.Brand, Enum.Material.Neon)
		lantern(arch, Vector3.new(x + (if x > 0 then -4 else 4), 0, archZ - 3), 6)
	end
	studded(arch, "Beam", Vector3.new(50, 3, 4.6), CFrame.new(0, 21, archZ), DIRT[2])
	studded(arch, "BeamTrim", Vector3.new(50.4, 0.8, 5), CFrame.new(0, 19.3, archZ), PALETTE.Pink)
	doubleSign(arch, "ArchSign", Vector3.new(36, 7, 0.8), CFrame.new(0, 15, archZ), "🎣 PESCA DE MEMES", RGB(40, 150, 220), PALETTE.Brand)
	part(arch, "SignFrame", Vector3.new(37.6, 0.8, 1), CFrame.new(0, 18.9, archZ), PALETTE.Brand)
	part(arch, "SignFrame", Vector3.new(37.6, 0.8, 1), CFrame.new(0, 11.1, archZ), PALETTE.Brand)
	for _, x in ipairs({ -18.4, 18.4 }) do
		part(arch, "SignFrame", Vector3.new(0.8, 8.6, 1), CFrame.new(x, 15, archZ), PALETTE.Brand)
	end
	for _, dz in ipairs({ -0.7, 0.7 }) do
		bulbs(arch, Vector3.new(-17.5, 19.5, archZ + dz), Vector3.new(17.5, 19.5, archZ + dz), 15)
		bulbs(arch, Vector3.new(-17.5, 10.5, archZ + dz), Vector3.new(17.5, 10.5, archZ + dz), 15)
	end
	bigFish(arch, CFrame.new(0, 26, archZ) * CFrame.Angles(0, math.rad(90), math.rad(-12)))
	-- anzuelos colgando del arco
	for _, x in ipairs({ -12, 12 }) do
		part(arch, "HookLine", Vector3.new(0.15, 6, 0.15), CFrame.new(x, 8.5, archZ), RGB(240, 240, 240))
		part(arch, "Hook", Vector3.new(0.3, 1.4, 0.3), CFrame.new(x, 5.2, archZ), RGB(200, 205, 215), Enum.Material.Metal)
		part(arch, "HookBend", Vector3.new(1, 0.3, 0.3), CFrame.new(x + 0.4, 4.6, archZ), RGB(200, 205, 215), Enum.Material.Metal)
	end

	-- ===== GRAN TIENDA =====
	-- Al FONDO del eje del río: se ve desde todas las parcelas y el arco la enmarca. Mercado de madera con
	-- columnas de color, tejado a rayas, marquesina de bombillas, mostrador con tendero, estanterías,
	-- RINCÓN VIP (Robux) DENTRO de la tienda, y fuera el TABLÓN del boost gratis (cambia cada 15 min).
	local shop = folder(hub, "Shop")
	local shopZ = r.MaxZ + 46
	local o = CFrame.lookAt(Vector3.new(0, 0, shopZ), Vector3.new(0, 0, shopZ - 1))
	local function at(x: number, y: number, z: number): CFrame
		return o * CFrame.new(x, y, z)
	end
	local W, Dp, H = 38, 18, 12 -- ancho, fondo, alto de pared
	for ix = -6, 6 do
		for iz = -3, 2 do
			studded(shop, "Floor", Vector3.new(3, 0.6, 3), at(ix * 3, 0.3, iz * 3 + 1.5), if (ix + iz) % 2 == 0 then SAND[1] else SAND[2])
		end
	end
	-- escalón de entrada
	studded(shop, "Step", Vector3.new(W, 0.4, 3), at(0, 0.2, -10.5), PALETTE.WoodLight)
	-- pared del fondo y laterales con ventanas
	part(shop, "BackWall", Vector3.new(W, H, 1), at(0, H / 2, Dp / 2), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		part(shop, "SideWall", Vector3.new(1, H, Dp), at(side * W / 2, H / 2, 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
		part(shop, "Window", Vector3.new(1.1, 4, 6), at(side * W / 2, 6, 1), PALETTE.Glass, Enum.Material.Glass, { Transparency = 0.4 })
		part(shop, "WindowFrame", Vector3.new(1.2, 0.5, 6.6), at(side * W / 2, 8.2, 1), PALETTE.WoodDark, Enum.Material.Wood)
		part(shop, "WindowFrame", Vector3.new(1.2, 0.5, 6.6), at(side * W / 2, 3.8, 1), PALETTE.WoodDark, Enum.Material.Wood)
	end
	-- columnas de colores en la fachada
	local colColors = { PALETTE.Pink, PALETTE.Brand, RGB(70, 200, 255), PALETTE.Brand, PALETTE.Pink }
	for i, x in ipairs({ -W / 2, -W / 4, 0, W / 4, W / 2 }) do
		if x ~= 0 then
			studded(shop, "Column", Vector3.new(1.6, H + 2, 1.6), at(x, (H + 2) / 2, -Dp / 2), colColors[i])
			studded(shop, "ColumnCap", Vector3.new(2.2, 0.8, 2.2), at(x, H + 2.2, -Dp / 2), PALETTE.White)
		end
	end
	-- cabecera con el cartel grande
	studded(shop, "Header", Vector3.new(W + 2, 3.2, 1.4), at(0, H + 2.6, -Dp / 2), RGB(60, 200, 80))
	sign(shop, "ShopSign", Vector3.new(26, 4.6, 0.6), at(0, H + 5.6, -Dp / 2 - 0.2), "🛒 GRAN TIENDA", RGB(60, 200, 80), PALETTE.White)
	bulbs(shop, at(-13, H + 8.3, -Dp / 2 - 0.6).Position, at(13, H + 8.3, -Dp / 2 - 0.6).Position, 14)
	bulbs(shop, at(-W / 2, H + 0.6, -Dp / 2 - 0.9).Position, at(W / 2, H + 0.6, -Dp / 2 - 0.9).Position, 20)
	-- tejado a rayas en dos aguas
	for k = 0, 9 do
		local x = -W / 2 - 1 + (k + 0.5) * (W + 2) / 10
		local color = if k % 2 == 0 then RGB(230, 70, 70) else PALETTE.White
		for _, side in ipairs({ -1, 1 }) do
			part(shop, "Roof", Vector3.new((W + 2) / 10, 0.5, Dp / 2 + 2), at(x, H + 2.5, side * (Dp / 4 + 0.5)) * CFrame.Angles(math.rad(side * 18), 0, 0),
				color, Enum.Material.Fabric)
		end
	end
	-- mostrador central con caja registradora
	local counter = part(shop, "Counter", Vector3.new(14, 3.4, 2.4), at(0, 2.3, 1), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(shop, "CounterTop", Vector3.new(14.6, 0.4, 2.8), at(0, 4.1, 1), PALETTE.WoodDark, Enum.Material.Wood)
	for k = -2, 2 do
		part(shop, "CounterPanel", Vector3.new(2.2, 2.4, 0.15), at(k * 2.7, 2.1, -0.25), PALETTE.Wood, Enum.Material.WoodPlanks)
	end
	part(shop, "Register", Vector3.new(1.4, 1, 1), at(4.5, 4.8, 1.1), RGB(70, 70, 80), Enum.Material.Metal)
	part(shop, "RegisterScreen", Vector3.new(1, 0.6, 0.1), at(4.5, 5.3, 0.55), RGB(90, 255, 120), Enum.Material.Neon)
	new("ProximityPrompt", { Name = "ShopPrompt", ActionText = "Abrir la tienda", ObjectText = "Gran Tienda",
		HoldDuration = 0, MaxActivationDistance = 14, RequiresLineOfSight = false, Parent = counter })
	-- estanterías del fondo con cañas y peceras
	for _, y in ipairs({ 2.6, 5.2, 7.8 }) do
		part(shop, "Shelf", Vector3.new(16, 0.3, 1.6), at(0, y, Dp / 2 - 1.3), PALETTE.WoodDark, Enum.Material.Wood)
	end
	for k, color in ipairs({ RGB(150, 105, 60), RGB(40, 110, 220), RGB(255, 205, 40), RGB(60, 30, 90) }) do
		local rod = part(shop, "DisplayRod", Vector3.new(5, 0.22, 0.22), at(-6 + (k - 1) * 4, 7.9, Dp / 2 - 1.3) * CFrame.Angles(0, 0, math.rad(80)),
			color, Enum.Material.SmoothPlastic)
		rod.Shape = Enum.PartType.Cylinder
	end
	for k, color in ipairs({ RGB(150, 220, 255), RGB(90, 210, 110), RGB(70, 160, 255), RGB(185, 90, 255) }) do
		local tank = part(shop, "DisplayTank", Vector3.new(1.6, 1.6, 1.1), at(-6 + (k - 1) * 4, 3.6, Dp / 2 - 1.3), PALETTE.Glass, Enum.Material.Glass)
		tank.Transparency = 0.5
		part(shop, "DisplayTankLid", Vector3.new(1.7, 0.2, 1.2), at(-6 + (k - 1) * 4, 4.5, Dp / 2 - 1.3), color)
	end

	-- el tendero (el cliente le hace saludar)
	local keeper = new("Model", { Name = "Shopkeeper", Parent = shop })
	local skin, shirt, apron = RGB(245, 205, 160), RGB(70, 170, 255), RGB(250, 250, 245)
	for _, x in ipairs({ -0.5, 0.5 }) do
		part(keeper, "Leg", Vector3.new(0.95, 2, 0.95), at(x, 1.6, 3.6), RGB(60, 60, 80))
	end
	part(keeper, "Torso", Vector3.new(2, 2, 1), at(0, 3.6, 3.6), shirt)
	part(keeper, "Apron", Vector3.new(1.6, 2.2, 0.1), at(0, 3.3, 3.05), apron)
	part(keeper, "ArmL", Vector3.new(0.95, 2, 0.95), at(-1.5, 3.6, 3.6), skin)
	part(keeper, "ArmR", Vector3.new(0.95, 2, 0.95), at(1.5, 3.6, 3.6), skin)
	part(keeper, "Head", Vector3.new(1.6, 1.6, 1.6), at(0, 5.4, 3.6), skin)
	part(keeper, "Moustache", Vector3.new(1, 0.25, 0.1), at(0, 5.1, 2.78), RGB(90, 60, 40))
	for _, x in ipairs({ -0.35, 0.35 }) do
		part(keeper, "Eye", Vector3.new(0.25, 0.3, 0.1), at(x, 5.6, 2.78), RGB(30, 30, 35))
	end
	part(keeper, "Cap", Vector3.new(1.8, 0.5, 1.8), at(0, 6.4, 3.6), PALETTE.Pink)
	part(keeper, "CapBrim", Vector3.new(1.8, 0.15, 0.9), at(0, 6.2, 2.5), PALETTE.Pink)
	local root = part(keeper, "Root", Vector3.new(1, 1, 1), at(0, 0.5, 3.6), Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false })
	keeper.PrimaryPart = root

	-- rincón VIP (Robux) DENTRO de la tienda: alfombra morada, cordón dorado y podio con la corona
	local vip = folder(shop, "VipCorner")
	part(vip, "Carpet", Vector3.new(9, 0.1, 8), at(-13, 0.65, 3), RGB(120, 60, 200), Enum.Material.Fabric)
	for _, p in ipairs({ { -17, -1 }, { -9, -1 }, { -9, 7 } }) do
		post(vip, "RopePost", 0.4, 2.4, at(p[1], 0.6, p[2]).Position, PALETTE.Brand, Enum.Material.SmoothPlastic)
	end
	part(vip, "Rope", Vector3.new(8, 0.15, 0.15), at(-13, 2.6, -1), RGB(200, 40, 60), Enum.Material.Fabric)
	part(vip, "Rope", Vector3.new(0.15, 0.15, 8), at(-9, 2.6, 3), RGB(200, 40, 60), Enum.Material.Fabric)
	local podium = post(vip, "Podium", 3, 2.4, at(-13, 0.6, 3).Position, PALETTE.White, Enum.Material.Marble)
	local crown = GearModels.Crown()
	crown:ScaleTo(1.3)
	crown:PivotTo(at(-13, 4, 3))
	crown.Parent = vip
	local gemLight = new("PointLight", { Color = RGB(255, 210, 90), Range = 14, Brightness = 1.2, Parent = podium })
	gemLight.Name = "VipGlow"
	new("ProximityPrompt", { Name = "VipPrompt", ActionText = "Ver pases (Robux)", ObjectText = "VIP",
		HoldDuration = 0, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = podium })

	-- ===== TABLÓN DEL BOOST GRATIS (fuera, a la derecha de la entrada) =====
	-- Estante con un cartel grande que el cliente actualiza: qué boost toca, cuánto dura y cuándo cambia.
	local board = folder(shop, "FreeBoard")
	local bx, bz = W / 2 + 8, -Dp / 2 - 4
	for _, dx in ipairs({ -6.5, 6.5 }) do
		studded(board, "BoardPost", Vector3.new(1.2, 14, 1.2), at(bx + dx, 7, bz), PALETTE.WoodDark)
	end
	studded(board, "BoardTop", Vector3.new(15, 1.2, 2), at(bx, 14.6, bz), RGB(60, 200, 80))
	local panel = part(board, "Panel", Vector3.new(12, 8, 0.6), at(bx, 9, bz), RGB(20, 52, 72), Enum.Material.SmoothPlastic)
	local gui = new("SurfaceGui", { Name = "BoardGui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40, LightInfluence = 0, Parent = panel })
	local function boardLabel(name: string, text: string, y: number, h: number, color: Color3)
		local lbl = new("TextLabel", { Name = name, Size = UDim2.fromScale(0.94, h), Position = UDim2.fromScale(0.03, y), BackgroundTransparency = 1,
			Text = text, Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = color, Parent = gui })
		new("UIStroke", { Thickness = 4, Color = RGB(10, 20, 30), Parent = lbl })
	end
	boardLabel("Title", "🎁 ¡BOOST GRATIS!", 0.04, 0.2, PALETTE.Brand)
	boardLabel("BoostName", "…", 0.27, 0.22, RGB(90, 255, 120))
	boardLabel("Duration", "Tiempo de uso: 5 min", 0.52, 0.13, RGB(255, 255, 255))
	boardLabel("NextIn", "Nuevo en 15:00", 0.68, 0.13, RGB(170, 220, 255))
	boardLabel("Status", "Recógelo en el regalo 👇", 0.84, 0.12, RGB(255, 205, 40))
	bulbs(board, at(bx - 6, 13.5, bz - 0.5).Position, at(bx + 6, 13.5, bz - 0.5).Position, 9)
	-- el estante con el regalo (aquí se recoge)
	local gift = folder(shop, "GiftPedestal")
	part(gift, "ShelfBase", Vector3.new(12, 0.6, 3), at(bx, 3, bz - 1.2), PALETTE.Wood, Enum.Material.WoodPlanks)
	local pedestal = disc(gift, "Pedestal", 3.2, 1, at(bx, 3.8, bz - 1.2).Position, RGB(240, 240, 245), Enum.Material.Marble)
	disc(gift, "Ring", 3.8, 0.2, at(bx, 3.35, bz - 1.2).Position, RGB(90, 255, 120), Enum.Material.Neon).Transparency = 0.5
	part(gift, "Box", Vector3.new(1.6, 1.6, 1.6), at(bx, 5.1, bz - 1.2), RGB(230, 60, 70), Enum.Material.SmoothPlastic)
	part(gift, "RibbonA", Vector3.new(1.65, 1.65, 0.3), at(bx, 5.1, bz - 1.2), PALETTE.Brand, Enum.Material.SmoothPlastic)
	part(gift, "RibbonB", Vector3.new(0.3, 1.65, 1.65), at(bx, 5.1, bz - 1.2), PALETTE.Brand, Enum.Material.SmoothPlastic)
	part(gift, "Bow", Vector3.new(0.9, 0.5, 0.9), at(bx, 6.1, bz - 1.2) * CFrame.Angles(0, math.rad(45), 0), PALETTE.Brand, Enum.Material.SmoothPlastic)
	for _, dx in ipairs({ -5.5, 5.5 }) do
		post(gift, "ShelfLeg", 0.6, 2.7, at(bx + dx, 0, bz - 1.2).Position, PALETTE.WoodDark)
	end
	new("ProximityPrompt", { Name = "GiftPrompt", ActionText = "Recoger boost gratis", ObjectText = "Regalo",
		HoldDuration = 0.4, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = pedestal })

	-- decoración de la plaza: barriles, cajas, bancos y farolas
	post(shop, "Barrel", 2.2, 2.8, at(-W / 2 - 3, 0, -6).Position, PALETTE.Wood)
	part(shop, "Crate", Vector3.new(2, 2, 2), at(-W / 2 - 3, 1, -3) * CFrame.Angles(0, math.rad(15), 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(shop, "Crate", Vector3.new(1.6, 1.6, 1.6), at(-W / 2 - 3, 2.8, -3.2) * CFrame.Angles(0, math.rad(-10), 0), PALETTE.Wood, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -30, 30 }) do
		local bench = folder(hub, "Bench")
		part(bench, "Seat", Vector3.new(5, 0.4, 1.6), CFrame.new(x, 1.4, spawnZ), PALETTE.Wood, Enum.Material.WoodPlanks)
		part(bench, "Back", Vector3.new(5, 1.4, 0.3), CFrame.new(x, 2.3, spawnZ + 0.7), PALETTE.Wood, Enum.Material.WoodPlanks)
		for _, dx in ipairs({ -2, 2 }) do
			part(bench, "Leg", Vector3.new(0.4, 1.2, 1.4), CFrame.new(x + dx, 0.6, spawnZ), PALETTE.WoodDark, Enum.Material.Wood)
		end
		lantern(hub, Vector3.new(x + 4, 0, spawnZ), 7)
	end
end

-- ===== Detalles: nenúfares, boyas, arbustos =====

local function buildNature(map: Instance)
	local nature = folder(map, "Nature")
	local r = GameConfig.River
	-- nenúfares y boyas a lo largo del río, lejos de los muelles
	for z = r.MinZ + 12, r.MaxZ - 12, 28 do
		local x = rng:NextNumber(-r.HalfWidth + 3, r.HalfWidth - 3)
		local pad = disc(nature, "LilyPad", rng:NextNumber(2.4, 3.6), 0.15, Vector3.new(x, r.SurfaceY + 0.05, z), RGB(80, 160, 70), Enum.Material.Grass)
		pad.CanCollide = false
		if rng:NextNumber() < 0.4 then
			ball(nature, "LilyFlower", 0.7, Vector3.new(x + 0.4, r.SurfaceY + 0.35, z + 0.2), PALETTE.Pink).CanCollide = false
		end
	end
	for z = r.MinZ + 30, r.MaxZ - 30, 64 do
		ball(nature, "Buoy", 1.6, Vector3.new(0, r.SurfaceY + 0.3, z), RGB(230, 60, 60))
		ball(nature, "BuoyTop", 1, Vector3.new(0, r.SurfaceY + 1.05, z), PALETTE.White)
	end
	-- arbustos de bloques junto a las paredes laterales
	for z = MAP.MinZ + 15, MAP.MaxZ - 15, 40 do
		for _, side in ipairs({ -1, 1 }) do
			local x = side * (MAP.MaxX - 4)
			studded(nature, "Bush", Vector3.new(5, 4, 6), CFrame.new(x, 2, z), PALETTE.Leaf[rng:NextInteger(1, 3)])
			studded(nature, "BushTop", Vector3.new(3.5, 2, 4), CFrame.new(x, 4.8, z + rng:NextNumber(-1, 1)), PALETTE.Leaf[rng:NextInteger(1, 3)])
		end
	end
end

-- Árbol de bloques: tronco con studs y copa en 3 pisos que se van estrechando (con alguna fruta o flor).
local function tree(parent: Instance, base: Vector3, height: number)
	local t = folder(parent, "Tree")
	local trunk = RGB(120, 80, 50)
	for k = 0, height - 1 do
		studded(t, "Trunk", Vector3.new(1.6, 2, 1.6), CFrame.new(base + Vector3.new(0, 1 + k * 2, 0)), trunk)
	end
	local top = base.Y + height * 2
	local layers = { { 7, 2.6 }, { 5.2, 2.2 }, { 3.2, 1.8 } }
	local y = top
	for i, layer in ipairs(layers) do
		local offset = Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
		studded(t, "Leaves", Vector3.new(layer[1], layer[2], layer[1]), CFrame.new(Vector3.new(base.X, y + layer[2] / 2, base.Z) + offset),
			PALETTE.Leaf[(i + math.floor(base.X)) % 3 + 1])
		y += layer[2]
	end
	if rng:NextNumber() < 0.5 then
		local fruit = if rng:NextNumber() < 0.5 then RGB(230, 60, 60) else PALETTE.Pink
		for _ = 1, 3 do
			ball(t, "Fruit", 0.7, Vector3.new(base.X + rng:NextNumber(-3, 3), top + rng:NextNumber(0.6, 2), base.Z - 3.2), fruit)
		end
	end
end

local FLOWER_COLORS = { RGB(255, 90, 150), RGB(255, 205, 40), RGB(250, 250, 250), RGB(170, 90, 255), RGB(255, 120, 60) }

-- Parche de flores: tallos verdes con una cabeza de color (grupos, no flores sueltas por todas partes).
local function flowers(parent: Instance, center: Vector3, count: number)
	local f = folder(parent, "Flowers")
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for _ = 1, count do
		local p = center + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		part(f, "Stem", Vector3.new(0.2, 0.9, 0.2), CFrame.new(p + Vector3.new(0, 0.45, 0)), RGB(70, 150, 60))
		part(f, "Bloom", Vector3.new(0.6, 0.4, 0.6), CFrame.new(p + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), color)
	end
end

local function buildGreenery(map: Instance)
	local green = folder(map, "Greenery")
	local plots = GameConfig.Plots
	local half = plots.Size / 2
	-- árboles detrás de las parcelas (entre la valla y la pared)
	for z = MAP.MinZ + 20, MAP.MaxZ - 50, 26 do
		for _, side in ipairs({ -1, 1 }) do
			tree(green, Vector3.new(side * (MAP.MaxX - 9), 0, z + rng:NextNumber(-3, 3)), rng:NextInteger(2, 4))
		end
	end
	-- entre filas de parcelas: un árbol y flores a cada lado
	for i = 1, #plots.Z - 1 do
		local z = (plots.Z[i] + plots.Z[i + 1]) / 2
		for _, side in ipairs({ -1, 1 }) do
			tree(green, Vector3.new(side * (plots.CenterX + half - 8), 0, z), rng:NextInteger(2, 3))
			flowers(green, Vector3.new(side * (plots.CenterX - 6), 0, z + 4), 8)
			flowers(green, Vector3.new(side * (plots.CenterX + 8), 0, z - 5), 6)
			studded(green, "Rock", Vector3.new(3, 1.6, 2.4), CFrame.new(side * (plots.CenterX - half + 6), 0.8, z - 6)
				* CFrame.Angles(0, rng:NextNumber(0, 1), 0), PALETTE.Rock)
		end
	end
	-- flores junto a la entrada
	for _, x in ipairs({ -26, -12, 12, 26 }) do
		flowers(green, Vector3.new(x, 0, GameConfig.River.MaxZ + 18), 7)
	end
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = RGB(120, 120, 120)
	Lighting.OutdoorAmbient = RGB(160, 160, 160)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or new("Atmosphere", { Parent = Lighting })
	atmosphere.Density = 0.2
	atmosphere.Haze = 0.5
	atmosphere.Color = RGB(200, 225, 245)
	atmosphere.Decay = RGB(140, 180, 220)
	if not Lighting:FindFirstChild("PescaColor") then
		new("ColorCorrectionEffect", { Name = "PescaColor", Saturation = 0.2, Contrast = 0.05, Parent = Lighting })
	end
end

function WorldBuilder.Build()
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local map = new("Folder", { Name = "Map", Parent = Workspace })
	buildGround(map)
	buildWalls(map)
	buildRiver(map)
	buildPlots(map)
	buildHub(map)
	buildNature(map)
	buildGreenery(map)
	setupLighting()
end

return WorldBuilder
