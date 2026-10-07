--[[
	PescaDeMemes • GearModels (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > GearModels

	Modelos de bloques del equipo, compartidos por servidor y cliente:
	  · GearModels.Rod(rod, broken?)        → caña (la usa GearService para la herramienta y la tienda para su foto)
	  · GearModels.Tank(aquarium, memeIds?) → mochila-acuario con MINI MEMES dentro (espalda y tienda)
	  · GearModels.Spool()                  → carrete de Sedal Reforzado (icono de la tienda)
	Todas las piezas salen Anchored y sin colisión, con el origen en el centro de la pieza principal
	(PrimaryPart). Para pegarlas a un personaje: desanclar y soldar (ver GearService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local MemeModels = require(Root.Shared.MemeModels)

local GearModels = {}

local RGB = Color3.fromRGB
GearModels.RodLength = 6.5
GearModels.RodTilt = math.rad(35) -- la caña sale hacia delante (-Z) y hacia arriba

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

-- ===== Cañas: cada una con su diseño y sus efectos =====
-- Construcción común: mango (con su material), carrete con manivela, vara en dos tramos, anillas y punta.
-- Encima, cada caña añade su identidad (DECOR) y sus partículas (FX):
--   Palo   rama natural con nudos, cordel atado y una hoja · sin efectos (es la humilde)
--   Fibra  carbono azul brillante con franjas blancas y mango de corcho · destellos azules suaves
--   Turbo  franjas de peligro amarillo/negro y aletas-rayo junto al mango · chispas eléctricas en la punta
--   Abisal vara negra-morada con runas que brillan y una esfera abisal en la punta · niebla morada y luz

local ROD_STYLE = {
	Palo = { Shaft = RGB(130, 90, 55), ShaftMat = Enum.Material.Wood, Grip = RGB(95, 65, 40), GripMat = Enum.Material.Wood, Tip = RGB(90, 160, 60) },
	Fibra = { Shaft = RGB(40, 110, 220), ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(205, 165, 115), GripMat = Enum.Material.Fabric, Tip = RGB(255, 255, 255) },
	Turbo = { Shaft = RGB(255, 205, 40), ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(30, 30, 35), GripMat = Enum.Material.Fabric, Tip = RGB(255, 240, 120) },
	Abisal = { Shaft = RGB(40, 20, 60), ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(25, 15, 35), GripMat = Enum.Material.Fabric, Tip = RGB(140, 255, 235) },
	Bambu = { Shaft = RGB(140, 200, 90), ShaftMat = Enum.Material.Wood, Grip = RGB(120, 165, 70), GripMat = Enum.Material.Wood, Tip = RGB(110, 195, 70) },
	Pirata = { Shaft = RGB(85, 55, 35), ShaftMat = Enum.Material.Wood, Grip = RGB(70, 45, 28), GripMat = Enum.Material.Wood, Tip = RGB(255, 200, 60) },
	Coral = { Shaft = RGB(255, 130, 120), ShaftMat = Enum.Material.Slate, Grip = RGB(245, 230, 210), GripMat = Enum.Material.Marble, Tip = RGB(255, 200, 220) },
	Glaciar = { Shaft = RGB(170, 225, 255), ShaftMat = Enum.Material.Ice, Grip = RGB(60, 90, 130), GripMat = Enum.Material.Fabric, Tip = RGB(235, 250, 255) },
	Volcanica = { Shaft = RGB(45, 35, 33), ShaftMat = Enum.Material.Basalt, Grip = RGB(60, 40, 35), GripMat = Enum.Material.Slate, Tip = RGB(255, 120, 30) },
	CyberNeon = { Shaft = RGB(30, 30, 42), ShaftMat = Enum.Material.Metal, Grip = RGB(15, 15, 20), GripMat = Enum.Material.Fabric, Tip = RGB(60, 240, 255) },
	Dragon = { Shaft = RGB(170, 25, 35), ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(60, 20, 20), GripMat = Enum.Material.Fabric, Tip = RGB(255, 200, 60) },
	Galactica = { Shaft = RGB(30, 22, 85), ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(20, 15, 40), GripMat = Enum.Material.Fabric, Tip = RGB(240, 240, 255) },
	Arcoiris = { Shaft = RGB(255, 255, 255), ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(250, 250, 255), GripMat = Enum.Material.Fabric, Tip = RGB(255, 255, 255) },
	Diamante = { Shaft = RGB(200, 240, 255), ShaftMat = Enum.Material.Glass, Grip = RGB(225, 228, 238), GripMat = Enum.Material.Metal, Tip = RGB(220, 250, 255) },
	Brainrot = { Shaft = RGB(255, 110, 180), ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(80, 200, 255), GripMat = Enum.Material.Fabric, Tip = RGB(255, 140, 185) },
	Divina = { Shaft = RGB(250, 248, 240), ShaftMat = Enum.Material.Marble, Grip = RGB(235, 190, 70), GripMat = Enum.Material.Metal, Tip = RGB(255, 245, 200) },
}

-- Ayudas para decorar a lo largo de la vara (f = 0 junto al mango, 1 en la punta).
local function along(axis: CFrame, length: number, f: number, x: number?, y: number?): CFrame
	return axis * CFrame.new(x or 0, y or 0, -0.5 - f * length)
end

-- Termina una pieza creada a mano (WedgePart…) igual que part(): anclada, sin colisión ni sombra.
local function bakePart(p: BasePart, model: Model)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
end

local function ballPart(model: Model, name: string, d: number, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	return part(model, { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * d, Color = color,
		Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0, CFrame = cf })
end

-- Cilindro (el eje del cilindro de Roblox es X: gira cf para orientarlo).
local function cylinderPart(model: Model, name: string, thickness: number, d: number, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	return part(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, d, d), Color = color,
		Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0, CFrame = cf })
end

local function light(parent: Instance, color: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.4
	l.Parent = parent
end

local function rodFx(parent: Instance, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
end

local DECOR: { [string]: (Model, CFrame, number) -> () } = {
	-- rama: nudos repartidos a lo largo, cordel atado en dos puntos y una hoja cerca de la punta
	Palo = function(model, axis, length)
		for i = 1, 4 do
			part(model, { Name = "Knot", Size = Vector3.new(0.22, 0.22, 0.22), Color = RGB(100, 70, 40), Material = Enum.Material.Wood,
				CFrame = axis * CFrame.new((i % 2 - 0.5) * 0.12, 0.05, -0.5 - i * length / 5) })
		end
		for _, f in ipairs({ 0.15, 0.6 }) do
			part(model, { Name = "Twine", Size = Vector3.new(0.2, 0.2, 0.14), Color = RGB(225, 210, 170), Material = Enum.Material.Fabric,
				CFrame = axis * CFrame.new(0, 0, -0.5 - f * length) })
		end
		part(model, { Name = "Leaf", Size = Vector3.new(0.5, 0.06, 0.3), Color = RGB(90, 170, 60), Material = Enum.Material.Grass,
			CFrame = axis * CFrame.new(0.25, 0.08, -0.5 - length * 0.85) * CFrame.Angles(0, 0, 0.4) })
	end,
	-- carbono: franjas blancas regulares y un reflejo
	Fibra = function(model, axis, length)
		for i = 1, 5 do
			part(model, { Name = "Stripe", Size = Vector3.new(0.19, 0.19, 0.12), Color = RGB(245, 245, 250),
				CFrame = axis * CFrame.new(0, 0, -0.5 - i * length / 6) })
		end
		part(model, { Name = "Gloss", Size = Vector3.new(0.05, 0.05, length * 0.6), Color = RGB(200, 230, 255), Material = Enum.Material.Neon,
			CFrame = axis * CFrame.new(0.06, 0.07, -0.5 - length * 0.4) })
	end,
	-- turbo: franjas de peligro y dos aletas en forma de rayo
	Turbo = function(model, axis, length)
		for i = 1, 6 do
			part(model, { Name = "Hazard", Size = Vector3.new(0.19, 0.19, 0.15), Color = RGB(25, 25, 30),
				CFrame = axis * CFrame.new(0, 0, -0.5 - i * length / 7) * CFrame.Angles(0, 0, math.rad(45)) })
		end
		for _, side in ipairs({ -1, 1 }) do
			local fin = Instance.new("WedgePart")
			fin.Name = "BoltFin"
			fin.Size = Vector3.new(0.06, 0.5, 0.7)
			fin.Color = RGB(255, 240, 120)
			fin.Material = Enum.Material.Neon
			fin.Anchored = true
			fin.CanCollide = false
			fin.CanQuery = false
			fin.CanTouch = false
			fin.Massless = true
			fin.CFrame = axis * CFrame.new(side * 0.14, 0.2, -1.0) * CFrame.Angles(0, 0, side * 0.3)
			fin.Parent = model
		end
	end,
	-- abisal: runas de neón y una esfera que brilla en la punta
	Abisal = function(model, axis, length)
		for i = 1, 4 do
			part(model, { Name = "Rune", Size = Vector3.new(0.2, 0.2, 0.1), Color = RGB(140, 255, 235), Material = Enum.Material.Neon,
				CFrame = axis * CFrame.new(0, 0, -0.5 - i * length / 5) })
		end
		local orb = part(model, { Name = "AbyssOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = RGB(170, 90, 255),
			Material = Enum.Material.Neon, CFrame = axis * CFrame.new(0, 0, -length - 0.65) })
		part(model, { Name = "OrbCage", Size = Vector3.new(0.55, 0.08, 0.55), Color = RGB(60, 40, 80), Material = Enum.Material.Metal,
			CFrame = axis * CFrame.new(0, 0, -length - 0.65) })
		light(orb, RGB(160, 100, 255), 8)
	end,
	-- ===== v0.9: 12 cañas nuevas =====
	-- bambú: nudos (anillos más oscuros) en cada tramo, cordel en el mango y dos hojas en la punta
	Bambu = function(model, axis, length)
		for i = 1, 6 do
			local shade = RGB(90 + i * 3, 145 + (i % 2) * 10, 55)
			part(model, { Name = "Node", Size = Vector3.new(0.22, 0.22, 0.07), Color = shade, Material = Enum.Material.Wood,
				CFrame = along(axis, length, i / 7) })
		end
		for _, z in ipairs({ -0.45, -0.05, 0.35 }) do
			part(model, { Name = "Twine", Size = Vector3.new(0.39, 0.39, 0.07), Color = RGB(215, 195, 145), Material = Enum.Material.Fabric,
				CFrame = CFrame.new(0, 0, z) })
		end
		part(model, { Name = "Twig", Size = Vector3.new(0.05, 0.05, 0.35), Color = RGB(100, 150, 60), Material = Enum.Material.Wood,
			CFrame = along(axis, length, 0.9, 0.12, 0.1) * CFrame.Angles(0, 0.5, 0) })
		for _, side in ipairs({ -1, 1 }) do
			part(model, { Name = "Leaf", Size = Vector3.new(0.34, 0.04, 0.6), Color = RGB(110, 195, 70), Material = Enum.Material.Grass,
				CFrame = along(axis, length, 0.92, side * 0.2, 0.12) * CFrame.Angles(0, side * 0.6, side * 0.4) })
		end
	end,
	-- pirata: madera oscura con aros de latón, cuerda en el mango, doblón en el talón y bandera con calavera
	Pirata = function(model, axis, length)
		for _, f in ipairs({ 0.22, 0.48, 0.74 }) do
			part(model, { Name = "BrassBand", Size = Vector3.new(0.21, 0.21, 0.1), Color = RGB(205, 160, 60), Material = Enum.Material.Metal,
				CFrame = along(axis, length, f) })
		end
		for i = 0, 4 do
			part(model, { Name = "Rope", Size = Vector3.new(0.4, 0.4, 0.06), Color = RGB(180 - i * 4, 145, 95), Material = Enum.Material.Fabric,
				CFrame = CFrame.new(0, 0, -0.5 + i * 0.22) * CFrame.Angles(0, 0, i * 0.4) })
		end
		cylinderPart(model, "Doubloon", 0.06, 0.38, CFrame.new(0, 0, 0.9) * CFrame.Angles(0, math.rad(90), 0), RGB(255, 200, 60), Enum.Material.Metal)
		local pole = along(axis, length, 0.86, 0, 0.3)
		part(model, { Name = "FlagPole", Size = Vector3.new(0.05, 0.6, 0.05), Color = RGB(70, 45, 25), Material = Enum.Material.Wood, CFrame = pole })
		local flag = pole * CFrame.new(0, 0.15, 0.27)
		part(model, { Name = "Flag", Size = Vector3.new(0.03, 0.32, 0.5), Color = RGB(20, 20, 25), Material = Enum.Material.Fabric, CFrame = flag })
		part(model, { Name = "Skull", Size = Vector3.new(0.05, 0.12, 0.12), Color = RGB(240, 240, 230), CFrame = flag * CFrame.new(0, 0.04, 0) })
		for _, a in ipairs({ -0.7, 0.7 }) do
			part(model, { Name = "Bone", Size = Vector3.new(0.05, 0.03, 0.22), Color = RGB(240, 240, 230),
				CFrame = flag * CFrame.new(0, -0.07, 0) * CFrame.Angles(a, 0, 0) })
		end
	end,
	-- coral: ramas de coral que salen de la vara (de varios tonos, con puntas redondas), concha y perla
	Coral = function(model, axis, length)
		local tones = { RGB(255, 120, 120), RGB(255, 160, 90), RGB(240, 90, 150), RGB(255, 140, 170) }
		for i = 1, 4 do
			local side = if i % 2 == 0 then 1 else -1
			local base = along(axis, length, 0.18 + i * 0.17) * CFrame.Angles(0, 0, side * 0.9)
			local color = tones[i]
			part(model, { Name = "Branch", Size = Vector3.new(0.08, 0.38, 0.08), Color = color, Material = Enum.Material.Slate,
				CFrame = base * CFrame.new(0, 0.22, 0) })
			part(model, { Name = "Twig", Size = Vector3.new(0.06, 0.22, 0.06), Color = color, Material = Enum.Material.Slate,
				CFrame = base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0.6, 0, 0) * CFrame.new(0, 0.1, 0) })
			ballPart(model, "Polyp", 0.12, base * CFrame.new(0, 0.42, 0), color:Lerp(Color3.new(1, 1, 1), 0.3))
		end
		for _, side in ipairs({ -1, 1 }) do
			local shell = Instance.new("WedgePart")
			shell.Name = "Shell"
			shell.Size = Vector3.new(0.05, 0.26, 0.3)
			shell.Color = RGB(250, 225, 200)
			shell.Material = Enum.Material.Marble
			shell.CFrame = CFrame.new(side * 0.21, 0.05, 0.2) * CFrame.Angles(0, 0, side * 0.2)
			bakePart(shell, model)
		end
		ballPart(model, "Pearl", 0.32, axis * CFrame.new(0, 0, -length - 0.7), RGB(250, 245, 255), Enum.Material.Glass).Reflectance = 0.3
	end,
	-- glaciar: vara de hielo translúcida con un núcleo que brilla, pinchos de hielo y un copo de nieve en la punta
	Glaciar = function(model, axis, length)
		part(model, { Name = "FrostCore", Size = Vector3.new(0.06, 0.06, length * 0.95), Color = RGB(210, 245, 255), Material = Enum.Material.Neon,
			CFrame = axis * CFrame.new(0, 0, -length / 2 - 0.5) })
		for i = 1, 6 do
			local side = if i % 2 == 0 then 1 else -1
			local spike = Instance.new("WedgePart")
			spike.Name = "IceSpike"
			spike.Size = Vector3.new(0.08, 0.2 + (i % 3) * 0.06, 0.32)
			spike.Color = RGB(190, 235, 255)
			spike.Material = Enum.Material.Glass
			spike.Transparency = 0.3
			spike.CFrame = along(axis, length, i / 7.5, side * 0.1, 0.12) * CFrame.Angles(0, 0, side * 0.5)
			bakePart(spike, model)
		end
		local flake = axis * CFrame.new(0, 0, -length - 0.8)
		for k = 0, 2 do
			part(model, { Name = "Snowflake", Size = Vector3.new(0.05, 0.6, 0.05), Color = RGB(235, 250, 255), Material = Enum.Material.Neon,
				CFrame = flake * CFrame.Angles(0, 0, k * math.rad(60)) })
		end
	end,
	-- volcánica: basalto con grietas de lava zigzagueando, rocas pegadas y un orbe de magma con luz
	Volcanica = function(model, axis, length)
		for i = 1, 7 do
			local x = if i % 2 == 0 then 0.06 else -0.06
			part(model, { Name = "LavaCrack", Size = Vector3.new(0.035, 0.035, length / 7.5), Color = RGB(255, 110 + i * 8, 20),
				Material = Enum.Material.Neon, CFrame = along(axis, length, (i - 0.5) / 7, x, 0.075) * CFrame.Angles(0, x * 4, 0) })
		end
		for i, f in ipairs({ 0.2, 0.47, 0.71 }) do
			part(model, { Name = "Rock", Size = Vector3.new(0.24, 0.2, 0.26), Color = RGB(55 + i * 6, 45, 42), Material = Enum.Material.Basalt,
				CFrame = along(axis, length, f, (i % 2 - 0.5) * 0.12, -0.04) * CFrame.Angles(i, i * 0.7, 0.3) })
		end
		local orb = ballPart(model, "MagmaOrb", 0.42, axis * CFrame.new(0, 0, -length - 0.7), RGB(255, 100, 20), Enum.Material.Neon)
		part(model, { Name = "OrbCrust", Size = Vector3.new(0.5, 0.12, 0.5), Color = RGB(40, 30, 28), Material = Enum.Material.Basalt,
			CFrame = axis * CFrame.new(0, -0.12, -length - 0.7) * CFrame.Angles(0, 0.4, 0) })
		light(orb, RGB(255, 120, 40), 8)
	end,
	-- cyber neón: metal oscuro con pistas de circuito cian/magenta, anillos holográficos y pantalla LED
	CyberNeon = function(model, axis, length)
		part(model, { Name = "TraceTop", Size = Vector3.new(0.03, 0.03, length * 0.9), Color = RGB(60, 240, 255), Material = Enum.Material.Neon,
			CFrame = axis * CFrame.new(0, 0.085, -length / 2 - 0.5) })
		part(model, { Name = "TraceSide", Size = Vector3.new(0.03, 0.03, length * 0.7), Color = RGB(255, 60, 220), Material = Enum.Material.Neon,
			CFrame = axis * CFrame.new(0.085, 0, -length * 0.4 - 0.5) })
		for i = 1, 5 do
			part(model, { Name = "Chip", Size = Vector3.new(0.1, 0.06, 0.1), Color = if i % 2 == 0 then RGB(60, 240, 255) else RGB(255, 60, 220),
				Material = Enum.Material.Neon, CFrame = along(axis, length, i / 6, 0, 0.1) })
		end
		for _, f in ipairs({ 0.42, 0.72 }) do
			cylinderPart(model, "HoloRing", 0.04, 0.55, along(axis, length, f) * CFrame.Angles(0, math.rad(90), 0), RGB(80, 230, 255),
				Enum.Material.Neon, 0.55)
		end
		part(model, { Name = "Screen", Size = Vector3.new(0.3, 0.22, 0.4), Color = RGB(15, 15, 20), Material = Enum.Material.Metal,
			CFrame = CFrame.new(0, 0.28, -0.1) })
		part(model, { Name = "ScreenGlow", Size = Vector3.new(0.24, 0.02, 0.32), Color = RGB(60, 240, 255), Material = Enum.Material.Neon,
			CFrame = CFrame.new(0, 0.4, -0.1) })
		local tip = part(model, { Name = "Scanner", Size = Vector3.new(0.28, 0.12, 0.12), Color = RGB(60, 240, 255), Material = Enum.Material.Neon,
			CFrame = axis * CFrame.new(0, 0, -length - 0.7) })
		light(tip, RGB(80, 240, 255), 10)
	end,
	-- dragón: escamas por el lomo, alas junto al mango y una cabeza de dragón con cuernos y ojos en la punta
	Dragon = function(model, axis, length)
		for i = 1, 9 do
			local scale = Instance.new("WedgePart")
			scale.Name = "Scale"
			scale.Size = Vector3.new(0.14, 0.1, 0.22)
			scale.Color = RGB(120 + (i % 3) * 15, 15, 25)
			scale.Material = Enum.Material.SmoothPlastic
			scale.CFrame = along(axis, length, i / 10.5, 0, 0.11)
			bakePart(scale, model)
		end
		for _, side in ipairs({ -1, 1 }) do
			local wing = CFrame.new(side * 0.35, 0.25, -0.3) * CFrame.Angles(0, side * 0.3, side * 0.5)
			part(model, { Name = "WingBone", Size = Vector3.new(0.6, 0.05, 0.05), Color = RGB(90, 20, 25), CFrame = wing })
			local membrane = Instance.new("WedgePart")
			membrane.Name = "WingMembrane"
			membrane.Size = Vector3.new(0.03, 0.4, 0.55)
			membrane.Color = RGB(230, 120, 40)
			membrane.Material = Enum.Material.Fabric
			membrane.CFrame = wing * CFrame.new(0, -0.2, 0.2) * CFrame.Angles(0, math.rad(90), 0)
			bakePart(membrane, model)
		end
		local head = axis * CFrame.new(0, 0, -length - 0.75)
		part(model, { Name = "DragonHead", Size = Vector3.new(0.4, 0.36, 0.5), Color = RGB(170, 25, 35), CFrame = head })
		part(model, { Name = "Snout", Size = Vector3.new(0.3, 0.2, 0.32), Color = RGB(150, 20, 30), CFrame = head * CFrame.new(0, -0.04, -0.38) })
		part(model, { Name = "Jaw", Size = Vector3.new(0.26, 0.07, 0.36), Color = RGB(90, 15, 20), CFrame = head * CFrame.new(0, -0.17, -0.34) })
		for _, side in ipairs({ -1, 1 }) do
			part(model, { Name = "Eye", Size = Vector3.new(0.07, 0.07, 0.07), Color = RGB(255, 230, 60), Material = Enum.Material.Neon,
				CFrame = head * CFrame.new(side * 0.17, 0.08, -0.18) })
			local horn = Instance.new("WedgePart")
			horn.Name = "Horn"
			horn.Size = Vector3.new(0.07, 0.3, 0.16)
			horn.Color = RGB(240, 200, 90)
			horn.Material = Enum.Material.Metal
			horn.CFrame = head * CFrame.new(side * 0.13, 0.3, 0.12) * CFrame.Angles(-0.5, 0, side * 0.2)
			bakePart(horn, model)
		end
	end,
	-- galáctica: vara azul noche con estrellas, un planeta con anillo en la punta y una luna pequeña
	Galactica = function(model, axis, length)
		for i = 1, 11 do
			local x = math.sin(i * 2.3) * 0.085
			local y = math.cos(i * 1.7) * 0.085
			part(model, { Name = "Star", Size = Vector3.one * (0.035 + (i % 3) * 0.012), Color = if i % 4 == 0 then RGB(255, 220, 140) else RGB(240, 240, 255),
				Material = Enum.Material.Neon, CFrame = along(axis, length, i / 12, x, y) })
		end
		local planetCf = axis * CFrame.new(0, 0, -length - 0.8)
		local planet = ballPart(model, "Planet", 0.5, planetCf, RGB(150, 90, 230), Enum.Material.SmoothPlastic)
		ballPart(model, "PlanetBand", 0.52, planetCf * CFrame.new(0, 0.05, 0), RGB(255, 170, 90), Enum.Material.SmoothPlastic, 0.55)
		cylinderPart(model, "PlanetRing", 0.03, 0.95, planetCf * CFrame.Angles(0.4, 0, math.rad(90)), RGB(230, 200, 255),
			Enum.Material.Neon, 0.35)
		ballPart(model, "Moon", 0.14, planetCf * CFrame.new(0.45, 0.3, 0.1), RGB(220, 220, 230), Enum.Material.Slate)
		light(planet, RGB(170, 120, 255), 9)
	end,
	-- arcoíris: la vara está hecha de franjas de colores, con una nube en la punta y una moneda en el talón
	Arcoiris = function(model, axis, length)
		local colors = { RGB(255, 70, 70), RGB(255, 150, 40), RGB(255, 230, 60), RGB(80, 220, 100), RGB(70, 160, 255), RGB(170, 90, 255) }
		for i, c in ipairs(colors) do
			part(model, { Name = "Band", Size = Vector3.new(0.17, 0.17, length / 6), Color = c,
				CFrame = along(axis, length, (i - 0.5) / 6) })
		end
		local cloud = axis * CFrame.new(0, 0.05, -length - 0.75)
		for k, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(0.22, -0.05, 0.08), Vector3.new(-0.22, -0.05, 0.05), Vector3.new(0, 0.12, 0.15) }) do
			ballPart(model, "Cloud", 0.34 - (k % 2) * 0.06, cloud * CFrame.new(off), RGB(255, 255, 255), Enum.Material.SmoothPlastic)
		end
		cylinderPart(model, "GoldCoin", 0.06, 0.34, CFrame.new(0, 0, 0.9) * CFrame.Angles(0, math.rad(90), 0), RGB(255, 205, 60), Enum.Material.Metal)
	end,
	-- diamante: vara de cristal con engastes de platino, gemas talladas y un gran diamante en la punta
	Diamante = function(model, axis, length)
		for i = 1, 5 do
			local f = i / 6
			part(model, { Name = "Setting", Size = Vector3.new(0.22, 0.22, 0.08), Color = RGB(225, 228, 238), Material = Enum.Material.Metal,
				CFrame = along(axis, length, f) })
			local gem = part(model, { Name = "Gem", Size = Vector3.one * (0.13 + (i % 2) * 0.04), Color = RGB(150, 230, 255),
				Material = Enum.Material.Glass, Transparency = 0.15, CFrame = along(axis, length, f, 0, 0.14) * CFrame.Angles(math.rad(45), math.rad(45), 0) })
			gem.Reflectance = 0.35
		end
		local top = axis * CFrame.new(0, 0, -length - 0.8)
		local diamond = part(model, { Name = "Diamond", Size = Vector3.new(0.36, 0.36, 0.36), Color = RGB(200, 245, 255), Material = Enum.Material.Glass,
			Transparency = 0.1, CFrame = top * CFrame.Angles(math.rad(45), 0, math.rad(45)) })
		diamond.Reflectance = 0.45
		part(model, { Name = "Prongs", Size = Vector3.new(0.3, 0.3, 0.1), Color = RGB(225, 228, 238), Material = Enum.Material.Metal,
			CFrame = top * CFrame.new(0, 0, 0.24) })
		light(diamond, RGB(200, 240, 255), 7)
	end,
	-- brainrot: vara a cuadros de colores meme, zapatilla en el mango y un CEREBRO con ojos saltones y corona
	Brainrot = function(model, axis, length)
		for i = 1, 8 do
			part(model, { Name = "Check", Size = Vector3.new(0.175, 0.175, length / 9), Color = if i % 2 == 0 then RGB(80, 220, 255) else RGB(255, 225, 60),
				CFrame = along(axis, length, (i - 0.5) / 8.5) * CFrame.Angles(0, 0, i * 0.4) })
		end
		part(model, { Name = "SneakerSole", Size = Vector3.new(0.42, 0.12, 0.7), Color = RGB(245, 245, 245), CFrame = CFrame.new(0, -0.25, 0.25) })
		part(model, { Name = "SneakerSwoosh", Size = Vector3.new(0.44, 0.05, 0.3), Color = RGB(255, 60, 120), CFrame = CFrame.new(0, -0.17, 0.2) })
		local brain = axis * CFrame.new(0, 0.05, -length - 0.85)
		ballPart(model, "Brain", 0.7, brain, RGB(255, 140, 185), Enum.Material.SmoothPlastic)
		for k = -1, 1 do
			part(model, { Name = "Fold", Size = Vector3.new(0.05, 0.05, 0.6), Color = RGB(220, 95, 145),
				CFrame = brain * CFrame.new(k * 0.15, 0.3 - math.abs(k) * 0.05, 0) * CFrame.Angles(0, 0, k * 0.3) })
		end
		part(model, { Name = "Fissure", Size = Vector3.new(0.04, 0.08, 0.66), Color = RGB(200, 80, 130), CFrame = brain * CFrame.new(0, 0.3, 0) })
		for _, side in ipairs({ -1, 1 }) do
			local eye = brain * CFrame.new(side * 0.15, 0.02, -0.3)
			ballPart(model, "EyeWhite", 0.2, eye, RGB(255, 255, 255), Enum.Material.SmoothPlastic)
			ballPart(model, "Pupil", 0.09, eye * CFrame.new(side * 0.02, -0.03, -0.07), RGB(20, 20, 25), Enum.Material.SmoothPlastic)
		end
		for k = -1, 1 do
			local spike = Instance.new("WedgePart")
			spike.Name = "Crown"
			spike.Size = Vector3.new(0.06, 0.18, 0.12)
			spike.Color = RGB(255, 205, 60)
			spike.Material = Enum.Material.Metal
			spike.CFrame = brain * CFrame.new(k * 0.12, 0.45, 0.05)
			bakePart(spike, model)
		end
	end,
	-- divina: mármol blanco con filigrana de oro, alas de ángel de plumas en el mango y un halo en la punta
	Divina = function(model, axis, length)
		for _, f in ipairs({ 0.2, 0.5, 0.8 }) do
			part(model, { Name = "GoldBand", Size = Vector3.new(0.21, 0.21, 0.09), Color = RGB(240, 195, 70), Material = Enum.Material.Metal,
				CFrame = along(axis, length, f) })
			part(model, { Name = "BandGem", Size = Vector3.one * 0.07, Color = RGB(120, 220, 255), Material = Enum.Material.Neon,
				CFrame = along(axis, length, f, 0, 0.11) })
		end
		for _, side in ipairs({ -1, 1 }) do
			for k = 1, 3 do
				part(model, { Name = "Feather", Size = Vector3.new(0.75 - k * 0.15, 0.05, 0.16), Color = RGB(255, 255, 255 - k * 8),
					CFrame = CFrame.new(side * (0.3 + (3 - k) * 0.06), 0.15 + k * 0.08, -0.2 + k * 0.1) * CFrame.Angles(0, side * 0.25, side * (0.35 + k * 0.12)) })
			end
		end
		local haloCf = axis * CFrame.new(0, 0, -length - 0.85)
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			part(model, { Name = "Halo", Size = Vector3.new(0.1, 0.1, 0.2), Color = RGB(255, 230, 120), Material = Enum.Material.Neon,
				CFrame = haloCf * CFrame.new(math.cos(a) * 0.32, math.sin(a) * 0.32, 0) * CFrame.Angles(0, 0, a) })
		end
		local core = ballPart(model, "HolyLight", 0.22, haloCf, RGB(255, 250, 220), Enum.Material.Neon)
		light(core, RGB(255, 235, 170), 10)
	end,
}

local FX: { [string]: (Attachment) -> () } = {
	Fibra = function(att)
		rodFx(att, { Name = "Glint", Rate = 2, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.5, 1),
			Size = NumberSequence.new(0.15), Color = ColorSequence.new(RGB(150, 210, 255)), SpreadAngle = Vector2.new(180, 180) })
	end,
	Turbo = function(att)
		rodFx(att, { Name = "Sparks", Rate = 10, Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(3, 6),
			Size = NumberSequence.new(0.12), Color = ColorSequence.new(RGB(255, 235, 90)), SpreadAngle = Vector2.new(180, 180) })
	end,
	Abisal = function(att)
		rodFx(att, { Name = "AbyssMist", Rate = 8, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.3, 1),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.8) }),
			Color = ColorSequence.new(RGB(170, 90, 255), RGB(110, 255, 230)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			SpreadAngle = Vector2.new(180, 180) })
	end,
	Bambu = function(att)
		rodFx(att, { Name = "Leaves", Rate = 0.6, Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(0.3, 0.8), LightEmission = 0,
			Size = NumberSequence.new(0.12), Color = ColorSequence.new(RGB(120, 200, 80)), Acceleration = Vector3.new(0, -1, 0),
			SpreadAngle = Vector2.new(180, 180) })
	end,
	Pirata = function(att)
		rodFx(att, { Name = "GoldGlint", Rate = 2, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.3, 0.8),
			Size = NumberSequence.new(0.14), Color = ColorSequence.new(RGB(255, 210, 70)), SpreadAngle = Vector2.new(180, 180) })
	end,
	Coral = function(att)
		rodFx(att, { Name = "Bubbles", Rate = 3, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.6, 1.2), LightEmission = 0.3,
			Size = NumberSequence.new(0.12), Color = ColorSequence.new(RGB(200, 240, 255)), Transparency = NumberSequence.new(0.4),
			Acceleration = Vector3.new(0, 1.5, 0), SpreadAngle = Vector2.new(40, 40) })
	end,
	Glaciar = function(att)
		rodFx(att, { Name = "Snow", Rate = 4, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.3, 0.7),
			Size = NumberSequence.new(0.1), Color = ColorSequence.new(RGB(235, 250, 255)), Acceleration = Vector3.new(0, -0.8, 0),
			SpreadAngle = Vector2.new(180, 180) })
	end,
	Volcanica = function(att)
		rodFx(att, { Name = "Embers", Rate = 9, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 2.5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(RGB(255, 200, 60), RGB(255, 60, 20)), Acceleration = Vector3.new(0, 3, 0), SpreadAngle = Vector2.new(30, 30) })
	end,
	CyberNeon = function(att)
		rodFx(att, { Name = "Pixels", Rate = 6, Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(1, 2),
			Size = NumberSequence.new(0.12), Color = ColorSequence.new(RGB(60, 240, 255), RGB(255, 60, 220)), SpreadAngle = Vector2.new(180, 180) })
	end,
	Dragon = function(att)
		rodFx(att, { Name = "DragonFire", Rate = 12, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(2, 4),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.05) }),
			Color = ColorSequence.new(RGB(255, 230, 80), RGB(255, 50, 20)), Acceleration = Vector3.new(0, 2, 0), SpreadAngle = Vector2.new(20, 20) })
	end,
	Galactica = function(att)
		rodFx(att, { Name = "Nebula", Rate = 6, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.2, 0.6),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.5) }),
			Color = ColorSequence.new(RGB(120, 90, 255), RGB(255, 120, 220)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			SpreadAngle = Vector2.new(180, 180) })
	end,
	Arcoiris = function(att)
		rodFx(att, { Name = "Rainbow", Rate = 10, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0.5, 1.2),
			Size = NumberSequence.new(0.15), SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, RGB(255, 70, 70)), ColorSequenceKeypoint.new(0.33, RGB(255, 230, 60)),
				ColorSequenceKeypoint.new(0.66, RGB(80, 220, 100)), ColorSequenceKeypoint.new(1, RGB(170, 90, 255)) }) })
	end,
	Diamante = function(att)
		rodFx(att, { Name = "Sparkle", Rate = 7, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(0.5, 1.5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(RGB(220, 250, 255)), SpreadAngle = Vector2.new(180, 180) })
	end,
	Brainrot = function(att)
		rodFx(att, { Name = "BrainWaves", Rate = 6, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0.8, 1.5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.35) }),
			Color = ColorSequence.new(RGB(255, 110, 180), RGB(80, 220, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			RotSpeed = NumberRange.new(-180, 180), SpreadAngle = Vector2.new(180, 180) })
	end,
	Divina = function(att)
		rodFx(att, { Name = "HolyRays", Rate = 8, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0.3, 0.8),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(RGB(255, 245, 200), RGB(255, 210, 90)), Acceleration = Vector3.new(0, 1, 0),
			SpreadAngle = Vector2.new(180, 180) })
	end,
}

-- Caña completa. broken = rota (más corta, apagada y sin efectos).
function GearModels.Rod(rod: any, broken: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "Rod"
	local style = ROD_STYLE[rod.Id] or { Shaft = rod.Color, ShaftMat = Enum.Material.SmoothPlastic, Grip = RGB(40, 32, 30),
		GripMat = Enum.Material.Fabric, Tip = RGB(255, 75, 75) }
	local length = GearModels.RodLength * (if broken then 0.5 else 1)
	local color = if broken then RGB(90, 70, 60) else style.Shaft
	local handle = part(model, { Name = "Handle", Size = Vector3.new(0.35, 0.35, 1.4), Color = style.Grip,
		Material = style.GripMat, CFrame = CFrame.new() })
	model.PrimaryPart = handle
	part(model, { Name = "Butt", Size = Vector3.new(0.42, 0.42, 0.25), Color = RGB(25, 20, 18), CFrame = CFrame.new(0, 0, 0.75) })
	part(model, { Name = "Wrap", Size = Vector3.new(0.38, 0.38, 0.12), Color = color, CFrame = CFrame.new(0, 0, -0.3) })
	local axis = CFrame.Angles(GearModels.RodTilt, 0, 0)
	local shaft = part(model, { Name = "Shaft", Size = Vector3.new(0.16, 0.16, length), Color = color, Material = style.ShaftMat,
		Reflectance = if rod.Id == "Fibra" and not broken then 0.15 else 0, CFrame = axis * CFrame.new(0, 0, -length / 2 - 0.5) })
	part(model, { Name = "Upper", Size = Vector3.new(0.18, 0.18, length * 0.12), Color = color:Lerp(Color3.new(1, 1, 1), 0.35),
		CFrame = axis * CFrame.new(0, 0, -length * 0.45 - 0.5) })
	part(model, { Name = "Reel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.6, 0.6), Color = RGB(200, 200, 210),
		Material = Enum.Material.Metal, CFrame = CFrame.new(0, -0.35, -0.3) })
	part(model, { Name = "Spool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 0.4, 0.4), Color = style.Shaft,
		CFrame = CFrame.new(0, -0.35, -0.3) })
	part(model, { Name = "Crank", Size = Vector3.new(0.08, 0.35, 0.08), Color = RGB(60, 60, 70), Material = Enum.Material.Metal,
		CFrame = CFrame.new(0.2, -0.45, -0.3) })
	part(model, { Name = "CrankKnob", Size = Vector3.new(0.14, 0.14, 0.14), Color = RGB(30, 30, 35), CFrame = CFrame.new(0.2, -0.62, -0.3) })
	for i = 1, 3 do
		part(model, { Name = "Guide", Size = Vector3.new(0.22, 0.22, 0.1), Color = RGB(220, 220, 220), Material = Enum.Material.Metal,
			CFrame = axis * CFrame.new(0, 0.12, -0.5 - i * length / 4) })
	end
	if not broken then
		part(model, { Name = "TipCap", Size = Vector3.new(0.2, 0.2, 0.3), Color = style.Tip, Material = Enum.Material.Neon,
			CFrame = axis * CFrame.new(0, 0, -length - 0.5) })
		local decor = DECOR[rod.Id]
		if decor then
			decor(model, axis, length)
		end
	end
	local tip = Instance.new("Attachment")
	tip.Name = "RodTip"
	tip.Position = Vector3.new(0, 0, -length / 2)
	tip.Parent = shaft
	local fx = not broken and FX[rod.Id]
	if fx then
		fx(tip)
	end
	return model
end

-- ===== Mochilas-acuario: 12 diseños =====
-- Todas comparten el "interior" (agua, arena y hasta 3 MINI MEMES de verdad, mirando hacia fuera) y
-- cambian la CARCASA, que es lo que las hace reconocibles a la espalda:
--   Jar tarro con corcho · Bowl pecera redonda en mochila de tela · Tank acuario de cristal · Barrel barril
--   con ventana · Globe esfera con anillo · Sub submarino con ojos de buey · Chest cofre con tapa de cristal
--   Rocket cohete con aletas y llama · Neon burbuja que brilla · Royal marco de oro con corona
--   Cosmic cristal oscuro con estrellas y anillo · BlackHole esfera negra con disco morado que gira.
-- El origen es el centro del agua; la espalda del jugador queda hacia -Z (las correas van por -Z).

local function ball(model: Model, name: string, d: number, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	return part(model, { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * d, Color = color,
		Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0, CFrame = cf })
end

local function cylinder(model: Model, name: string, length: number, d: number, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	return part(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, d, d), Color = color,
		Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0, CFrame = cf })
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- los cilindros de Roblox van en X: así quedan de pie

local function straps(model: Model, color: Color3, height: number)
	for _, x in ipairs({ -0.55, 0.55 }) do
		part(model, { Name = "Strap", Size = Vector3.new(0.25, 0.15, 1.6), Color = color, Material = Enum.Material.Fabric,
			CFrame = CFrame.new(x, height, -0.8) })
		part(model, { Name = "StrapDown", Size = Vector3.new(0.25, height * 1.6, 0.15), Color = color, Material = Enum.Material.Fabric,
			CFrame = CFrame.new(x, 0, -0.62) })
	end
end

local SHELLS: { [string]: (Model, any) -> () } = {
	Jar = function(m, aq)
		cylinder(m, "Glass", 2.2, 1.8, UP, RGB(210, 245, 255), Enum.Material.Glass, 0.6)
		cylinder(m, "Cork", 0.5, 1.2, CFrame.new(0, 1.3, 0) * UP, RGB(170, 125, 80), Enum.Material.Wood)
		part(m, { Name = "Twine", Size = Vector3.new(1.85, 0.12, 1.85), Color = RGB(230, 215, 170), Material = Enum.Material.Fabric, CFrame = CFrame.new(0, 0.95, 0) })
		part(m, { Name = "Label", Size = Vector3.new(0.9, 0.6, 0.05), Color = aq.Color, CFrame = CFrame.new(0, 0.2, 0.92) })
		straps(m, RGB(120, 90, 60), 0.9)
	end,
	Bowl = function(m, aq)
		part(m, { Name = "Pack", Size = Vector3.new(2.2, 2.4, 0.7), Color = aq.Color, Material = Enum.Material.Fabric, CFrame = CFrame.new(0, -0.1, -0.55) })
		part(m, { Name = "Pocket", Size = Vector3.new(1.4, 0.7, 0.2), Color = aq.Color:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Fabric, CFrame = CFrame.new(0, -0.9, -0.95) })
		ball(m, "Glass", 2.0, CFrame.new(0, 0.1, 0.35), RGB(210, 245, 255), Enum.Material.Glass, 0.55)
		cylinder(m, "Rim", 0.2, 1.1, CFrame.new(0, 1.05, 0.35) * UP, RGB(240, 250, 255), Enum.Material.Glass, 0.3)
		straps(m, aq.Color:Lerp(Color3.new(0, 0, 0), 0.3), 1)
	end,
	Tank = function(m, aq)
		part(m, { Name = "Glass", Size = Vector3.new(1.9, 2.2, 1.1), Color = RGB(200, 240, 255), Material = Enum.Material.Glass, Transparency = 0.6, CFrame = CFrame.new() })
		part(m, { Name = "Lid", Size = Vector3.new(2.05, 0.25, 1.25), Color = aq.Color, CFrame = CFrame.new(0, 1.2, 0) })
		part(m, { Name = "Bottom", Size = Vector3.new(2.05, 0.25, 1.25), Color = aq.Color, CFrame = CFrame.new(0, -1.2, 0) })
		for _, x in ipairs({ -0.97, 0.97 }) do
			part(m, { Name = "Frame", Size = Vector3.new(0.12, 2.2, 1.2), Color = aq.Color, CFrame = CFrame.new(x, 0, 0) })
		end
		straps(m, RGB(60, 45, 35), 1.1)
	end,
	Barrel = function(m, aq)
		for k = 0, 7 do
			local a = k * math.pi / 4
			part(m, { Name = "Stave", Size = Vector3.new(0.8, 2.5, 0.2), Color = RGB(150, 100, 60):Lerp(RGB(120, 80, 45), (k % 2) * 0.5),
				Material = Enum.Material.WoodPlanks, CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.95) })
		end
		for _, y in ipairs({ -0.8, 0.8 }) do
			cylinder(m, "Hoop", 0.18, 2.1, CFrame.new(0, y, 0) * UP, RGB(80, 80, 90), Enum.Material.Metal)
		end
		part(m, { Name = "Window", Size = Vector3.new(1.1, 1.2, 0.1), Color = RGB(200, 240, 255), Material = Enum.Material.Glass, Transparency = 0.4, CFrame = CFrame.new(0, 0, 1.02) })
		cylinder(m, "Top", 0.2, 1.9, CFrame.new(0, 1.25, 0) * UP, aq.Color)
		straps(m, RGB(60, 45, 35), 1.1)
	end,
	Globe = function(m, aq)
		ball(m, "Glass", 2.4, CFrame.new(), RGB(200, 240, 255), Enum.Material.Glass, 0.55)
		cylinder(m, "Ring", 0.25, 2.8, CFrame.Angles(0, math.rad(90), 0), aq.Color, Enum.Material.SmoothPlastic)
		cylinder(m, "Base", 0.35, 1.4, CFrame.new(0, -1.25, 0) * UP, aq.Color)
		ball(m, "Wave", 0.5, CFrame.new(0.7, 0.6, 0.7), RGB(120, 230, 255), Enum.Material.Neon, 0.3)
		straps(m, RGB(60, 45, 35), 1.1)
	end,
	Sub = function(m, aq)
		part(m, { Name = "Hull", Size = Vector3.new(2.2, 2.0, 1.4), Color = aq.Color, CFrame = CFrame.new() })
		ball(m, "Nose", 2.0, CFrame.new(0, 1.0, 0), aq.Color)
		ball(m, "Tail", 1.6, CFrame.new(0, -1.1, 0), aq.Color)
		for _, y in ipairs({ 0.45, -0.45 }) do
			cylinder(m, "Porthole", 0.12, 0.8, CFrame.new(0, y, 0.72) * CFrame.Angles(0, math.rad(90), 0), RGB(200, 240, 255), Enum.Material.Glass, 0.3)
			cylinder(m, "PortRim", 0.1, 0.95, CFrame.new(0, y, 0.7) * CFrame.Angles(0, math.rad(90), 0), RGB(90, 90, 100), Enum.Material.Metal)
		end
		cylinder(m, "Periscope", 1.2, 0.25, CFrame.new(0.6, 2.2, 0) * UP, RGB(90, 90, 100), Enum.Material.Metal)
		part(m, { Name = "PeriscopeTop", Size = Vector3.new(0.3, 0.3, 0.5), Color = RGB(90, 90, 100), Material = Enum.Material.Metal, CFrame = CFrame.new(0.6, 2.8, 0.15) })
		for _, x in ipairs({ -1, 1 }) do
			part(m, { Name = "Fin", Size = Vector3.new(0.6, 0.15, 0.8), Color = aq.Color:Lerp(Color3.new(0, 0, 0), 0.2), CFrame = CFrame.new(x * 1.3, -1.2, 0) })
		end
		straps(m, RGB(60, 45, 35), 1.1)
	end,
	Chest = function(m, aq)
		part(m, { Name = "Base", Size = Vector3.new(2.4, 1.6, 1.4), Color = aq.Color, Material = Enum.Material.WoodPlanks, CFrame = CFrame.new(0, -0.5, 0) })
		part(m, { Name = "Glass", Size = Vector3.new(2.2, 1.1, 1.2), Color = RGB(200, 240, 255), Material = Enum.Material.Glass, Transparency = 0.55, CFrame = CFrame.new(0, 0.85, 0) })
		part(m, { Name = "LidFrame", Size = Vector3.new(2.5, 0.25, 1.5), Color = RGB(255, 200, 50), Reflectance = 0.2, CFrame = CFrame.new(0, 1.45, 0) })
		for _, x in ipairs({ -1.1, 1.1 }) do
			part(m, { Name = "GoldBand", Size = Vector3.new(0.2, 1.65, 1.45), Color = RGB(255, 200, 50), Reflectance = 0.2, CFrame = CFrame.new(x, -0.5, 0) })
		end
		part(m, { Name = "Lock", Size = Vector3.new(0.4, 0.5, 0.12), Color = RGB(255, 200, 50), CFrame = CFrame.new(0, -0.1, 0.72) })
		straps(m, RGB(60, 45, 35), 1.2)
	end,
	Rocket = function(m, aq)
		cylinder(m, "Body", 2.6, 1.6, UP, RGB(240, 240, 245))
		part(m, { Name = "Stripe", Size = Vector3.new(1.65, 0.35, 1.65), Color = aq.Color, CFrame = CFrame.new(0, 0.6, 0) })
		ball(m, "Nose", 1.6, CFrame.new(0, 1.45, 0), aq.Color)
		cylinder(m, "Window", 0.12, 0.9, CFrame.new(0, 0.1, 0.8) * CFrame.Angles(0, math.rad(90), 0), RGB(200, 240, 255), Enum.Material.Glass, 0.3)
		for k = 0, 2 do
			part(m, { Name = "Fin", Size = Vector3.new(0.15, 0.9, 0.8), Color = aq.Color, CFrame = CFrame.Angles(0, k * math.pi * 2 / 3, 0) * CFrame.new(0, -1.1, 0.9) })
		end
		local nozzle = cylinder(m, "Nozzle", 0.4, 0.9, CFrame.new(0, -1.45, 0) * UP, RGB(70, 70, 80), Enum.Material.Metal)
		local flame = Instance.new("ParticleEmitter")
		flame.Name = "Flame"
		flame.Rate = 25
		flame.Lifetime = NumberRange.new(0.2, 0.35)
		flame.Speed = NumberRange.new(3, 5)
		flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		flame.Color = ColorSequence.new(RGB(255, 220, 80), RGB(255, 90, 30))
		flame.LightEmission = 1
		flame.EmissionDirection = Enum.NormalId.Left -- el cilindro está girado: "Left" apunta hacia abajo
		flame.Parent = nozzle
		straps(m, RGB(60, 45, 35), 1.0)
	end,
	Neon = function(m, aq)
		ball(m, "Glass", 2.3, CFrame.new(), RGB(255, 200, 250), Enum.Material.Glass, 0.5)
		for _, rot in ipairs({ CFrame.Angles(0, 0, 0), CFrame.Angles(0, math.rad(90), 0), CFrame.Angles(math.rad(90), 0, 0) }) do
			cylinder(m, "NeonRing", 0.12, 2.45, rot * CFrame.Angles(0, math.rad(90), 0), aq.Color, Enum.Material.Neon, 0.1)
		end
		local glow = Instance.new("PointLight")
		glow.Color = aq.Color
		glow.Range = 8
		glow.Brightness = 1.5
		glow.Parent = m:FindFirstChild("Glass")
		straps(m, RGB(40, 30, 50), 1.1)
	end,
	Royal = function(m, aq)
		part(m, { Name = "Glass", Size = Vector3.new(2.0, 2.3, 1.2), Color = RGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.55, CFrame = CFrame.new() })
		for _, y in ipairs({ -1.25, 1.25 }) do
			part(m, { Name = "GoldFrame", Size = Vector3.new(2.3, 0.3, 1.45), Color = aq.Color, Reflectance = 0.25, CFrame = CFrame.new(0, y, 0) })
		end
		for _, x in ipairs({ -1.05, 1.05 }) do
			part(m, { Name = "GoldPillar", Size = Vector3.new(0.25, 2.3, 0.25), Color = aq.Color, Reflectance = 0.25, CFrame = CFrame.new(x, 0, 0.6) })
		end
		for i = 0, 3 do
			part(m, { Name = "CrownSpike", Size = Vector3.new(0.3, 0.5, 0.3), Color = aq.Color, Reflectance = 0.25, CFrame = CFrame.new(-0.75 + i * 0.5, 1.65, 0) })
		end
		ball(m, "Jewel", 0.35, CFrame.new(0, 1.25, 0.75), RGB(230, 40, 70), Enum.Material.Neon)
		straps(m, RGB(160, 20, 40), 1.2)
	end,
	Cosmic = function(m, aq)
		ball(m, "Glass", 2.4, CFrame.new(), aq.Color, Enum.Material.Glass, 0.35)
		cylinder(m, "PlanetRing", 0.1, 3.4, CFrame.Angles(math.rad(20), 0, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(200, 170, 255), Enum.Material.Neon, 0.4)
		local stars = Instance.new("ParticleEmitter")
		stars.Name = "Stars"
		stars.Rate = 6
		stars.Lifetime = NumberRange.new(1, 2)
		stars.Speed = NumberRange.new(0.2, 0.6)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Size = NumberSequence.new(0.12)
		stars.Color = ColorSequence.new(RGB(255, 255, 255), RGB(180, 200, 255))
		stars.LightEmission = 1
		stars.Parent = m:FindFirstChild("Glass")
		straps(m, RGB(30, 20, 60), 1.1)
	end,
	BlackHole = function(m, aq)
		ball(m, "Core", 1.4, CFrame.new(0, 0, -0.2), RGB(5, 5, 10), Enum.Material.SmoothPlastic)
		ball(m, "Glass", 2.5, CFrame.new(), RGB(60, 30, 90), Enum.Material.Glass, 0.6)
		cylinder(m, "Disc", 0.08, 3.6, CFrame.Angles(math.rad(70), 0, 0) * CFrame.Angles(0, 0, math.rad(90)), aq.Color, Enum.Material.Neon, 0.25)
		cylinder(m, "DiscInner", 0.1, 2.6, CFrame.Angles(math.rad(70), 0, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(255, 170, 80), Enum.Material.Neon, 0.35)
		local swirl = Instance.new("ParticleEmitter")
		swirl.Name = "Swirl"
		swirl.Rate = 10
		swirl.Lifetime = NumberRange.new(0.8, 1.2)
		swirl.Speed = NumberRange.new(-1.5, -1)
		swirl.SpreadAngle = Vector2.new(180, 180)
		swirl.Size = NumberSequence.new(0.2)
		swirl.Color = ColorSequence.new(aq.Color, RGB(255, 170, 80))
		swirl.LightEmission = 1
		swirl.Parent = m:FindFirstChild("Glass")
		straps(m, RGB(30, 20, 40), 1.1)
	end,
}

-- Mochila-acuario con su diseño y hasta 3 MINI MEMES de verdad dentro (en la espalda y en la tienda).
-- Escala de la mochila a la espalda según el tier (las grandes se ven un poco más grandes).
function GearModels.TankScale(aquarium: any): number
	return 1 + math.clamp((aquarium.Tier - 1) * 0.035, 0, 0.4)
end

-- Mitad del fondo (eje Z) de la mochila ya escalada: para pegarla a la espalda sin medir efectos.
function GearModels.TankHalfDepth(aquarium: any): number
	return 0.6 * GearModels.TankScale(aquarium)
end

function GearModels.Tank(aquarium: any, memeIds: { string }?): Model
	local model = Instance.new("Model")
	model.Name = "Tank"
	-- interior común: agua y arena
	local water = part(model, { Name = "Water", Size = Vector3.new(1.6, 1.4, 0.9), Color = RGB(60, 170, 230), Transparency = 0.55,
		CFrame = CFrame.new(0, -0.25, 0) })
	model.PrimaryPart = water
	part(model, { Name = "Sand", Size = Vector3.new(1.6, 0.2, 0.9), Color = RGB(235, 215, 160), Material = Enum.Material.Sand,
		CFrame = CFrame.new(0, -0.9, 0) })
	part(model, { Name = "Weed", Size = Vector3.new(0.12, 0.6, 0.12), Color = RGB(70, 190, 90), CFrame = CFrame.new(0.6, -0.5, 0.2) })
	local shell = SHELLS[aquarium.Style or "Tank"] or SHELLS.Tank
	shell(model, aquarium)
	-- mini memes de pie sobre la arena, mirando hacia fuera (la espalda del jugador)
	for i, memeId in ipairs(memeIds or {}) do
		if i > 3 then
			break
		end
		if MemeModels.Has(memeId) then
			local mini = MemeModels.Build(memeId, 0.12, false, false)
			mini:PivotTo(CFrame.new(-0.5 + (i - 1) * 0.5, -0.8, 0.05) * CFrame.Angles(0, math.pi, 0))
			for _, d in ipairs(mini:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Massless = true
					d.CastShadow = false
				end
			end
			mini.Parent = model
		end
	end
	-- las mochilas grandes se ven un poco más grandes a la espalda
	local scale = GearModels.TankScale(aquarium)
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

-- Carrete de hilo reforzado (icono del objeto).
function GearModels.Spool(): Model
	local model = Instance.new("Model")
	model.Name = "Spool"
	local core = part(model, { Name = "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.1, 1.1),
		Color = RGB(255, 90, 150), Material = Enum.Material.Fabric, CFrame = CFrame.Angles(0, math.rad(90), 0) })
	model.PrimaryPart = core
	for _, z in ipairs({ -0.7, 0.7 }) do
		part(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.7, 1.7), Color = RGB(150, 104, 66),
			Material = Enum.Material.Wood, CFrame = CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0) })
	end
	part(model, { Name = "Thread", Size = Vector3.new(0.08, 0.08, 1.4), Color = RGB(255, 255, 255),
		CFrame = CFrame.new(0.4, -0.6, 0.6) * CFrame.Angles(math.rad(70), 0, 0) })
	return model
end

-- Linterna: cuerpo con agarre, cabezal ancho y cristal que brilla.
function GearModels.Flashlight(): Model
	local model = Instance.new("Model")
	model.Name = "Flashlight"
	local body = part(model, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 0.8, 0.8), Color = RGB(60, 60, 70),
		Material = Enum.Material.Metal, CFrame = CFrame.new() })
	model.PrimaryPart = body
	for k = -1, 1 do
		part(model, { Name = "Grip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 0.86, 0.86), Color = RGB(30, 30, 35),
			CFrame = CFrame.new(k * 0.45 + 0.2, 0, 0) })
	end
	part(model, { Name = "Head", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 1.3, 1.3), Color = RGB(255, 200, 50),
		CFrame = CFrame.new(-1.45, 0, 0) })
	part(model, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.05, 1.05), Color = RGB(255, 245, 190),
		Material = Enum.Material.Neon, CFrame = CFrame.new(-1.82, 0, 0) })
	part(model, { Name = "Button", Size = Vector3.new(0.3, 0.2, 0.3), Color = RGB(230, 60, 60), CFrame = CFrame.new(0.1, 0.45, 0) })
	return model
end

-- Imán en U: rojo con puntas plateadas.
function GearModels.Magnet(): Model
	local model = Instance.new("Model")
	model.Name = "Magnet"
	local bend = part(model, { Name = "Bend", Size = Vector3.new(2.4, 0.7, 0.8), Color = RGB(220, 50, 50), CFrame = CFrame.new(0, 1.2, 0) })
	model.PrimaryPart = bend
	for _, x in ipairs({ -0.85, 0.85 }) do
		part(model, { Name = "Arm", Size = Vector3.new(0.7, 1.8, 0.8), Color = RGB(220, 50, 50), CFrame = CFrame.new(x, 0.1, 0) })
		part(model, { Name = "Tip", Size = Vector3.new(0.72, 0.5, 0.82), Color = RGB(215, 220, 230), Material = Enum.Material.Metal, CFrame = CFrame.new(x, -1.0, 0) })
	end
	return model
end

-- Red dorada: aro con mango y malla en cuadrícula.
function GearModels.Net(): Model
	local model = Instance.new("Model")
	model.Name = "Net"
	local ring = part(model, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.4, 2.4), Color = RGB(255, 200, 50),
		Reflectance = 0.2, CFrame = CFrame.Angles(0, math.rad(90), 0) })
	model.PrimaryPart = ring
	part(model, { Name = "Inner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 2.1, 2.1), Color = RGB(255, 245, 210),
		Transparency = 0.6, CFrame = CFrame.Angles(0, math.rad(90), 0) })
	for k = -2, 2 do
		part(model, { Name = "MeshV", Size = Vector3.new(0.05, 2.0, 0.05), Color = RGB(255, 225, 120), CFrame = CFrame.new(k * 0.4, 0, 0) })
		part(model, { Name = "MeshH", Size = Vector3.new(2.0, 0.05, 0.05), Color = RGB(255, 225, 120), CFrame = CFrame.new(0, k * 0.4, 0) })
	end
	part(model, { Name = "Handle", Size = Vector3.new(0.25, 2.2, 0.25), Color = RGB(150, 100, 60), Material = Enum.Material.Wood,
		CFrame = CFrame.new(0, -2.2, 0) })
	return model
end

-- Casita de bloques (icono de la parcela).
function GearModels.House(): Model
	local model = Instance.new("Model")
	model.Name = "House"
	local base = part(model, { Name = "Walls", Size = Vector3.new(3, 2.2, 2.6), Color = RGB(245, 235, 215), CFrame = CFrame.new(0, 1.1, 0) })
	model.PrimaryPart = base
	for _, side in ipairs({ -1, 1 }) do
		local roof = Instance.new("WedgePart")
		roof.Size = Vector3.new(3.4, 1.4, 1.6)
		roof.Color = RGB(220, 70, 60)
		roof.Anchored = true
		roof.CanCollide = false
		roof.CFrame = CFrame.new(0, 2.9, side * 0.8) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
		roof.Parent = model
	end
	part(model, { Name = "Door", Size = Vector3.new(0.8, 1.3, 0.1), Color = RGB(130, 85, 50), CFrame = CFrame.new(0, 0.65, -1.32) })
	for _, x in ipairs({ -0.95, 0.95 }) do
		part(model, { Name = "Window", Size = Vector3.new(0.6, 0.6, 0.1), Color = RGB(120, 200, 255), CFrame = CFrame.new(x, 1.4, -1.32) })
	end
	part(model, { Name = "Grass", Size = Vector3.new(3.8, 0.3, 3.4), Color = RGB(96, 200, 70), CFrame = CFrame.new(0, -0.15, 0) })
	return model
end

-- Moneda (icono del dinero).
function GearModels.Coin(): Model
	local model = Instance.new("Model")
	model.Name = "Coin"
	local coin = part(model, { Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.2, 2.2), Color = RGB(255, 200, 50),
		Reflectance = 0.2, CFrame = CFrame.Angles(0, math.rad(90), 0) })
	model.PrimaryPart = coin
	part(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 1.6, 1.6), Color = RGB(255, 225, 110),
		CFrame = CFrame.Angles(0, math.rad(90), 0) })
	part(model, { Name = "Mark", Size = Vector3.new(0.35, 0.9, 0.5), Color = RGB(220, 150, 30), CFrame = CFrame.new(0, 0, -0.03) })
	return model
end

-- Libro (icono del índice).
function GearModels.Book(): Model
	local model = Instance.new("Model")
	model.Name = "Book"
	local cover = part(model, { Name = "Cover", Size = Vector3.new(2.2, 2.8, 0.5), Color = RGB(40, 120, 230), CFrame = CFrame.new() })
	model.PrimaryPart = cover
	part(model, { Name = "Pages", Size = Vector3.new(2, 2.6, 0.52), Color = RGB(250, 245, 230), CFrame = CFrame.new(0.12, 0, 0) })
	part(model, { Name = "Spine", Size = Vector3.new(0.3, 2.8, 0.56), Color = RGB(25, 80, 170), CFrame = CFrame.new(-1.05, 0, 0) })
	part(model, { Name = "Star", Size = Vector3.new(0.8, 0.8, 0.1), Color = RGB(255, 205, 40), Material = Enum.Material.Neon,
		CFrame = CFrame.new(0.1, 0.3, -0.3) * CFrame.Angles(0, 0, math.rad(45)) })
	return model
end

-- Poción de boost: frasco con líquido de color, tapón de corcho y brillo.
function GearModels.Potion(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Potion"
	local bottle = part(model, { Name = "Bottle", Size = Vector3.new(1.8, 1.8, 1.8), Color = RGB(220, 245, 255), Material = Enum.Material.Glass,
		Transparency = 0.45, CFrame = CFrame.new(0, 0.9, 0) })
	model.PrimaryPart = bottle
	part(model, { Name = "Liquid", Size = Vector3.new(1.55, 1.2, 1.55), Color = color, Material = Enum.Material.Neon, Transparency = 0.15,
		CFrame = CFrame.new(0, 0.7, 0) })
	part(model, { Name = "Neck", Size = Vector3.new(0.7, 0.7, 0.7), Color = RGB(220, 245, 255), Material = Enum.Material.Glass,
		Transparency = 0.4, CFrame = CFrame.new(0, 2.1, 0) })
	part(model, { Name = "Cork", Size = Vector3.new(0.6, 0.5, 0.6), Color = RGB(160, 115, 70), Material = Enum.Material.Wood, CFrame = CFrame.new(0, 2.65, 0) })
	part(model, { Name = "Shine", Size = Vector3.new(0.2, 0.9, 0.1), Color = RGB(255, 255, 255), Material = Enum.Material.Neon,
		CFrame = CFrame.new(-0.5, 1.1, -0.92) })
	return model
end

-- Cofre del tesoro (premio al subir de nivel). La tapa es una pieza aparte ("Lid") para poder abrirla.
function GearModels.Chest(): Model
	local model = Instance.new("Model")
	model.Name = "Chest"
	local wood, dark, gold = RGB(150, 95, 50), RGB(105, 65, 35), RGB(255, 200, 50)
	local base = part(model, { Name = "Base", Size = Vector3.new(3, 1.8, 2), Color = wood, Material = Enum.Material.WoodPlanks, CFrame = CFrame.new(0, 0.9, 0) })
	model.PrimaryPart = base
	for _, x in ipairs({ -1.35, 1.35 }) do
		part(model, { Name = "Band", Size = Vector3.new(0.25, 1.85, 2.05), Color = gold, Reflectance = 0.2, CFrame = CFrame.new(x, 0.9, 0) })
	end
	part(model, { Name = "Rim", Size = Vector3.new(3.05, 0.2, 2.05), Color = dark, CFrame = CFrame.new(0, 1.8, 0) })
	part(model, { Name = "Gold", Size = Vector3.new(2.6, 0.4, 1.6), Color = gold, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 1.75, 0) })
	part(model, { Name = "Lock", Size = Vector3.new(0.5, 0.6, 0.15), Color = gold, Reflectance = 0.3, CFrame = CFrame.new(0, 1.5, -1.05) })
	local lid = part(model, { Name = "Lid", Size = Vector3.new(3, 0.7, 2), Color = wood, Material = Enum.Material.WoodPlanks, CFrame = CFrame.new(0, 2.25, 0) })
	part(model, { Name = "LidBand", Size = Vector3.new(3.05, 0.25, 0.3), Color = gold, Reflectance = 0.2, CFrame = CFrame.new(0, 2.25, -0.9) })
	lid:SetAttribute("Hinge", true)
	return model
end

-- Corona (icono del pase VIP).
function GearModels.Crown(): Model
	local model = Instance.new("Model")
	model.Name = "Crown"
	local band = part(model, { Name = "Band", Size = Vector3.new(2.6, 0.8, 2.6), Color = RGB(255, 200, 50), Reflectance = 0.2, CFrame = CFrame.new() })
	model.PrimaryPart = band
	for i = 0, 3 do
		local a = i * math.pi / 2
		local p = Vector3.new(math.sin(a) * 1.05, 0.9, math.cos(a) * 1.05)
		part(model, { Name = "Spike", Size = Vector3.new(0.6, 1.1, 0.6), Color = RGB(255, 200, 50), Reflectance = 0.2, CFrame = CFrame.new(p) })
		part(model, { Name = "Jewel", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = if i % 2 == 0 then RGB(255, 60, 90) else RGB(70, 170, 255),
			Material = Enum.Material.Neon, CFrame = CFrame.new(p * Vector3.new(1.2, 0, 1.2) + Vector3.new(0, 0, 0)) })
	end
	return model
end

-- Desancla y suelda todas las piezas a `to` (para llevar el modelo encima).
function GearModels.WeldTo(model: Model, to: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = to
			w.Part1 = d
			w.Parent = d
		end
	end
end

return GearModels
