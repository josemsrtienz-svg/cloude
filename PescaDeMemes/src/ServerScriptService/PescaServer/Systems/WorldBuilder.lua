--[[
	PescaDeMemes • WorldBuilder (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > WorldBuilder

	Construye por script la zona 1 "Charca del Noob" para el prototipo.

	DIRECCIÓN DE ARTE
	  Estilo:        cartoon acogedor de lago, tarde soleada.
	  Formas:        madera algo torcida, postes de alturas distintas, tejados inclinados.
	  Materiales:    WoodPlanks / Wood para el muelle y casetas, Slate para tejas, Glass en el acuario.
	  Paleta:        maderas cálidas + agua turquesa + arena; acentos amarillo (marca) y rosa.
	  Foco:          el arco "CHARCA DEL NOOB" a la entrada del muelle, visto desde el spawn.
	  Secundarios:   tienda de cañas (derecha), acuario (izquierda), plataforma en T al final.
	  Entorno:       nenúfares, juncos, boyas, rocas y árboles alrededor de la charca.

	Jerarquía: Workspace > Map > { Terrain (agua/arena), Dock, Shop, Aquarium, Props, Nature }
	El agua es Terrain; su centro y radio deben coincidir con GameConfig.Pond.
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

-- ===== Terreno: hierba, arena, charca =====

local function buildTerrain()
	local terrain = Workspace.Terrain
	local c = GameConfig.Pond.Center
	terrain:Clear()
	terrain:FillBlock(CFrame.new(c.X, -8, c.Z + 40), Vector3.new(460, 16, 460), Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(c.X, -4, c.Z), 8, 94, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(c.X, -7, c.Z), 14, 80, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(c.X, -17, c.Z), 6, 84, Enum.Material.Sand)
	-- pequeñas calas para que la orilla no sea un círculo perfecto
	for _, cove in ipairs({ Vector3.new(-62, 0, -60), Vector3.new(58, 0, -150), Vector3.new(-40, 0, -168) }) do
		terrain:FillBall(c + cove + Vector3.new(0, -5, 0), 16, Enum.Material.Water)
	end
	terrain.WaterColor = RGB(40, 170, 190)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.4
end

-- ===== Muelle =====

local DOCK_START_Z = -6
local DOCK_END_Z = -62
local DOCK_HALF_W = 6
local DECK_Y = 1.2

local function buildDock(map: Instance)
	local dock = folder(map, "Dock")
	local planks = folder(dock, "Planks")
	local structure = folder(dock, "Structure")

	-- tablones del pasillo (cruzados), con color y giro levemente distintos
	local z = DOCK_START_Z
	local i = 0
	while z > DOCK_END_Z do
		i += 1
		local color = if i % 3 == 0 then PALETTE.WoodLight else PALETTE.Wood:Lerp(PALETTE.WoodDark, rng:NextNumber(0, 0.35))
		part(planks, "Plank", Vector3.new(DOCK_HALF_W * 2 + rng:NextNumber(-0.3, 0.4), 0.5, 1.8),
			CFrame.new(rng:NextNumber(-0.15, 0.15), DECK_Y, z - 0.9) * CFrame.Angles(0, math.rad(rng:NextNumber(-1.5, 1.5)), 0),
			color, Enum.Material.WoodPlanks)
		z -= 2
	end

	-- plataforma en T al final: tablones en el otro sentido para contraste
	local platformZ0, platformZ1 = DOCK_END_Z, DOCK_END_Z - 16
	for x = -14, 13, 2 do
		local color = PALETTE.Wood:Lerp(PALETTE.WoodDark, rng:NextNumber(0, 0.4))
		part(planks, "PlatformPlank", Vector3.new(1.8, 0.5, 16 + rng:NextNumber(-0.2, 0.2)),
			CFrame.new(x + 1, DECK_Y, (platformZ0 + platformZ1) / 2), color, Enum.Material.WoodPlanks)
	end

	-- vigas bajo los tablones
	for _, x in ipairs({ -DOCK_HALF_W + 1, DOCK_HALF_W - 1 }) do
		part(structure, "Stringer", Vector3.new(0.8, 0.8, DOCK_START_Z - DOCK_END_Z),
			CFrame.new(x, DECK_Y - 0.6, (DOCK_START_Z + DOCK_END_Z) / 2), PALETTE.WoodDark, Enum.Material.Wood)
	end
	part(structure, "PlatformBeam", Vector3.new(28, 0.8, 0.8), CFrame.new(0, DECK_Y - 0.6, platformZ0 - 1), PALETTE.WoodDark, Enum.Material.Wood)
	part(structure, "PlatformBeam", Vector3.new(28, 0.8, 0.8), CFrame.new(0, DECK_Y - 0.6, platformZ1 + 1), PALETTE.WoodDark, Enum.Material.Wood)

	-- postes que se hunden en el agua, de alturas distintas
	for pz = DOCK_START_Z - 4, DOCK_END_Z, -9 do
		for _, x in ipairs({ -DOCK_HALF_W - 0.3, DOCK_HALF_W + 0.3 }) do
			post(structure, "Post", 0.9, 8 + rng:NextNumber(0, 1.6), Vector3.new(x, -7, pz), PALETTE.WoodDark)
		end
	end
	for _, p in ipairs({ Vector3.new(-14, 0, platformZ0), Vector3.new(14, 0, platformZ0), Vector3.new(-14, 0, platformZ1),
		Vector3.new(14, 0, platformZ1), Vector3.new(0, 0, platformZ1) }) do
		post(structure, "Post", 1, 9.5 + rng:NextNumber(0, 1.2), Vector3.new(p.X, -7, p.Z), PALETTE.WoodDark)
	end

	-- barandilla baja al fondo de la plataforma, con hueco en el centro
	local rail = folder(dock, "Railing")
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			post(rail, "RailPost", 0.4, 2.6, Vector3.new(side * (5 + k * 4), DECK_Y + 0.25, platformZ1 + 0.6), PALETTE.WoodDark)
		end
		part(rail, "Rail", Vector3.new(9, 0.35, 0.35), CFrame.new(side * 9, DECK_Y + 2.5, platformZ1 + 0.6), PALETTE.Wood, Enum.Material.Wood)
		-- laterales de la plataforma
		post(rail, "RailPost", 0.4, 2.6, Vector3.new(side * 14, DECK_Y + 0.25, platformZ0 - 4), PALETTE.WoodDark)
		post(rail, "RailPost", 0.4, 2.6, Vector3.new(side * 14, DECK_Y + 0.25, platformZ1 + 4), PALETTE.WoodDark)
		part(rail, "Rail", Vector3.new(0.35, 0.35, 8.6), CFrame.new(side * 14, DECK_Y + 2.5, (platformZ0 + platformZ1) / 2), PALETTE.Wood, Enum.Material.Wood)
	end

	-- props de la plataforma: banco, barril con cebos, cajas y faroles
	local props = folder(dock, "Props")
	local benchCF = CFrame.new(-9.5, DECK_Y, platformZ0 - 3.5)
	part(props, "BenchSeat", Vector3.new(6, 0.4, 1.6), benchCF * CFrame.new(0, 1.6, 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(props, "BenchBack", Vector3.new(6, 1.4, 0.3), benchCF * CFrame.new(0, 2.6, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	for _, lx in ipairs({ -2.4, 2.4 }) do
		part(props, "BenchLeg", Vector3.new(0.4, 1.4, 1.4), benchCF * CFrame.new(lx, 0.9, 0), PALETTE.WoodDark, Enum.Material.Wood)
	end
	local barrel = post(props, "Barrel", 2.4, 3, Vector3.new(10, DECK_Y + 0.25, platformZ0 - 3), PALETTE.Wood, Enum.Material.Wood)
	barrel.Name = "BaitBarrel"
	for _, by in ipairs({ 0.5, 2.5 }) do
		post(props, "Hoop", 2.55, 0.25, Vector3.new(10, DECK_Y + 0.25 + by, platformZ0 - 3), RGB(70, 70, 75), Enum.Material.Metal)
	end
	part(props, "Crate", Vector3.new(2.2, 2.2, 2.2), CFrame.new(11.5, DECK_Y + 1.35, platformZ0 - 6) * CFrame.Angles(0, math.rad(18), 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(props, "Crate", Vector3.new(1.6, 1.6, 1.6), CFrame.new(11.3, DECK_Y + 3.25, platformZ0 - 5.8) * CFrame.Angles(0, math.rad(-12), 0), PALETTE.Wood, Enum.Material.WoodPlanks)
	lantern(props, Vector3.new(-13.4, DECK_Y + 0.25, platformZ1 + 1), 7)
	lantern(props, Vector3.new(13.4, DECK_Y + 0.25, platformZ1 + 1), 6.4)
	lantern(props, Vector3.new(DOCK_HALF_W + 0.2, DECK_Y + 0.25, -30), 6)

	-- arco de entrada: el foco visual desde el spawn
	local arch = folder(dock, "EntranceArch")
	post(arch, "ArchPost", 1.3, 13, Vector3.new(-7.5, 0, DOCK_START_Z + 1), PALETTE.WoodDark)
	post(arch, "ArchPost", 1.3, 12.4, Vector3.new(7.5, 0, DOCK_START_Z + 1), PALETTE.WoodDark)
	part(arch, "ArchBeam", Vector3.new(18, 1, 1.2), CFrame.new(0, 12.2, DOCK_START_Z + 1) * CFrame.Angles(0, 0, math.rad(-1.5)), PALETTE.Wood, Enum.Material.Wood)
	local board = sign(arch, "ArchSign", Vector3.new(15, 3.6, 0.5),
		CFrame.new(0, 9.6, DOCK_START_Z + 1.4) * CFrame.Angles(0, math.rad(180), math.rad(2.5)), "🎣 CHARCA DEL NOOB", PALETTE.Brand, PALETTE.White)
	board.Name = "ArchSign"
	for _, rx in ipairs({ -5.5, 5.5 }) do
		part(arch, "SignRope", Vector3.new(0.15, 1.6, 0.15), CFrame.new(rx, 11.5, DOCK_START_Z + 1.3), RGB(220, 200, 160), Enum.Material.Fabric)
	end
end

-- ===== Tienda de cañas =====

local function buildShop(map: Instance)
	local shop = folder(map, "Shop")
	-- frente local = -Z, mirando hacia el camino del spawn
	local o = CFrame.lookAt(Vector3.new(27, 0, 6), Vector3.new(0, 0, 26))
	local function at(x: number, y: number, z: number): CFrame
		return o * CFrame.new(x, y, z)
	end

	part(shop, "Foundation", Vector3.new(13, 0.8, 11), at(0, 0.4, 0), PALETTE.Rock, Enum.Material.Cobblestone)
	part(shop, "Floor", Vector3.new(12, 0.4, 10), at(0, 1, 0), PALETTE.Wood, Enum.Material.WoodPlanks)
	part(shop, "BackWall", Vector3.new(12, 9, 0.8), at(0, 5.6, 4.6), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(shop, "SideWall", Vector3.new(0.8, 9, 10), at(-5.6, 5.6, 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(shop, "SideWall", Vector3.new(0.8, 9, 10), at(5.6, 5.6, 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	part(shop, "CounterWall", Vector3.new(12, 3.2, 0.8), at(0, 2.8, -4.6), PALETTE.Wood, Enum.Material.WoodPlanks)
	local counter = part(shop, "Counter", Vector3.new(12.8, 0.4, 2.2), at(0, 4.6, -4.9), PALETTE.WoodDark, Enum.Material.Wood)
	for _, x in ipairs({ -5.6, 5.6 }) do
		part(shop, "FrontPillar", Vector3.new(1, 5.6, 1), at(x, 7.6, -4.6), PALETTE.WoodDark, Enum.Material.Wood)
	end
	part(shop, "Header", Vector3.new(12, 1.4, 0.8), at(0, 9.6, -4.6), PALETTE.Wood, Enum.Material.WoodPlanks)

	-- tejado inclinado con alero hacia delante
	part(shop, "Roof", Vector3.new(14.5, 0.7, 13.5), at(0, 11.2, -0.6) * CFrame.Angles(math.rad(-13), 0, 0), PALETTE.Roof, Enum.Material.Slate)
	part(shop, "RoofTrim", Vector3.new(14.6, 0.5, 0.5), at(0, 9.65, -7.2) * CFrame.Angles(math.rad(-13), 0, 0), PALETTE.WoodDark, Enum.Material.Wood)

	-- toldo de rayas amarillo/blanco sobre el mostrador
	for k = 0, 5 do
		local color = if k % 2 == 0 then PALETTE.Brand else PALETTE.White
		part(shop, "AwningStripe", Vector3.new(2, 0.2, 3.2), at(-5 + k * 2, 8.4, -6.6) * CFrame.Angles(math.rad(28), 0, 0), color, Enum.Material.Fabric)
	end

	-- cartel sobre el tejado
	for _, x in ipairs({ -3.5, 3.5 }) do
		part(shop, "SignPost", Vector3.new(0.4, 2.4, 0.4), at(x, 12.6, -3.5), PALETTE.WoodDark, Enum.Material.Wood)
	end
	sign(shop, "ShopSign", Vector3.new(10, 2.6, 0.4), at(0, 14.2, -3.6), "CAÑAS & CEBOS", PALETTE.Pink, PALETTE.White)

	-- interior visible: estantería con cañas de colores
	local rack = folder(shop, "RodRack")
	part(rack, "Shelf", Vector3.new(9, 0.4, 1.2), at(0, 3.2, 3.6), PALETTE.WoodDark, Enum.Material.Wood)
	for k, color in ipairs({ RGB(150, 105, 60), RGB(70, 170, 255), RGB(255, 205, 40), RGB(120, 60, 200) }) do
		local x = -3.6 + (k - 1) * 2.4
		local rod = part(rack, "DisplayRod", Vector3.new(6.5, 0.2, 0.2), at(x, 6.6, 3.9) * CFrame.Angles(0, 0, math.rad(84 - k * 2)), color, Enum.Material.SmoothPlastic)
		rod.Shape = Enum.PartType.Cylinder
	end

	-- campana en el mostrador + prompt de la tienda
	local bell = ball(shop, "Bell", 0.8, (at(3.8, 5.2, -5.2)).Position, PALETTE.Brand, Enum.Material.Metal)
	bell.Reflectance = 0.2
	new("ProximityPrompt", { Name = "ShopPrompt", ActionText = "Comprar", ObjectText = "Tienda de cañas",
		HoldDuration = 0, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = counter })

	-- exterior: barriles, cajas y cañas apoyadas en la pared
	post(shop, "Barrel", 2.2, 2.8, at(7.6, 0, -3).Position, PALETTE.Wood)
	part(shop, "Crate", Vector3.new(2, 2, 2), at(7.8, 1, 1) * CFrame.Angles(0, math.rad(15), 0), PALETTE.WoodLight, Enum.Material.WoodPlanks)
	for k = 0, 2 do
		local rod = part(shop, "LeaningRod", Vector3.new(7, 0.2, 0.2), at(-6.3, 3.4, -2 + k * 1.2) * CFrame.Angles(0, 0, math.rad(70 + k * 4)),
			PALETTE.WoodDark, Enum.Material.Wood)
		rod.Shape = Enum.PartType.Cylinder
	end
	lantern(shop, at(-7.2, 0, -5.5).Position, 7.5)
end

-- ===== Acuario del jugador =====

local function buildAquarium(map: Instance)
	local aq = folder(map, "Aquarium")
	local o = CFrame.lookAt(Vector3.new(-27, 0, 6), Vector3.new(0, 0, 26))
	local function at(x: number, y: number, z: number): CFrame
		return o * CFrame.new(x, y, z)
	end

	part(aq, "Plinth", Vector3.new(16, 0.8, 8), at(0, 0.4, 0), PALETTE.Rock, Enum.Material.Cobblestone)
	local cabinet = part(aq, "Cabinet", Vector3.new(14.5, 3, 6), at(0, 2.3, 0), PALETTE.WoodDark, Enum.Material.WoodPlanks)
	part(aq, "CabinetTop", Vector3.new(15, 0.4, 6.4), at(0, 4, 0), PALETTE.Wood, Enum.Material.Wood)
	part(aq, "TankSand", Vector3.new(13.6, 0.6, 5.2), at(0, 4.5, 0), RGB(235, 215, 160), Enum.Material.Sand)
	local water = part(aq, "AquariumWater", Vector3.new(13.4, 6.2, 5), at(0, 7.9, 0), RGB(60, 180, 230), Enum.Material.SmoothPlastic,
		{ Transparency = 0.75, CanCollide = false })
	water.CastShadow = false
	part(aq, "TankGlass", Vector3.new(14, 7.4, 5.6), at(0, 7.9, 0), PALETTE.Glass, Enum.Material.Glass,
		{ Transparency = 0.7, CanCollide = true })
	-- marco de madera
	for _, x in ipairs({ -7, 7 }) do
		for _, z in ipairs({ -2.8, 2.8 }) do
			part(aq, "FrameCorner", Vector3.new(0.5, 7.6, 0.5), at(x, 7.9, z), PALETTE.WoodDark, Enum.Material.Wood)
		end
	end
	part(aq, "FrameTop", Vector3.new(14.6, 0.5, 6.2), at(0, 11.8, 0), PALETTE.WoodDark, Enum.Material.Wood, { Transparency = 0 })
	-- algas y un pequeño castillo dentro
	for k = 1, 5 do
		local x = rng:NextNumber(-6, 6)
		local h = rng:NextNumber(1.5, 3.5)
		part(aq, "Seaweed", Vector3.new(0.25, h, 0.25), at(x, 4.8 + h / 2, rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12))),
			PALETTE.Leaf[(k % 3) + 1], Enum.Material.Grass, { CanCollide = false })
	end
	part(aq, "MiniCastle", Vector3.new(1.4, 1.8, 1.4), at(4.8, 5.7, 1), RGB(200, 170, 140), Enum.Material.Sandstone, { CanCollide = false })
	part(aq, "MiniCastleTop", Vector3.new(1.7, 0.4, 1.7), at(4.8, 6.8, 1), RGB(180, 150, 120), Enum.Material.Sandstone, { CanCollide = false })

	for _, x in ipairs({ -4.5, 4.5 }) do
		part(aq, "SignPost", Vector3.new(0.4, 2.6, 0.4), at(x, 13.2, 0), PALETTE.WoodDark, Enum.Material.Wood)
	end
	sign(aq, "AquariumSign", Vector3.new(12, 2.6, 0.4), at(0, 14.8, -0.1), "🐠 TU ACUARIO", RGB(40, 150, 200), PALETTE.White)

	new("ProximityPrompt", { Name = "AquariumPrompt", ActionText = "Ver acuario", ObjectText = "Tu acuario",
		HoldDuration = 0, MaxActivationDistance = 12, RequiresLineOfSight = false, Parent = cabinet })
end

-- ===== Naturaleza: árboles, juncos, nenúfares, rocas, boyas =====

local function tree(parent: Instance, base: Vector3)
	local m = folder(parent, "Tree")
	local h = rng:NextNumber(9, 15)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-6, 6)))
	local trunk = part(m, "Trunk", Vector3.new(h, 1.6, 1.6), CFrame.new(base) * lean * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		PALETTE.WoodDark, Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	local top = (CFrame.new(base) * lean * CFrame.new(0, h, 0)).Position
	for k = 1, 3 do
		local d = rng:NextNumber(6, 9)
		local offset = Vector3.new(rng:NextNumber(-2.2, 2.2), rng:NextNumber(-0.8, 2.2), rng:NextNumber(-2.2, 2.2))
		ball(m, "Leaves", d, top + offset, PALETTE.Leaf[rng:NextInteger(1, 3)], Enum.Material.Grass)
	end
end

local function reeds(parent: Instance, base: Vector3)
	local m = folder(parent, "Reeds")
	for _ = 1, rng:NextInteger(4, 7) do
		local h = rng:NextNumber(3, 5.5)
		local p = base + Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10)))
		part(m, "Stem", Vector3.new(0.18, h, 0.18), CFrame.new(p) * tilt * CFrame.new(0, h / 2 - 1, 0), RGB(110, 150, 70), Enum.Material.Grass, { CanCollide = false })
		if rng:NextNumber() < 0.6 then
			part(m, "Cattail", Vector3.new(0.4, 1, 0.4), CFrame.new(p) * tilt * CFrame.new(0, h - 0.8, 0), RGB(120, 75, 45), Enum.Material.Fabric, { CanCollide = false })
		end
	end
end

local function lilyPad(parent: Instance, center: Vector3)
	local pad = disc(parent, "LilyPad", rng:NextNumber(2.4, 4), 0.15, center + Vector3.new(0, 0.05, 0), RGB(80, 160, 70), Enum.Material.Grass)
	pad.CanCollide = false
	if rng:NextNumber() < 0.35 then
		ball(parent, "LilyFlower", 0.7, center + Vector3.new(0.4, 0.35, 0.2), PALETTE.Pink, Enum.Material.SmoothPlastic).CanCollide = false
	end
end

local function buoy(parent: Instance, center: Vector3)
	local m = folder(parent, "Buoy")
	ball(m, "Bottom", 1.6, center, RGB(230, 60, 60), Enum.Material.SmoothPlastic)
	ball(m, "Top", 1, center + Vector3.new(0, 0.75, 0), PALETTE.White, Enum.Material.SmoothPlastic)
end

local function rocks(parent: Instance, base: Vector3)
	local m = folder(parent, "Rocks")
	for _ = 1, rng:NextInteger(2, 3) do
		local s = rng:NextNumber(1.5, 3.5)
		part(m, "Rock", Vector3.new(s * rng:NextNumber(1, 1.5), s * 0.7, s), CFrame.new(base + Vector3.new(rng:NextNumber(-1.5, 1.5), s * 0.2, rng:NextNumber(-1.5, 1.5)))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), PALETTE.Rock, Enum.Material.Rock)
	end
end

local function buildNature(map: Instance)
	local nature = folder(map, "Nature")
	local c = GameConfig.Pond.Center
	-- árboles en un anillo irregular, dejando libre el camino del spawn (z > -10 cerca de x = 0)
	for k = 1, 22 do
		local angle = (k / 22) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local radius = rng:NextNumber(108, 150)
		local p = c + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not (math.abs(p.X) < 40 and p.Z > -20) then
			tree(nature, p)
		end
	end
	-- juncos y rocas en la orilla
	for k = 1, 14 do
		local angle = (k / 14) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local p = c + Vector3.new(math.cos(angle) * rng:NextNumber(79, 85), 0, math.sin(angle) * rng:NextNumber(79, 85))
		if math.abs(p.X) > 10 or p.Z < c.Z then
			if k % 3 == 0 then
				rocks(nature, p)
			else
				reeds(nature, p)
			end
		end
	end
	-- nenúfares en grupos
	for _, group in ipairs({ Vector3.new(-40, 0, 30), Vector3.new(38, 0, 20), Vector3.new(-20, 0, -45), Vector3.new(45, 0, -35) }) do
		for _ = 1, rng:NextInteger(3, 5) do
			lilyPad(nature, c + group + Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7)))
		end
	end
	for _, p in ipairs({ Vector3.new(-22, 0, -48), Vector3.new(22, 0, -52), Vector3.new(-30, 0, -80), Vector3.new(32, 0, -85), Vector3.new(0, 0, -98) }) do
		buoy(nature, p + Vector3.new(0, 0.3, 0))
	end
end

-- ===== Spawn y camino =====

local function buildSpawn(map: Instance)
	local spawnArea = folder(map, "Spawn")
	local spawnLoc = new("SpawnLocation", {
		Name = "Spawn", Size = Vector3.new(1, 10, 10), Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(0, 0.5, 30) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PALETTE.Brand, Material = Enum.Material.SmoothPlastic, Anchored = true, Neutral = true,
		Duration = 0, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, Parent = spawnArea,
	})
	local decal = spawnLoc:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	-- camino de piedras irregulares hasta el muelle
	for z = 23, -3, -3.2 do
		local s = rng:NextNumber(2.6, 3.6)
		part(spawnArea, "Stepstone", Vector3.new(s * 1.3, 0.4, s), CFrame.new(rng:NextNumber(-1.2, 1.2), 0.1, z)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), RGB(170, 165, 155), Enum.Material.Slate)
	end
end

local function setupLighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = RGB(110, 100, 95)
	Lighting.OutdoorAmbient = RGB(150, 140, 130)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or new("Atmosphere", { Parent = Lighting })
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	atmosphere.Color = RGB(200, 225, 240)
	atmosphere.Decay = RGB(120, 160, 200)
	if not Lighting:FindFirstChild("PescaColor") then
		new("ColorCorrectionEffect", { Name = "PescaColor", Saturation = 0.15, Contrast = 0.05, TintColor = RGB(255, 248, 240), Parent = Lighting })
		new("BloomEffect", { Name = "PescaBloom", Intensity = 0.4, Size = 24, Threshold = 1.6, Parent = Lighting })
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
	buildTerrain()
	buildSpawn(map)
	buildDock(map)
	buildShop(map)
	buildAquarium(map)
	buildNature(map)
	setupLighting()
end

return WorldBuilder
