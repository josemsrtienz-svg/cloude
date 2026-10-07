-- BORRADOR (fuera de src, Rojo no lo carga): modelos de mascotas guardados para cuando se hagan las mascotas.
--[[
	PescaDeMemes • PetModels (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > PetModels

	Modelos de bloques de las MASCOTAS (Config/Pets) y de los huevos. Mismo estilo voxel que los memes:
	origen en los PIES (centro de la base), de frente hacia -Z, todo anclado y sin colisión.
	  PetModels.Build(petId, scale?) → Model      PetModels.Egg(eggId, scale?) → Model
	Diseños originales (brainrots propios). Habibriel es un personaje NUEVO del equipo con estilo voxel
	(pelo rizado en bloques, ojos enormes, peto azul con su insignia "H"), no copia de ningún personaje existente.
]]

local PetModels = {}

local RGB = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic

type Builder = {
	box: (string, Vector3, Vector3, Color3, Enum.Material?, Vector3?) -> BasePart,
	ball: (string, number, Vector3, Color3, Enum.Material?) -> BasePart,
	cyl: (string, Vector3, Vector3, Color3, Enum.Material?, Vector3?) -> BasePart,
}

local function newBuilder(model: Model, scale: number): Builder
	local function finish(p: BasePart, name: string, pos: Vector3, rot: Vector3?)
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = p.Size.Magnitude > 1.5
		local r = rot or Vector3.zero
		p.CFrame = CFrame.new(pos * scale) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		p.Parent = model
	end
	local b = {}
	function b.box(name, size, pos, color, material, rot)
		local p = Instance.new("Part")
		p.Size = size * scale
		p.Color = color
		p.Material = material or SP
		finish(p, name, pos, rot)
		return p
	end
	function b.ball(name, d, pos, color, material)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * d * scale
		p.Color = color
		p.Material = material or SP
		finish(p, name, pos)
		return p
	end
	-- cilindro: Size.X es el largo (eje del cilindro en Roblox)
	function b.cyl(name, size, pos, color, material, rot)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = size * scale
		p.Color = color
		p.Material = material or SP
		finish(p, name, pos, rot)
		return p
	end
	return b :: any
end

-- ojo de dibujo: blanco que sobresale + pupila + brillo
local function eye(b: Builder, pos: Vector3, size: Vector3, look: number?)
	b.box("EyeWhite", size, pos, RGB(250, 250, 250))
	b.box("Pupil", Vector3.new(size.X * 0.32, size.Y * 0.4, 0.06), pos + Vector3.new((look or 0) * size.X * 0.15, -size.Y * 0.05, -size.Z / 2 - 0.02),
		RGB(20, 20, 25))
	b.box("Shine", Vector3.new(size.X * 0.12, size.Y * 0.12, 0.07), pos + Vector3.new(size.X * 0.12, size.Y * 0.14, -size.Z / 2 - 0.04), RGB(255, 255, 255))
end

local builders: { [string]: (Builder) -> () } = {}

-- 👦 HABIBRIEL (SECRETA): chico voxel de cabeza grande. Silueta: cabeza ancha (más que el cuerpo) con pelo
-- rizado en capas y patillas, ojos blancos enormes que sobresalen, nariz marcada; cuerpo de camiseta azul
-- claro con PETO azul (tirantes, botones, bolsillo con su insignia "H" dorada), pantalón corto, piernas
-- morenas, calcetines azul claro y zapatillas azules con puntera y suela blancas. Detalle repartido por todo
-- el cuerpo (espalda incluida: tirantes cruzados y bolsillo trasero).
builders.Habibriel = function(b)
	local skin, skinDark = RGB(176, 116, 72), RGB(150, 96, 58)
	local shirt, denim, denimDark = RGB(156, 205, 240), RGB(48, 108, 218), RGB(32, 80, 175)
	local hair = RGB(22, 24, 30)
	-- pies y piernas
	for _, x in ipairs({ -0.55, 0.55 }) do
		b.box("Sole", Vector3.new(0.95, 0.18, 1.4), Vector3.new(x, 0.09, -0.15), RGB(245, 245, 245))
		b.box("Shoe", Vector3.new(0.9, 0.42, 1.3), Vector3.new(x, 0.38, -0.12), RGB(45, 110, 225))
		b.box("ToeCap", Vector3.new(0.92, 0.28, 0.32), Vector3.new(x, 0.32, -0.72), RGB(245, 245, 245))
		b.box("Lace", Vector3.new(0.5, 0.06, 0.06), Vector3.new(x, 0.6, -0.45), RGB(240, 240, 240))
		b.box("Lace", Vector3.new(0.5, 0.06, 0.06), Vector3.new(x, 0.6, -0.25), RGB(240, 240, 240))
		b.box("Sock", Vector3.new(0.6, 0.38, 0.6), Vector3.new(x, 0.78, 0), shirt)
		b.box("Shin", Vector3.new(0.55, 0.8, 0.55), Vector3.new(x, 1.35, 0), skin)
		b.box("Knee", Vector3.new(0.57, 0.12, 0.57), Vector3.new(x, 1.72, -0.01), skinDark)
		b.box("ShortLeg", Vector3.new(0.88, 0.8, 1.0), Vector3.new(x, 2.15, 0), denim)
		b.box("Cuff", Vector3.new(0.92, 0.14, 1.04), Vector3.new(x, 1.8, 0), denimDark)
	end
	-- cuerpo: camiseta + peto
	b.box("Shirt", Vector3.new(2.0, 1.5, 1.1), Vector3.new(0, 3.35, 0), shirt)
	b.box("OverallsWaist", Vector3.new(2.06, 0.75, 1.16), Vector3.new(0, 2.85, 0), denim)
	b.box("Bib", Vector3.new(1.35, 1.0, 0.1), Vector3.new(0, 3.45, -0.6), denim)
	b.box("BibSeam", Vector3.new(1.37, 0.06, 0.12), Vector3.new(0, 3.95, -0.6), denimDark)
	b.box("Pocket", Vector3.new(0.65, 0.48, 0.06), Vector3.new(0, 3.3, -0.67), denimDark)
	b.box("Badge", Vector3.new(0.12, 0.34, 0.05), Vector3.new(-0.08, 3.32, -0.71), RGB(255, 200, 50), Enum.Material.Metal) -- la "H"
	b.box("Badge", Vector3.new(0.12, 0.34, 0.05), Vector3.new(0.08, 3.32, -0.71), RGB(255, 200, 50), Enum.Material.Metal)
	b.box("Badge", Vector3.new(0.18, 0.08, 0.05), Vector3.new(0, 3.32, -0.72), RGB(255, 200, 50), Enum.Material.Metal)
	b.box("BackPocket", Vector3.new(0.55, 0.4, 0.06), Vector3.new(0.45, 2.8, 0.6), denimDark)
	for _, x in ipairs({ -0.55, 0.55 }) do
		b.box("StrapFront", Vector3.new(0.26, 0.7, 0.08), Vector3.new(x, 4.0, -0.58), denim)
		b.box("Button", Vector3.new(0.16, 0.16, 0.06), Vector3.new(x, 3.88, -0.66), RGB(230, 200, 80), Enum.Material.Metal)
		b.box("StrapTop", Vector3.new(0.26, 0.1, 1.15), Vector3.new(x, 4.12, 0), denim)
		b.box("StrapBack", Vector3.new(0.26, 1.1, 0.08), Vector3.new(x * 0.6, 3.6, 0.58), denim, nil, Vector3.new(0, 0, x * -25))
	end
	-- brazos: manga, brazo moreno, mano
	for _, side in ipairs({ -1, 1 }) do
		b.box("Sleeve", Vector3.new(0.62, 0.62, 0.95), Vector3.new(side * 1.28, 3.78, 0), shirt)
		b.box("SleeveHem", Vector3.new(0.64, 0.1, 0.97), Vector3.new(side * 1.28, 3.45, 0), RGB(130, 185, 225))
		b.box("Arm", Vector3.new(0.46, 1.1, 0.46), Vector3.new(side * 1.28, 2.9, 0), skin)
		b.box("Hand", Vector3.new(0.52, 0.42, 0.52), Vector3.new(side * 1.28, 2.15, -0.02), skin)
		b.box("Thumb", Vector3.new(0.16, 0.22, 0.2), Vector3.new(side * 1.08, 2.2, -0.22), skinDark)
	end
	b.box("Wristband", Vector3.new(0.5, 0.14, 0.5), Vector3.new(1.28, 2.42, 0), RGB(255, 200, 50))
	-- cabeza grande
	b.box("Neck", Vector3.new(0.6, 0.3, 0.6), Vector3.new(0, 4.25, 0), skin)
	b.box("Jaw", Vector3.new(2.2, 0.35, 1.9), Vector3.new(0, 4.55, 0), skin)
	b.box("Head", Vector3.new(2.6, 2.0, 2.2), Vector3.new(0, 5.7, 0), skin)
	for _, side in ipairs({ -1, 1 }) do
		b.box("Ear", Vector3.new(0.28, 0.6, 0.42), Vector3.new(side * 1.42, 5.45, 0.15), skinDark)
		b.box("EarIn", Vector3.new(0.06, 0.3, 0.2), Vector3.new(side * 1.57, 5.45, 0.1), RGB(130, 80, 50))
		b.box("Cheek", Vector3.new(0.4, 0.22, 0.06), Vector3.new(side * 0.85, 4.95, -1.11), RGB(190, 110, 80))
		eye(b, Vector3.new(side * 0.62, 5.85, -1.25), Vector3.new(0.92, 0.88, 0.36), -side)
		b.box("Brow", Vector3.new(0.72, 0.14, 0.1), Vector3.new(side * 0.6, 6.42, -1.13), hair, nil, Vector3.new(0, 0, side * -6))
	end
	b.box("Nose", Vector3.new(0.3, 0.5, 0.38), Vector3.new(0, 5.3, -1.27), skinDark)
	b.box("Nostril", Vector3.new(0.2, 0.08, 0.06), Vector3.new(0, 5.07, -1.45), RGB(120, 75, 45))
	b.box("Mouth", Vector3.new(0.62, 0.1, 0.06), Vector3.new(0, 4.82, -1.12), RGB(90, 45, 35))
	b.box("MouthCorner", Vector3.new(0.12, 0.1, 0.06), Vector3.new(0.34, 4.87, -1.12), RGB(90, 45, 35))
	-- pelo: casquete + rizos en bloques (alturas y tamaños variados, deterministas) + patillas y nuca
	b.box("HairCap", Vector3.new(2.72, 0.45, 2.32), Vector3.new(0, 6.85, 0.05), hair)
	local k = 0
	for ix = -2, 2 do
		for iz = -2, 2 do
			k += 1
			local s = 0.5 + (k % 3) * 0.08
			b.box("Curl", Vector3.new(s, s, s), Vector3.new(ix * 0.52, 7.15 + ((k * 7) % 5) * 0.05, iz * 0.45 + 0.05), hair)
		end
	end
	for ix = -2, 2 do
		b.box("Fringe", Vector3.new(0.5, 0.42, 0.3), Vector3.new(ix * 0.5, 6.62 - (ix % 2) * 0.1, -1.08), hair)
	end
	for _, side in ipairs({ -1, 1 }) do
		b.box("SideHair", Vector3.new(0.34, 1.25, 1.7), Vector3.new(side * 1.38, 6.1, 0.3), hair)
		b.box("SideCurl", Vector3.new(0.42, 0.42, 0.42), Vector3.new(side * 1.5, 5.85, 0.95), hair)
	end
	b.box("BackHair", Vector3.new(2.6, 1.5, 0.36), Vector3.new(0, 6.0, 1.2), hair)
end

-- 🍞 Pez Tostada (COMÚN): una rebanada de pan tostado con forma de pez: corteza, miga con agujeritos,
-- aletas y cola de corteza, mantequilla encima, ojos y migas.
builders.PezTostada = function(b)
	local crust, bread = RGB(170, 105, 45), RGB(240, 205, 140)
	b.box("Crust", Vector3.new(0.8, 2.4, 2.6), Vector3.new(0, 1.6, 0), crust)
	b.box("Crumb", Vector3.new(0.84, 2.0, 2.2), Vector3.new(0, 1.62, 0), bread)
	for i = 0, 5 do
		b.box("Hole", Vector3.new(0.86, 0.12, 0.12), Vector3.new(0, 1.0 + (i % 3) * 0.45, -0.7 + math.floor(i / 3) * 1.1 + (i % 2) * 0.2), RGB(215, 175, 110))
	end
	b.box("Butter", Vector3.new(0.5, 0.25, 0.5), Vector3.new(0, 2.92, -0.2), RGB(255, 235, 120))
	b.box("Melt", Vector3.new(0.3, 0.1, 0.8), Vector3.new(0, 2.82, 0.2), RGB(255, 225, 100))
	b.box("TailTop", Vector3.new(0.4, 0.9, 0.6), Vector3.new(0, 2.1, 1.55), crust, nil, Vector3.new(30, 0, 0))
	b.box("TailBottom", Vector3.new(0.4, 0.9, 0.6), Vector3.new(0, 1.1, 1.55), crust, nil, Vector3.new(-30, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		b.box("Fin", Vector3.new(0.12, 0.5, 0.7), Vector3.new(side * 0.47, 1.3, 0.1), crust, nil, Vector3.new(0, 0, side * 20))
		eye(b, Vector3.new(side * 0.43, 2.05, -0.9), Vector3.new(0.06, 0.45, 0.45), 0)
	end
	b.box("Mouth", Vector3.new(0.5, 0.12, 0.1), Vector3.new(0, 1.4, -1.32), RGB(120, 60, 30))
end

-- 🦀 Cangrejo DJ (POCO COMÚN): cangrejo rojo con caparazón en dos capas, pinzas grandes, tres patas por lado,
-- ojos en antenas, cascos de DJ con diadema y cadena dorada.
builders.CangrejoDJ = function(b)
	local red, redDark = RGB(225, 70, 55), RGB(170, 45, 35)
	b.box("Shell", Vector3.new(2.6, 1.0, 1.9), Vector3.new(0, 1.2, 0), red)
	b.box("ShellTop", Vector3.new(2.1, 0.4, 1.5), Vector3.new(0, 1.85, 0.05), redDark)
	b.box("Belly", Vector3.new(2.2, 0.2, 1.6), Vector3.new(0, 0.62, 0), RGB(250, 200, 170))
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			b.box("Leg", Vector3.new(0.9, 0.2, 0.2), Vector3.new(side * 1.6, 0.75, -0.5 + i * 0.5), redDark, nil, Vector3.new(0, 0, side * -35))
			b.box("LegTip", Vector3.new(0.18, 0.5, 0.18), Vector3.new(side * 2.0, 0.3, -0.5 + i * 0.5), redDark)
		end
		b.box("Arm", Vector3.new(0.3, 0.3, 0.9), Vector3.new(side * 1.25, 1.3, -1.2), red)
		b.box("Claw", Vector3.new(0.7, 0.6, 0.7), Vector3.new(side * 1.35, 1.45, -1.75), red)
		b.box("Pincer", Vector3.new(0.25, 0.22, 0.55), Vector3.new(side * 1.2, 1.85, -2.05), redDark)
		b.box("Stalk", Vector3.new(0.16, 0.6, 0.16), Vector3.new(side * 0.45, 2.3, -0.6), redDark)
		eye(b, Vector3.new(side * 0.45, 2.75, -0.62), Vector3.new(0.4, 0.4, 0.3), 0)
		b.box("EarCup", Vector3.new(0.3, 0.6, 0.6), Vector3.new(side * 1.3, 2.0, 0.1), RGB(30, 30, 40))
		b.box("EarPad", Vector3.new(0.06, 0.45, 0.45), Vector3.new(side * 1.12, 2.0, 0.1), RGB(80, 220, 255), Enum.Material.Neon)
	end
	b.box("Headband", Vector3.new(2.7, 0.18, 0.3), Vector3.new(0, 2.45, 0.1), RGB(40, 40, 50))
	b.box("Smile", Vector3.new(0.7, 0.1, 0.06), Vector3.new(0, 1.15, -0.97), RGB(110, 20, 20))
	for k = -2, 2 do
		b.box("Chain", Vector3.new(0.22, 0.1, 0.1), Vector3.new(k * 0.25, 0.95 - math.abs(k) * 0.05, -0.98), RGB(255, 200, 50), Enum.Material.Metal)
	end
end

-- 🐙 Pulpo Chef (RARO): cabeza en cúpula escalonada, gorro de chef abombado, bigote, seis tentáculos que se
-- curvan (segmentos cada vez más finos, con ventosas) y una espátula en uno de ellos.
builders.PulpoChef = function(b)
	local purple, purpleDark = RGB(165, 90, 210), RGB(125, 60, 170)
	b.box("Mantle", Vector3.new(2.2, 1.6, 2.0), Vector3.new(0, 2.2, 0.1), purple)
	b.box("MantleTop", Vector3.new(1.7, 0.6, 1.6), Vector3.new(0, 3.2, 0.15), purple)
	for i = 0, 3 do
		b.box("Spot", Vector3.new(0.25, 0.25, 0.06), Vector3.new(-0.7 + i * 0.5, 2.6 + (i % 2) * 0.3, 1.12), purpleDark)
	end
	for _, side in ipairs({ -1, 1 }) do
		eye(b, Vector3.new(side * 0.45, 2.35, -0.95), Vector3.new(0.55, 0.6, 0.2), -side)
	end
	b.box("Mustache", Vector3.new(1.0, 0.18, 0.12), Vector3.new(0, 1.85, -0.98), RGB(40, 30, 30))
	b.box("MustacheTipL", Vector3.new(0.25, 0.15, 0.12), Vector3.new(-0.6, 1.95, -0.98), RGB(40, 30, 30), nil, Vector3.new(0, 0, 30))
	b.box("MustacheTipR", Vector3.new(0.25, 0.15, 0.12), Vector3.new(0.6, 1.95, -0.98), RGB(40, 30, 30), nil, Vector3.new(0, 0, -30))
	b.cyl("HatBand", Vector3.new(0.5, 1.5, 1.5), Vector3.new(0, 3.75, 0.15), RGB(250, 250, 250), nil, Vector3.new(0, 0, 90))
	b.ball("HatPuff", 1.4, Vector3.new(0, 4.4, 0.15), RGB(255, 255, 255))
	b.ball("HatPuff", 0.9, Vector3.new(-0.5, 4.3, 0.1), RGB(250, 250, 250))
	b.ball("HatPuff", 0.9, Vector3.new(0.5, 4.3, 0.2), RGB(250, 250, 250))
	for i = 0, 5 do
		local a = (i / 6) * math.pi * 2
		local dx, dz = math.cos(a), math.sin(a)
		for s = 0, 2 do
			local w = 0.42 - s * 0.1
			local r = 0.9 + s * 0.45
			b.box("Tentacle", Vector3.new(w, 0.4, w), Vector3.new(dx * r, 1.25 - s * 0.35, dz * r + 0.1), purple)
			b.box("Sucker", Vector3.new(w * 0.5, 0.06, w * 0.5), Vector3.new(dx * r, 1.02 - s * 0.35, dz * r + 0.1), RGB(240, 190, 230))
		end
	end
	b.box("SpatulaHandle", Vector3.new(0.12, 1.0, 0.12), Vector3.new(1.9, 1.4, -0.6), RGB(120, 80, 50))
	b.box("SpatulaHead", Vector3.new(0.5, 0.45, 0.06), Vector3.new(1.9, 2.05, -0.6), RGB(200, 205, 215), Enum.Material.Metal)
end

-- 🪩 Medusa Disco (ÉPICA): campana translúcida rosa con bola de discoteca dentro (azulejos espejo), borde
-- ondulado y tentáculos de neón de colores y largos distintos.
builders.MedusaDisco = function(b)
	b.ball("Bell", 2.4, Vector3.new(0, 3.2, 0), RGB(255, 140, 210), Enum.Material.Glass).Transparency = 0.35
	b.cyl("Rim", Vector3.new(0.3, 2.5, 2.5), Vector3.new(0, 2.3, 0), RGB(255, 110, 190), nil, Vector3.new(0, 0, 90))
	local disco = b.ball("DiscoBall", 1.1, Vector3.new(0, 3.3, 0), RGB(210, 215, 230), Enum.Material.Metal)
	disco.Reflectance = 0.5
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		b.box("Mirror", Vector3.new(0.22, 0.22, 0.05), Vector3.new(math.cos(a) * 0.55, 3.3 + (i % 2 - 0.5) * 0.3, math.sin(a) * 0.55), RGB(240, 245, 255),
			Enum.Material.Glass, Vector3.new(0, -math.deg(a) + 90, 0)).Reflectance = 0.6
	end
	for _, side in ipairs({ -1, 1 }) do
		eye(b, Vector3.new(side * 0.4, 3.0, -1.15), Vector3.new(0.4, 0.45, 0.12), 0)
	end
	local colors = { RGB(80, 220, 255), RGB(255, 90, 200), RGB(255, 230, 60), RGB(120, 255, 150), RGB(190, 120, 255) }
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local len = 1.2 + (i % 3) * 0.45
		b.box("Tentacle", Vector3.new(0.14, len, 0.14), Vector3.new(math.cos(a) * 0.8, 2.15 - len / 2, math.sin(a) * 0.8), colors[i % #colors + 1],
			Enum.Material.Neon, Vector3.new((i % 2 - 0.5) * 12, 0, 0))
	end
end

-- 🦆 Patito Astronauta (LEGENDARIA): patito de goma con casco de cristal, mochila de soporte vital con
-- luces, antena, cuello del traje y pico naranja.
builders.PatitoAstronauta = function(b)
	local yellow, orange = RGB(255, 215, 50), RGB(255, 140, 30)
	b.box("Body", Vector3.new(2.0, 1.4, 2.4), Vector3.new(0, 1.1, 0.2), yellow)
	b.box("Tail", Vector3.new(0.9, 0.7, 0.5), Vector3.new(0, 1.7, 1.55), yellow, nil, Vector3.new(-25, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		b.box("Wing", Vector3.new(0.25, 0.8, 1.3), Vector3.new(side * 1.05, 1.25, 0.3), RGB(245, 195, 40))
		eye(b, Vector3.new(side * 0.35, 2.75, -0.82), Vector3.new(0.35, 0.4, 0.12), 0)
	end
	b.box("Head", Vector3.new(1.4, 1.3, 1.4), Vector3.new(0, 2.6, -0.2), yellow)
	b.box("Beak", Vector3.new(0.8, 0.3, 0.6), Vector3.new(0, 2.4, -1.15), orange)
	b.box("BeakLow", Vector3.new(0.7, 0.15, 0.5), Vector3.new(0, 2.2, -1.1), RGB(230, 110, 20))
	b.ball("Helmet", 2.1, Vector3.new(0, 2.65, -0.2), RGB(200, 235, 255), Enum.Material.Glass).Transparency = 0.6
	b.cyl("Collar", Vector3.new(0.3, 1.8, 1.8), Vector3.new(0, 1.75, -0.2), RGB(235, 238, 245), Enum.Material.Metal, Vector3.new(0, 0, 90))
	b.box("Pack", Vector3.new(1.4, 1.3, 0.6), Vector3.new(0, 1.6, 1.45), RGB(240, 242, 248))
	b.box("PackLight", Vector3.new(0.2, 0.2, 0.06), Vector3.new(-0.35, 1.9, 1.77), RGB(255, 60, 60), Enum.Material.Neon)
	b.box("PackLight", Vector3.new(0.2, 0.2, 0.06), Vector3.new(0.35, 1.9, 1.77), RGB(80, 255, 120), Enum.Material.Neon)
	b.box("PackVent", Vector3.new(0.8, 0.1, 0.06), Vector3.new(0, 1.4, 1.77), RGB(150, 155, 165))
	b.box("Antenna", Vector3.new(0.08, 0.9, 0.08), Vector3.new(0.5, 2.6, 1.45), RGB(160, 165, 175), Enum.Material.Metal)
	b.ball("AntennaTip", 0.22, Vector3.new(0.5, 3.1, 1.45), RGB(255, 60, 60), Enum.Material.Neon)
end

-- ===== Huevos =====
-- Huevo voxel: capas de bloques que forman la silueta ovalada, manchas del color del huevo y una grieta.
local EGG_STYLE = {
	HuevoMeme = { Shell = RGB(250, 245, 230), Spot = RGB(110, 200, 255) },
	HuevoDorado = { Shell = RGB(255, 210, 70), Spot = RGB(255, 245, 190), Metal = true },
}

function PetModels.Egg(eggId: string, scale: number?): Model
	local s = scale or 1
	local style = EGG_STYLE[eggId] or EGG_STYLE.HuevoMeme
	local model = Instance.new("Model")
	model.Name = "Egg_" .. eggId
	local b = newBuilder(model, s)
	local mat = if style.Metal then Enum.Material.Metal else SP
	local layers = { { 1.6, 0.4 }, { 2.2, 1.0 }, { 2.4, 1.7 }, { 2.3, 2.4 }, { 2.0, 3.0 }, { 1.5, 3.5 }, { 0.8, 3.85 } }
	local root
	for i, l in ipairs(layers) do
		local p = b.box("Layer", Vector3.new(l[1], 0.62, l[1]), Vector3.new(0, l[2], 0), style.Shell, mat)
		if i == 3 then
			root = p
		end
	end
	model.PrimaryPart = root
	local spots = { Vector3.new(-0.9, 1.6, -0.9), Vector3.new(0.8, 2.3, -1.0), Vector3.new(-0.6, 3.0, -0.85), Vector3.new(1.1, 1.2, 0.3),
		Vector3.new(-1.15, 2.4, 0.4), Vector3.new(0.3, 2.9, 0.95) }
	for _, p in ipairs(spots) do
		b.box("Spot", Vector3.new(0.4, 0.4, 0.4), p, style.Spot, mat)
	end
	b.box("Crack", Vector3.new(0.5, 0.08, 0.06), Vector3.new(0.2, 2.65, -1.18), RGB(80, 70, 60), nil, Vector3.new(0, 0, 25))
	b.box("Crack", Vector3.new(0.4, 0.08, 0.06), Vector3.new(-0.2, 2.5, -1.18), RGB(80, 70, 60), nil, Vector3.new(0, 0, -30))
	return model
end

function PetModels.Has(petId: string): boolean
	return builders[petId] ~= nil
end

function PetModels.Build(petId: string, scale: number?): Model
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petId
	local b = newBuilder(model, s)
	local root = b.box("Root", Vector3.new(0.4, 0.1, 0.4), Vector3.new(0, 0.05, 0), RGB(0, 0, 0))
	root.Transparency = 1
	model.PrimaryPart = root
	local builder = builders[petId] or builders.PezTostada
	builder(b)
	return model
end

return PetModels
