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

-- Mochila-acuario: tanque de cristal con agua, arena, alga y hasta 3 MINI MEMES de verdad dentro.
function GearModels.Tank(aquarium: any, memeIds: { string }?): Model
	local model = Instance.new("Model")
	model.Name = "Tank"
	local glass = part(model, { Name = "Glass", Size = Vector3.new(1.9, 2.2, 1.1), Color = RGB(200, 240, 255),
		Material = Enum.Material.Glass, Transparency = 0.6, CFrame = CFrame.new() })
	model.PrimaryPart = glass
	part(model, { Name = "Water", Size = Vector3.new(1.75, 1.6, 0.95), Color = RGB(60, 170, 230), Transparency = 0.55,
		CFrame = CFrame.new(0, -0.25, 0) })
	part(model, { Name = "Sand", Size = Vector3.new(1.75, 0.2, 0.95), Color = RGB(235, 215, 160), Material = Enum.Material.Sand,
		CFrame = CFrame.new(0, -0.95, 0) })
	part(model, { Name = "Weed", Size = Vector3.new(0.12, 0.7, 0.12), Color = RGB(70, 190, 90), CFrame = CFrame.new(0.65, -0.5, 0.25) })
	part(model, { Name = "Weed", Size = Vector3.new(0.12, 0.45, 0.12), Color = RGB(50, 160, 70), CFrame = CFrame.new(0.75, -0.62, 0.1) })
	part(model, { Name = "Lid", Size = Vector3.new(2.05, 0.25, 1.25), Color = aquarium.Color, CFrame = CFrame.new(0, 1.2, 0) })
	part(model, { Name = "Bottom", Size = Vector3.new(2.05, 0.25, 1.25), Color = aquarium.Color, CFrame = CFrame.new(0, -1.2, 0) })
	for _, x in ipairs({ -0.97, 0.97 }) do
		part(model, { Name = "Frame", Size = Vector3.new(0.12, 2.2, 1.2), Color = aquarium.Color, CFrame = CFrame.new(x, 0, 0) })
		part(model, { Name = "Strap", Size = Vector3.new(0.25, 0.15, 1.6), Color = RGB(60, 45, 35), Material = Enum.Material.Fabric,
			CFrame = CFrame.new(x * 0.55, 1.1, -0.8) })
	end
	part(model, { Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.18, Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Glass, Transparency = 0.3, CFrame = CFrame.new(0.5, 0.4, -0.3) })
	part(model, { Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.12, Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Glass, Transparency = 0.3, CFrame = CFrame.new(0.35, 0.75, -0.2) })
	-- mini memes de pie sobre la arena, mirando hacia fuera (la espalda del jugador)
	for i, memeId in ipairs(memeIds or {}) do
		if i > 3 then
			break
		end
		if MemeModels.Has(memeId) then
			local mini = MemeModels.Build(memeId, 0.13, false, false)
			mini:PivotTo(CFrame.new(-0.55 + (i - 1) * 0.55, -0.85, 0.05) * CFrame.Angles(0, math.pi, 0))
			for _, d in ipairs(mini:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Massless = true
					d.CastShadow = false
				end
			end
			mini.Parent = model
		end
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
