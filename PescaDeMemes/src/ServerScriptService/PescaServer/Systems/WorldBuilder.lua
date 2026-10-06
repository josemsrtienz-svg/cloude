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

local function buildHub(map: Instance)
	local hub = folder(map, "Hub")
	local r = GameConfig.River
	local spawnZ = r.MaxZ + 30
	local spawnLoc = new("SpawnLocation", {
		Name = "Spawn", Size = Vector3.new(12, 1, 12), CFrame = CFrame.new(0, 0.5, spawnZ),
		Color = PALETTE.Brand, Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs,
		Anchored = true, Neutral = true, Duration = 0, Parent = hub,
	})
	local decal = spawnLoc:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- arco de entrada
	for _, x in ipairs({ -14, 14 }) do
		studded(hub, "ArchPillar", Vector3.new(3, 14, 3), CFrame.new(x, 7, r.MaxZ + 12), DIRT[1])
	end
	studded(hub, "ArchBeam", Vector3.new(32, 2, 3.4), CFrame.new(0, 15, r.MaxZ + 12), DIRT[2])
	sign(hub, "ArchSign", Vector3.new(24, 4.5, 0.6), CFrame.new(0, 11.5, r.MaxZ + 10.4) * CFrame.Angles(0, math.rad(180), 0),
		"🎣 PESCA DE MEMES", PALETTE.Brand, PALETTE.White)

	-- tienda con toldo a rayas (como la "tienda" de la referencia)
	local shop = folder(hub, "Shop")
	local o = CFrame.lookAt(Vector3.new(38, 0, spawnZ - 2), Vector3.new(0, 0, spawnZ - 2))
	local function at(x: number, yy: number, z: number): CFrame
		return o * CFrame.new(x, yy, z)
	end
	studded(shop, "Floor", Vector3.new(14, 0.6, 10), at(0, 0.3, 0), SAND[1])
	local counter = part(shop, "Counter", Vector3.new(12, 3.4, 2.4), at(0, 2.3, -2.5), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(shop, "CounterTop", Vector3.new(12.6, 0.4, 2.8), at(0, 4.1, -2.5), PALETTE.WoodDark, Enum.Material.Wood)
	for _, x in ipairs({ -6, 6 }) do
		for _, z in ipairs({ -3.5, 4 }) do
			part(shop, "Pole", Vector3.new(0.6, 9, 0.6), at(x, 4.8, z), RGB(230, 230, 235), Enum.Material.Metal)
		end
	end
	for k = 0, 6 do
		local color = if k % 2 == 0 then PALETTE.Brand else PALETTE.White
		part(shop, "Awning", Vector3.new(2, 0.3, 9.5), at(-6 + k * 2, 9.4, 0.2) * CFrame.Angles(math.rad(-8), 0, 0), color, Enum.Material.Fabric)
	end
	sign(shop, "ShopSign", Vector3.new(12, 2.4, 0.4), at(0, 7.4, -3.8), "🛒 TIENDA", RGB(60, 200, 80), PALETTE.White)
	for k, color in ipairs({ RGB(150, 105, 60), RGB(70, 170, 255), RGB(255, 205, 40), RGB(120, 60, 200) }) do
		local rod = part(shop, "DisplayRod", Vector3.new(6, 0.2, 0.2), at(-4.5 + (k - 1) * 3, 4.5, 3.5) * CFrame.Angles(0, 0, math.rad(80)),
			color, Enum.Material.SmoothPlastic)
		rod.Shape = Enum.PartType.Cylinder
	end
	new("ProximityPrompt", { Name = "ShopPrompt", ActionText = "Comprar", ObjectText = "Tienda",
		HoldDuration = 0, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = counter })
	post(shop, "Barrel", 2.2, 2.8, at(8.5, 0, -2).Position, PALETTE.Wood)
	part(shop, "Crate", Vector3.new(2, 2, 2), at(8.5, 1, 1.5) * CFrame.Angles(0, math.rad(15), 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
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
	setupLighting()
end

return WorldBuilder
