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
}

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
		local light = Instance.new("PointLight")
		light.Color = RGB(160, 100, 255)
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = orb
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
