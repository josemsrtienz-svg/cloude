--[[
	MemeGame • WorldBuilder (ModuleScript)
	ServerScriptService > MemeGameServer > Systems > WorldBuilder

	Construye el mundo 3D si no existe ya en el Workspace:
	  Workspace > Lobby          isla flotante: spawn, monumento, estatuas, MemeMarket, zona de trade
	  Workspace > MatchStations  Cabina1..Cabina4 (Zone, Slots, Exit, Door+ProximityPrompt, Sign)
	  Workspace > Maps           Map1..MapN. Si un mapa no existe, se crea un PLACEHOLDER marcado.

	Para usar tus propios modelos: construye/pega tu versión con el MISMO nombre y estructura
	(por ejemplo Workspace > Maps > Map1 con una carpeta "Spawns") y este script la respetará.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local MemeModels = require(Shared.Shared.MemeModels)

local WorldBuilder = {}

local RGB = Color3.fromRGB
local O = GameConfig.World.LobbyOrigin
local FONT_TITLE = Enum.Font.LuckiestGuy
local FONT = Enum.Font.FredokaOne

local refs = {
	Lobby = nil :: Instance?,
	Spawn = nil :: BasePart?,
	MatchZone = nil :: BasePart?,
	Stations = {} :: { [string]: Model },
	Maps = {} :: { [string]: Instance },
}

-- ============================================================ helpers
local function part(parent: Instance, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: any
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in pairs(props) do
		if k ~= "Shape" and k ~= "ClassName" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- cilindro vertical (el eje X del cilindro apunta hacia arriba)
local function disc(parent, name, pos: Vector3, height, diameter, color, material, extra)
	local props = {
		Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material,
	}
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return part(parent, props)
end

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not (f and f:IsA("Folder")) then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- Cartel de texto en una cara de una Part.
local function sign(p: BasePart, face: Enum.NormalId, lines: { { string } }, bg: Color3?, ppu: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 25
	gui.LightInfluence = 0
	gui.Parent = p
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = bg or RGB(20, 16, 40)
	frame.BackgroundTransparency = bg and 0 or 1
	frame.Parent = gui
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = frame
	for _, line in ipairs(lines) do
		label(frame, { Text = line[1], Size = UDim2.fromScale(0.95, tonumber(line[2]) or 0.4),
			TextColor3 = line[3] or Color3.new(1, 1, 1), Font = line[4] or FONT_TITLE })
	end
	return gui
end

local function billboard(adornee: BasePart, text: string, size: UDim2, offset: Vector3, color: Color3?, maxDist: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffsetWorldSpace = offset
	bb.MaxDistance = maxDist or 220
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Parent = adornee
	label(bb, { Text = text, Size = UDim2.fromScale(1, 1), TextColor3 = color or Color3.new(1, 1, 1), Font = FONT_TITLE })
	return bb
end

local function sparkle(parent: Instance, color: Color3, rate: number?)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkles"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Rate = rate or 6
	pe.Lifetime = NumberRange.new(1.2, 2.5)
	pe.Speed = NumberRange.new(1, 4)
	pe.Size = NumberSequence.new(0.5, 0)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = parent
	return pe
end

local function prompt(parent: BasePart, name: string, action: string, objectText: string, distance: number?)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = objectText
	pp.HoldDuration = 0
	pp.MaxActivationDistance = distance or 12
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = parent
	return pp
end

local function statue(parent: Instance, memeId: string, pos: Vector3, facing: Vector3, scale: number)
	local meme = MemeCatalog.Get(memeId)
	local rarity = MemeCatalog.GetRarity(memeId)
	local ped = disc(parent, memeId .. "_Pedestal", pos + Vector3.new(0, 1.5, 0), 3, 10, RGB(45, 40, 70), Enum.Material.Marble)
	local ring = disc(parent, memeId .. "_Ring", pos + Vector3.new(0, 3.1, 0), 0.4, 10.6, rarity.Color, Enum.Material.Neon,
		{ CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = rarity.Color, 14, 1.5
	light.Parent = ring
	sparkle(ring, rarity.Color, 3)
	local model = MemeModels.Build(memeId)
	local height = 6
	if model then
		pcall(function()
			model:ScaleTo(scale)
		end)
		local cf, size = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(cf.Position)
		local center = pos + Vector3.new(0, 3.3 + size.Y / 2, 0)
		model:PivotTo(CFrame.lookAt(center, center + facing))
		model.Parent = parent
		height = size.Y
	else
		billboard(ped, meme and meme.Emoji or "❓", UDim2.fromScale(6, 6), Vector3.new(0, 6, 0))
	end
	if meme then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(12, 3)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 1.5 + height + 3, 0)
		bb.MaxDistance = 120
		bb.LightInfluence = 0
		bb.Parent = ped
		label(bb, { Text = string.upper(meme.Name), Size = UDim2.fromScale(1, 0.6), Font = FONT_TITLE })
		label(bb, { Text = rarity.Name, Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.6), TextColor3 = rarity.Color })
	end
end

-- ============================================================ LOBBY
local function buildIsland(lobby: Instance)
	local d = GameConfig.World.IslandDiameter
	local ground = folder(lobby, "Ground")
	disc(ground, "Island", O - Vector3.new(0, 5, 0), 10, d, RGB(110, 200, 90), Enum.Material.Grass)
	disc(ground, "IslandTrim", O - Vector3.new(0, 5.5, 0), 9, d + 3, RGB(255, 70, 140), Enum.Material.Neon, { CanCollide = false })
	disc(ground, "RockTop", O - Vector3.new(0, 26, 0), 34, d - 30, RGB(105, 90, 80), Enum.Material.Slate)
	disc(ground, "RockMid", O - Vector3.new(0, 56, 0), 30, d - 110, RGB(90, 78, 70), Enum.Material.Slate)
	disc(ground, "RockBottom", O - Vector3.new(0, 80, 0), 22, d - 190, RGB(75, 65, 60), Enum.Material.Slate)

	-- muro invisible en el borde para no caerse sin querer
	local walls = folder(ground, "EdgeWalls")
	local segments = 40
	local r = d / 2 - 1
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local pos = O + Vector3.new(math.sin(a) * r, 8, math.cos(a) * r)
		part(walls, { Name = "Wall", Size = Vector3.new(2 * math.pi * r / segments + 2, 16, 2),
			CFrame = CFrame.lookAt(pos, Vector3.new(O.X, pos.Y, O.Z)), Transparency = 1, CanQuery = false })
		if i % 2 == 0 then
			local postPos = O + Vector3.new(math.sin(a) * r, 2, math.cos(a) * r)
			part(walls, { Name = "Post", Size = Vector3.new(1.4, 4, 1.4), CFrame = CFrame.new(postPos),
				Color = RGB(255, 205, 40), Material = Enum.Material.Neon })
		end
	end

	-- caminos de neón hacia cada zona
	local paths = folder(lobby, "Paths")
	local function path(from: Vector3, to: Vector3, color: Color3)
		local mid = (from + to) / 2
		local len = (to - from).Magnitude
		part(paths, { Name = "Path", Size = Vector3.new(12, 0.3, len), CFrame = CFrame.lookAt(mid, to) + Vector3.new(0, 0.15, 0),
			Color = RGB(235, 230, 245), Material = Enum.Material.Pavement })
		part(paths, { Name = "PathGlowL", Size = Vector3.new(0.6, 0.35, len), CFrame = CFrame.lookAt(mid, to) * CFrame.new(-6, 0.2, 0),
			Color = color, Material = Enum.Material.Neon, CanCollide = false })
		part(paths, { Name = "PathGlowR", Size = Vector3.new(0.6, 0.35, len), CFrame = CFrame.lookAt(mid, to) * CFrame.new(6, 0.2, 0),
			Color = color, Material = Enum.Material.Neon, CanCollide = false })
	end
	path(O + Vector3.new(0, 0, 100), O + Vector3.new(0, 0, 22), RGB(255, 205, 40))
	path(O + Vector3.new(0, 0, -22), O + Vector3.new(0, 0, -70), RGB(70, 195, 255))
	path(O + Vector3.new(-22, 0, 0), O + Vector3.new(-62, 0, 0), RGB(255, 60, 60))
	path(O + Vector3.new(22, 0, 0), O + Vector3.new(62, 0, 0), RGB(185, 90, 255))
end

local function buildSpawn(lobby: Instance)
	local spawnArea = folder(lobby, "SpawnArea")
	local sp = Instance.new("SpawnLocation")
	sp.Name = "LobbySpawn"
	sp.Anchored = true
	sp.Size = Vector3.new(16, 1, 16)
	sp.CFrame = CFrame.new(O + Vector3.new(0, 0.5, 105))
	sp.Color = RGB(255, 205, 40)
	sp.Material = Enum.Material.Neon
	sp.Neutral = true
	sp.Duration = 3
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = spawnArea
	refs.Spawn = sp

	-- portal estilo dojo/anime en la entrada
	local gate = folder(spawnArea, "Gate")
	local gz = 82
	for _, x in ipairs({ -12, 12 }) do
		part(gate, { Name = "Pillar", Size = Vector3.new(3, 22, 3), CFrame = CFrame.new(O + Vector3.new(x, 11, gz)), Color = RGB(220, 40, 50) })
	end
	part(gate, { Name = "TopBeam", Size = Vector3.new(34, 2.5, 4), CFrame = CFrame.new(O + Vector3.new(0, 23, gz)), Color = RGB(30, 25, 45) })
	part(gate, { Name = "MidBeam", Size = Vector3.new(28, 1.5, 3), CFrame = CFrame.new(O + Vector3.new(0, 18.5, gz)), Color = RGB(220, 40, 50) })
	local plaque = part(gate, { Name = "Plaque", Size = Vector3.new(16, 4, 1), CFrame = CFrame.new(O + Vector3.new(0, 20.8, gz)),
		Color = RGB(255, 205, 40), Material = Enum.Material.Neon })
	sign(plaque, Enum.NormalId.Back, { { "MEME DOJO", 0.9, RGB(30, 25, 45) } }, RGB(255, 205, 40))
	sign(plaque, Enum.NormalId.Front, { { "BUENA SUERTE 🫡", 0.9, RGB(30, 25, 45) } }, RGB(255, 205, 40))

	-- muñecos de entrenamiento
	for i, x in ipairs({ -30, -38, 30, 38 }) do
		local base = O + Vector3.new(x, 0, 92 - (i % 2) * 8)
		part(gate, { Name = "DummyPost", Size = Vector3.new(1, 5, 1), CFrame = CFrame.new(base + Vector3.new(0, 2.5, 0)), Color = RGB(120, 85, 50), Material = Enum.Material.Wood })
		part(gate, { Name = "DummyBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 3, 3),
			CFrame = CFrame.new(base + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = RGB(230, 200, 140), Material = Enum.Material.Fabric })
		part(gate, { Name = "DummyHead", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = CFrame.new(base + Vector3.new(0, 9, 0)), Color = RGB(230, 200, 140), Material = Enum.Material.Fabric })
	end
end

local function buildMonument(lobby: Instance)
	local mon = folder(lobby, "Monument")
	disc(mon, "Plaza", O + Vector3.new(0, 0.2, 0), 0.4, 44, RGB(60, 50, 100), Enum.Material.Marble)
	disc(mon, "PlazaRing", O + Vector3.new(0, 0.25, 0), 0.4, 46, RGB(255, 205, 40), Enum.Material.Neon, { CanCollide = false })
	disc(mon, "Pedestal", O + Vector3.new(0, 3, 0), 6, 22, RGB(40, 35, 65), Enum.Material.Marble)
	local glow = disc(mon, "PedestalGlow", O + Vector3.new(0, 6.1, 0), 0.4, 22.6, RGB(255, 70, 140), Enum.Material.Neon, { CanCollide = false })
	sparkle(glow, RGB(255, 205, 40), 12)

	local chad = MemeModels.Build("GigaChad")
	if chad then
		pcall(function()
			chad:ScaleTo(4)
		end)
		local cf, size = chad:GetBoundingBox()
		chad.WorldPivot = CFrame.new(cf.Position)
		local center = O + Vector3.new(0, 6.3 + size.Y / 2, 0)
		chad:PivotTo(CFrame.lookAt(center, center + Vector3.new(0, 0, 1)))
		chad.Parent = mon
	end

	-- título flotante
	local titleAnchor = part(mon, { Name = "TitleAnchor", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(O + Vector3.new(0, 48, 0)),
		Transparency = 1, CanCollide = false, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(60, 16)
	bb.MaxDistance = 400
	bb.LightInfluence = 0
	bb.Parent = titleAnchor
	label(bb, { Text = "MEME", Size = UDim2.fromScale(1, 0.5), TextColor3 = RGB(255, 205, 40), Font = FONT_TITLE })
	label(bb, { Text = "WARRIORS", Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.5), TextColor3 = RGB(255, 70, 140), Font = FONT_TITLE })

	-- estatuas alrededor (en diagonales, para no tapar los caminos)
	local ids = { "NoobFeliz", "Sospechoso", "PerroBonk", "GatoArcoiris", "Moai", "OgroPantano", "HeroeCalvo", "Stonks" }
	for i, id in ipairs(ids) do
		local a = math.rad(22.5 + (i - 1) * 45)
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		statue(mon, id, O + dir * 42, dir, 2.2)
	end

	-- orbes de energía flotantes (estética anime/entrenamiento)
	local orbs = folder(lobby, "EnergyOrbs")
	local colors = { RGB(70, 195, 255), RGB(255, 205, 40), RGB(255, 70, 140), RGB(120, 255, 120), RGB(185, 90, 255) }
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local pos = O + Vector3.new(math.sin(a) * 95, 30 + (i % 3) * 8, math.cos(a) * 95)
		local orb = part(orbs, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(pos),
			Color = colors[(i % #colors) + 1], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		sparkle(orb, orb.Color, 5)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = orb.Color, 20, 1
		light.Parent = orb
	end

	-- emojis gigantes flotando
	local emojis = { "😂", "🗿", "💀", "🔥", "👑", "🤡", "💯", "😎" }
	for i, e in ipairs(emojis) do
		local a = (i / #emojis) * math.pi * 2 + 0.2
		local anchor = part(orbs, { Name = "Emoji", Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(O + Vector3.new(math.sin(a) * 120, 40 + (i % 2) * 15, math.cos(a) * 120)),
			Transparency = 1, CanCollide = false, CanQuery = false })
		billboard(anchor, e, UDim2.fromScale(14, 14), Vector3.zero, nil, 500)
	end
end

local function buildShop(lobby: Instance)
	local RED, YELLOW, WHITE = RGB(218, 32, 40), RGB(255, 196, 0), RGB(250, 250, 250)
	local shop = Instance.new("Model")
	shop.Name = "MemeMarket"
	shop.Parent = lobby
	local c = O + Vector3.new(-90, 0, 0) -- centro del edificio; el frente mira a +X (hacia la plaza)
	part(shop, { Name = "Floor", Size = Vector3.new(30, 1, 36), CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)), Color = WHITE, Material = Enum.Material.Marble })
	part(shop, { Name = "BackWall", Size = Vector3.new(1, 18, 36), CFrame = CFrame.new(c + Vector3.new(-15, 9, 0)), Color = WHITE })
	part(shop, { Name = "SideWallN", Size = Vector3.new(30, 18, 1), CFrame = CFrame.new(c + Vector3.new(0, 9, -18)), Color = RED })
	part(shop, { Name = "SideWallS", Size = Vector3.new(30, 18, 1), CFrame = CFrame.new(c + Vector3.new(0, 9, 18)), Color = RED })
	part(shop, { Name = "Roof", Size = Vector3.new(32, 1.5, 38), CFrame = CFrame.new(c + Vector3.new(0, 18.5, 0)), Color = RED })
	part(shop, { Name = "StripeN", Size = Vector3.new(30.2, 2, 1.2), CFrame = CFrame.new(c + Vector3.new(0, 14, -18)), Color = YELLOW })
	part(shop, { Name = "StripeS", Size = Vector3.new(30.2, 2, 1.2), CFrame = CFrame.new(c + Vector3.new(0, 14, 18)), Color = YELLOW })
	for _, z in ipairs({ -17, 17 }) do
		part(shop, { Name = "FrontPillar", Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(c + Vector3.new(15, 9, z)), Color = RED })
	end
	-- letrero rojo con franja amarilla
	local header = part(shop, { Name = "Header", Size = Vector3.new(1.5, 7, 38), CFrame = CFrame.new(c + Vector3.new(15.5, 21, 0)), Color = RED })
	part(shop, { Name = "HeaderStripe", Size = Vector3.new(1.6, 1.4, 38), CFrame = CFrame.new(c + Vector3.new(15.5, 17.6, 0)), Color = YELLOW })
	sign(header, Enum.NormalId.Right, { { "MemeMarket", 0.75, WHITE }, { "abierto 24/7 · ¿redondeamos?", 0.25, YELLOW, FONT } }, RED)
	-- toldo
	part(shop, { ClassName = "WedgePart", Name = "Awning", Size = Vector3.new(36, 2, 6),
		CFrame = CFrame.new(c + Vector3.new(18, 16.5, 0)) * CFrame.Angles(0, math.rad(-90), 0), Color = YELLOW })
	-- estanterías con "productos"
	local productColors = { RED, YELLOW, RGB(60, 160, 255), RGB(80, 215, 110), RGB(255, 120, 200) }
	for row = 0, 2 do
		local shelfPos = c + Vector3.new(-13, 2 + row * 4, 0)
		part(shop, { Name = "Shelf", Size = Vector3.new(3, 0.4, 30), CFrame = CFrame.new(shelfPos), Color = RGB(200, 200, 205) })
		for i = 0, 9 do
			part(shop, { Name = "Product", Size = Vector3.new(1.6, 2.2, 1.8),
				CFrame = CFrame.new(shelfPos + Vector3.new(0, 1.3, -13.5 + i * 3)), Color = productColors[(i + row) % #productColors + 1] })
		end
	end
	-- mostrador + dependiente
	local counter = part(shop, { Name = "Counter", Size = Vector3.new(4, 4, 14), CFrame = CFrame.new(c + Vector3.new(4, 2.5, 0)), Color = RED })
	part(shop, { Name = "CounterTop", Size = Vector3.new(4.4, 0.4, 14.4), CFrame = CFrame.new(c + Vector3.new(4, 4.7, 0)), Color = YELLOW })
	local clerk = MemeModels.Build("ChicoTienda")
	if clerk then
		pcall(function()
			clerk:ScaleTo(1.6)
		end)
		local cf, size = clerk:GetBoundingBox()
		clerk.WorldPivot = CFrame.new(cf.Position)
		local center = c + Vector3.new(-1, 1 + size.Y / 2, 0)
		clerk:PivotTo(CFrame.lookAt(center, center + Vector3.new(1, 0, 0)))
		clerk.Name = "Clerk"
		clerk.Parent = shop
	end
	billboard(counter, "🛒 MemeMarket\n[E] para comprar", UDim2.fromScale(12, 4), Vector3.new(0, 11, 0), YELLOW, 60)
	prompt(counter, "OpenShop", "Abrir MemeMarket", "Chico de la Tienda", 14)
end

local function buildTradeZone(lobby: Instance)
	local zone = folder(lobby, "TradeZone")
	local c = O + Vector3.new(85, 0, 0)
	disc(zone, "Plaza", c + Vector3.new(0, 0.25, 0), 0.5, 40, RGB(60, 45, 110), Enum.Material.Marble)
	disc(zone, "Ring", c + Vector3.new(0, 0.3, 0), 0.5, 42, RGB(185, 90, 255), Enum.Material.Neon, { CanCollide = false })
	for _, z in ipairs({ -10, 10 }) do
		part(zone, { Name = "Table", Size = Vector3.new(6, 0.6, 4), CFrame = CFrame.new(c + Vector3.new(6, 3, z)), Color = RGB(250, 250, 250) })
		part(zone, { Name = "TableLeg", Size = Vector3.new(1, 3, 1), CFrame = CFrame.new(c + Vector3.new(6, 1.5, z)), Color = RGB(80, 80, 90) })
	end
	local kiosk = part(zone, { Name = "TradeKiosk", Size = Vector3.new(4, 6, 4), CFrame = CFrame.new(c + Vector3.new(0, 3, 0)),
		Color = RGB(185, 90, 255), Material = Enum.Material.Neon })
	sparkle(kiosk, RGB(185, 90, 255), 8)
	local board = part(zone, { Name = "Board", Size = Vector3.new(1, 10, 24), CFrame = CFrame.new(c + Vector3.new(18, 8, 0)), Color = RGB(30, 25, 50) })
	sign(board, Enum.NormalId.Left, { { "ZONA DE TRADEO 🤝", 0.55, RGB(255, 205, 40) }, { "Intercambia memes con otros jugadores", 0.3, nil, FONT } }, RGB(30, 25, 50))
	billboard(kiosk, "🤝 TRADEO\n[E] para intercambiar", UDim2.fromScale(12, 4), Vector3.new(0, 7, 0), RGB(220, 180, 255), 60)
	prompt(kiosk, "OpenTrade", "Abrir Trade", "Zona de Tradeo", 14)
end

-- ============================================================ CABINAS
local function buildStation(parent: Instance, cfg: any, index: number): Model
	local count = #GameConfig.Stations
	local x = (index - (count + 1) / 2) * 30
	local c = O + Vector3.new(x, 0, -100) -- centro de la cabina; la puerta mira a +Z
	local model = Instance.new("Model")
	model.Name = cfg.Id
	model:SetAttribute("StationId", cfg.Id)
	model.Parent = parent
	local col = cfg.Color
	local GLASS = RGB(170, 220, 255)

	part(model, { Name = "Floor", Size = Vector3.new(20, 1, 18), CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)), Color = RGB(40, 35, 65), Material = Enum.Material.Marble })
	part(model, { Name = "FloorGlow", Size = Vector3.new(16, 0.2, 14), CFrame = CFrame.new(c + Vector3.new(0, 1.05, 0)), Color = col, Material = Enum.Material.Neon, CanCollide = false })
	part(model, { Name = "BackWall", Size = Vector3.new(20, 14, 1), CFrame = CFrame.new(c + Vector3.new(0, 7.5, -9)), Color = RGB(30, 25, 50) })
	part(model, { Name = "WallL", Size = Vector3.new(1, 14, 18), CFrame = CFrame.new(c + Vector3.new(-10, 7.5, 0)), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.5 })
	part(model, { Name = "WallR", Size = Vector3.new(1, 14, 18), CFrame = CFrame.new(c + Vector3.new(10, 7.5, 0)), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.5 })
	part(model, { Name = "Roof", Size = Vector3.new(22, 1.5, 20), CFrame = CFrame.new(c + Vector3.new(0, 15, 0)), Color = col })
	-- marco de la puerta (abierta)
	part(model, { Name = "FrameL", Size = Vector3.new(4, 14, 1.5), CFrame = CFrame.new(c + Vector3.new(-8, 7.5, 9)), Color = col })
	part(model, { Name = "FrameR", Size = Vector3.new(4, 14, 1.5), CFrame = CFrame.new(c + Vector3.new(8, 7.5, 9)), Color = col })
	local door = part(model, { Name = "Door", Size = Vector3.new(12, 2, 1.5), CFrame = CFrame.new(c + Vector3.new(0, 13.5, 9)), Color = col, Material = Enum.Material.Neon })
	prompt(door, "EnterPrompt", "Entrar", cfg.Name, 18)

	-- zona interior (detección física de quién está dentro)
	part(model, { Name = "Zone", Size = Vector3.new(18, 12, 17), CFrame = CFrame.new(c + Vector3.new(0, 7, 0)),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local slots = folder(model, "Slots")
	local offsets = { Vector3.new(-3.5, 0, -3), Vector3.new(3.5, 0, -3), Vector3.new(-3.5, 0, 3), Vector3.new(3.5, 0, 3) }
	for i = 1, cfg.Capacity do
		local off = cfg.Capacity == 1 and Vector3.zero or offsets[i]
		local slot = part(slots, { Name = "Slot" .. i, Size = Vector3.new(4, 0.2, 4), CFrame = CFrame.new(c + off + Vector3.new(0, 1.2, 0)),
			Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
		slot:SetAttribute("Slot", i)
	end
	part(model, { Name = "Exit", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(c + Vector3.new(0, 1, 20)),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	-- cartel con estado (lo actualiza Matchmaking)
	local board = part(model, { Name = "Sign", Size = Vector3.new(18, 9, 1), CFrame = CFrame.new(c + Vector3.new(0, 21, 8)), Color = RGB(20, 16, 40) })
	part(model, { Name = "SignPost", Size = Vector3.new(1, 6, 1), CFrame = CFrame.new(c + Vector3.new(0, 16, 8)), Color = RGB(60, 55, 90) })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = RGB(20, 16, 40)
	bg.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 8
	stroke.Color = col
	stroke.Parent = bg
	label(bg, { Name = "Title", Text = cfg.Name, Size = UDim2.fromScale(0.94, 0.3), Position = UDim2.fromScale(0.03, 0.04), Font = FONT_TITLE, TextColor3 = col })
	label(bg, { Name = "Count", Text = ("0/%d"):format(cfg.Capacity), Size = UDim2.fromScale(0.94, 0.34), Position = UDim2.fromScale(0.03, 0.34), Font = FONT_TITLE })
	label(bg, { Name = "Status", Text = "LIBRE · ENTRA", Size = UDim2.fromScale(0.94, 0.16), Position = UDim2.fromScale(0.03, 0.68), TextColor3 = RGB(120, 255, 140) })
	label(bg, { Name = "Players", Text = "", Size = UDim2.fromScale(0.94, 0.12), Position = UDim2.fromScale(0.03, 0.85), TextColor3 = RGB(200, 195, 230), Font = FONT })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = col, 18, 2
	light.Parent = model.FloorGlow
	return model
end

local function buildMatchZone(lobby: Instance)
	local zone = folder(lobby, "MatchZone")
	local arch = O + Vector3.new(0, 0, -72)
	for _, x in ipairs({ -26, 26 }) do
		part(zone, { Name = "ArchPillar", Size = Vector3.new(3, 24, 3), CFrame = CFrame.new(arch + Vector3.new(x, 12, 0)), Color = RGB(70, 195, 255), Material = Enum.Material.Neon })
	end
	local top = part(zone, { Name = "ArchTop", Size = Vector3.new(56, 6, 2), CFrame = CFrame.new(arch + Vector3.new(0, 26, 0)), Color = RGB(20, 16, 40) })
	sign(top, Enum.NormalId.Back, { { "⚔️ ZONA DE PARTIDAS ⚔️", 0.8, RGB(255, 205, 40) } }, RGB(20, 16, 40))
	sign(top, Enum.NormalId.Front, { { "VUELVE PRONTO 👋", 0.8, RGB(255, 205, 40) } }, RGB(20, 16, 40))
	part(zone, { Name = "Floor", Size = Vector3.new(130, 0.4, 44), CFrame = CFrame.new(O + Vector3.new(0, 0.2, -96)), Color = RGB(50, 45, 85), Material = Enum.Material.Marble })
	-- marcador al que apunta el botón JUGAR
	refs.MatchZone = part(zone, { Name = "NavTarget", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(O + Vector3.new(0, 3, -76)),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end

-- ============================================================ MAPAS (placeholders)
local function buildPlaceholderMap(parent: Instance, cfg: any): Model
	local c = O + cfg.PlaceholderOffset
	local model = Instance.new("Model")
	model.Name = cfg.Id
	model:SetAttribute("Placeholder", true)
	model.Parent = parent
	local col = cfg.Color
	part(model, { Name = "StartPlatform", Size = Vector3.new(60, 4, 40), CFrame = CFrame.new(c + Vector3.new(0, -2, 60)), Color = col, Material = Enum.Material.Grass })
	part(model, { Name = "StartTrim", Size = Vector3.new(61, 3, 41), CFrame = CFrame.new(c + Vector3.new(0, -2.2, 60)), Color = RGB(255, 205, 40), Material = Enum.Material.Neon, CanCollide = false })
	local board = part(model, { Name = "PlaceholderSign", Size = Vector3.new(1, 14, 36), CFrame = CFrame.new(c + Vector3.new(-31, 7, 60)), Color = RGB(20, 16, 40) })
	sign(board, Enum.NormalId.Right, {
		{ "🚧 PLACEHOLDER · " .. cfg.Name .. " 🚧", 0.35, RGB(255, 205, 40) },
		{ "Este mapa todavía no existe.", 0.2, nil, FONT },
		{ "Reemplázalo en Workspace > Maps > " .. cfg.Id, 0.2, RGB(120, 220, 255), FONT },
		{ "Objetivo de prueba: llega a la META 🏁", 0.2, RGB(120, 255, 140), FONT },
	}, RGB(20, 16, 40))
	local spawns = folder(model, "Spawns")
	for i = 1, 4 do
		part(spawns, { Name = "Spawn" .. i, Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(c + Vector3.new(-12 + (i - 1) * 8, 0.5, 66)),
			Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false })
	end
	-- recorrido de saltos simple hacia la meta
	local steps = {
		Vector3.new(0, 0, 28), Vector3.new(-10, 3, 14), Vector3.new(4, 6, 2), Vector3.new(14, 9, -10),
		Vector3.new(2, 12, -22), Vector3.new(-10, 15, -34),
	}
	for i, off in ipairs(steps) do
		part(model, { Name = "Step" .. i, Size = Vector3.new(10, 2, 10), CFrame = CFrame.new(c + off), Color = i % 2 == 0 and RGB(255, 255, 255) or col })
	end
	part(model, { Name = "GoalPlatform", Size = Vector3.new(24, 2, 20), CFrame = CFrame.new(c + Vector3.new(0, 18, -52)), Color = RGB(40, 35, 65) })
	local goal = part(model, { Name = "Goal", Size = Vector3.new(14, 1, 10), CFrame = CFrame.new(c + Vector3.new(0, 19.5, -52)),
		Color = RGB(120, 255, 120), Material = Enum.Material.Neon, CanCollide = false })
	sparkle(goal, RGB(120, 255, 120), 15)
	billboard(goal, "🏁 META", UDim2.fromScale(14, 5), Vector3.new(0, 6, 0), RGB(120, 255, 140), 300)
	return model
end

-- ============================================================ API
local function findOurs(parent: Instance, attr: string): Instance?
	for _, child in ipairs(parent:GetChildren()) do
		if child:GetAttribute(attr) then
			return child
		end
	end
	return nil
end

function WorldBuilder.Build()
	-- Lobby
	local lobby = findOurs(Workspace, "MemeGameLobby")
	if not lobby then
		lobby = Instance.new("Folder")
		lobby.Name = "Lobby"
		lobby:SetAttribute("MemeGameLobby", true)
		buildIsland(lobby)
		buildSpawn(lobby)
		buildMonument(lobby)
		buildShop(lobby)
		buildTradeZone(lobby)
		buildMatchZone(lobby)
		lobby.Parent = Workspace
	else
		refs.Spawn = lobby:FindFirstChild("LobbySpawn", true) :: BasePart?
		refs.MatchZone = lobby:FindFirstChild("NavTarget", true) :: BasePart?
	end
	refs.Lobby = lobby

	-- Cabinas
	local stations = folder(Workspace, "MatchStations")
	for i, cfg in ipairs(GameConfig.Stations) do
		local model = stations:FindFirstChild(cfg.Id)
		if not (model and model:FindFirstChild("Zone") and model:FindFirstChild("Slots")) then
			model = buildStation(stations, cfg, i)
		end
		refs.Stations[cfg.Id] = model :: Model
	end

	-- Mapas
	local maps = folder(Workspace, "Maps")
	for _, cfg in ipairs(GameConfig.Maps) do
		local map = maps:FindFirstChild(cfg.Id)
		if not map then
			map = buildPlaceholderMap(maps, cfg)
			print(("[MemeGame] %s no existe todavía: se creó un PLACEHOLDER en Workspace > Maps > %s"):format(cfg.Id, cfg.Id))
		end
		refs.Maps[cfg.Id] = map
	end
end

function WorldBuilder.GetSpawnCFrame(): CFrame
	local sp = refs.Spawn
	if sp then
		return sp.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(O + Vector3.new(0, 5, 100))
end

function WorldBuilder.GetSpawnLocation(): SpawnLocation?
	local sp = refs.Spawn
	return if sp and sp:IsA("SpawnLocation") then sp else nil
end

function WorldBuilder.GetStation(id: string): Model?
	return refs.Stations[id]
end

function WorldBuilder.GetMap(id: string): Instance?
	local map = refs.Maps[id]
	if map and map.Parent then
		return map
	end
	local maps = Workspace:FindFirstChild("Maps")
	return maps and maps:FindFirstChild(id) or nil
end

-- CFrames de aparición del mapa (carpeta "Spawns" o, si no hay, el centro del mapa).
function WorldBuilder.GetMapSpawns(map: Instance): { CFrame }
	local result = {}
	local spawns = map:FindFirstChild("Spawns")
	if spawns then
		local list = spawns:GetChildren()
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		for _, s in ipairs(list) do
			if s:IsA("BasePart") then
				table.insert(result, s.CFrame + Vector3.new(0, 4, 0))
			end
		end
	end
	if #result == 0 then
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("SpawnLocation") then
				table.insert(result, d.CFrame + Vector3.new(0, 4, 0))
			end
		end
	end
	if #result == 0 then
		local cf = if map:IsA("Model") then map:GetPivot() else CFrame.new(O)
		table.insert(result, cf + Vector3.new(0, 10, 0))
	end
	return result
end

return WorldBuilder
