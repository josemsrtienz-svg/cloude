--[[
	PescaDeMemes • MemeModels (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Shared > MemeModels

	Figuras de bloques (estilo voxel, como los personajes de los juegos de "steal") para cada meme.
	Se construyen con Parts por código: no hace falta subir mallas.

	MemeModels.Build(memeId, scale?, golden?) → Model
	  · El origen del modelo está en los PIES (centro de la base), mirando hacia -Z (de frente).
	  · scale: 1 ≈ 6–7 studs de alto. golden: lo pinta todo de oro (mutación Dorado).
	  · Todas las piezas son Anchored, sin colisión: pensadas para exponerlas (muévelas con :PivotTo).

	Criterio de diseño: cada meme tiene una SILUETA reconocible (forma principal), formas secundarias
	(orejas, hocico, cejas, músculos, teclas…) y detalles pequeños (brillos en los ojos, costuras,
	calcetines, corbata). Nada de "un cubo con cara".
]]

local MemeModels = {}

local RGB = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic

type Builder = {
	box: (name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, rot: Vector3?) -> BasePart,
	wedge: (name: string, size: Vector3, pos: Vector3, color: Color3, rot: Vector3?) -> BasePart,
	ball: (name: string, d: number, pos: Vector3, color: Color3, material: Enum.Material?) -> BasePart,
}

local function newBuilder(model: Model, scale: number): Builder
	local function finish(p: BasePart, name: string, pos: Vector3, rot: Vector3?)
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
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
	function b.wedge(name, size, pos, color, rot)
		local p = Instance.new("WedgePart")
		p.Size = size * scale
		p.Color = color
		p.Material = SP
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
	return b :: any
end

-- Ojos con brillo: blanco + pupila + destello (se lee bien de lejos y de cerca).
local function eye(b: Builder, pos: Vector3, size: number, lookX: number?)
	b.box("EyeWhite", Vector3.new(size, size, 0.1), pos, RGB(250, 250, 250))
	b.box("Pupil", Vector3.new(size * 0.55, size * 0.6, 0.12), pos + Vector3.new((lookX or 0) * size * 0.2, -size * 0.05, -0.02), RGB(25, 25, 30))
	b.box("Shine", Vector3.new(size * 0.18, size * 0.18, 0.14), pos + Vector3.new((lookX or 0) * size * 0.2 + size * 0.12, size * 0.1, -0.04), RGB(255, 255, 255))
end

local builders: { [string]: (Builder) -> () } = {}

-- 🙂 Noob Feliz: el clásico noob saludando, con calcetines y zapatillas.
builders.NoobFeliz = function(b)
	local yellow, blue, green = RGB(245, 205, 60), RGB(30, 110, 210), RGB(90, 170, 60)
	for _, x in ipairs({ -0.5, 0.5 }) do
		b.box("Shoe", Vector3.new(0.95, 0.4, 1.25), Vector3.new(x, 0.2, -0.1), RGB(60, 60, 70))
		b.box("Leg", Vector3.new(0.95, 1.8, 0.95), Vector3.new(x, 1.3, 0), green)
	end
	b.box("Belt", Vector3.new(2.05, 0.25, 1.05), Vector3.new(0, 2.3, 0), RGB(40, 70, 140))
	b.box("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3.3, 0), blue)
	b.box("Collar", Vector3.new(1.2, 0.2, 1.02), Vector3.new(0, 4.25, 0), RGB(25, 90, 180))
	b.box("ArmL", Vector3.new(0.95, 2, 0.95), Vector3.new(-1.5, 3.3, 0), yellow)
	-- brazo derecho levantado saludando
	b.box("ArmR", Vector3.new(0.95, 2, 0.95), Vector3.new(1.75, 4.6, 0), yellow, nil, Vector3.new(0, 0, -25))
	b.box("Head", Vector3.new(1.7, 1.6, 1.6), Vector3.new(0, 5.2, 0), yellow)
	b.box("HeadTop", Vector3.new(1.3, 0.2, 1.3), Vector3.new(0, 6.1, 0), yellow)
	eye(b, Vector3.new(-0.38, 5.4, -0.81), 0.32)
	eye(b, Vector3.new(0.38, 5.4, -0.81), 0.32)
	-- sonrisa en 3 piezas
	b.box("Mouth", Vector3.new(0.6, 0.14, 0.1), Vector3.new(0, 4.82, -0.81), RGB(40, 25, 20))
	b.box("MouthL", Vector3.new(0.14, 0.2, 0.1), Vector3.new(-0.36, 4.9, -0.81), RGB(40, 25, 20))
	b.box("MouthR", Vector3.new(0.14, 0.2, 0.1), Vector3.new(0.36, 4.9, -0.81), RGB(40, 25, 20))
	b.box("Cheek", Vector3.new(0.25, 0.15, 0.08), Vector3.new(-0.62, 5.0, -0.81), RGB(255, 150, 140))
	b.box("Cheek", Vector3.new(0.25, 0.15, 0.08), Vector3.new(0.62, 5.0, -0.81), RGB(255, 150, 140))
end

-- 🐕 Perro Bonk: perro de pelo canela con el bate en la boca, listo para mandarte a la cárcel.
builders.PerroBonk = function(b)
	local fur, cream, dark = RGB(215, 150, 75), RGB(250, 235, 210), RGB(150, 95, 45)
	b.box("Body", Vector3.new(2.2, 1.9, 3.4), Vector3.new(0, 2.1, 0.4), fur)
	b.box("Belly", Vector3.new(1.6, 0.5, 2.6), Vector3.new(0, 1.2, 0.4), cream)
	b.box("Chest", Vector3.new(1.7, 1.5, 0.4), Vector3.new(0, 2.1, -1.35), cream)
	for _, x in ipairs({ -0.7, 0.7 }) do
		for _, z in ipairs({ -0.8, 1.6 }) do
			b.box("Leg", Vector3.new(0.65, 1.2, 0.65), Vector3.new(x, 0.75, z), fur)
			b.box("Sock", Vector3.new(0.7, 0.35, 0.75), Vector3.new(x, 0.18, z - 0.03), cream)
		end
	end
	-- cola enroscada
	b.box("Tail1", Vector3.new(0.5, 0.9, 0.5), Vector3.new(0, 3.2, 2.1), fur, nil, Vector3.new(-30, 0, 0))
	b.box("Tail2", Vector3.new(0.45, 0.6, 0.45), Vector3.new(0, 3.6, 1.7), cream, nil, Vector3.new(40, 0, 0))
	-- cabeza
	b.box("Neck", Vector3.new(1.3, 1, 1), Vector3.new(0, 3.1, -1.1), fur)
	b.box("Head", Vector3.new(2, 1.8, 1.7), Vector3.new(0, 4.1, -1.4), fur)
	b.box("Muzzle", Vector3.new(1.2, 0.8, 0.8), Vector3.new(0, 3.65, -2.55), cream)
	b.box("Nose", Vector3.new(0.4, 0.3, 0.2), Vector3.new(0, 3.95, -2.98), RGB(30, 25, 25))
	b.box("FaceCream", Vector3.new(1.5, 0.6, 0.1), Vector3.new(0, 3.75, -2.26), cream)
	for _, x in ipairs({ -0.65, 0.65 }) do
		b.wedge("Ear", Vector3.new(0.5, 0.8, 0.5), Vector3.new(x, 5.35, -1.3), fur, Vector3.new(0, 0, 0))
		b.box("EarInner", Vector3.new(0.25, 0.4, 0.1), Vector3.new(x, 5.25, -1.56), RGB(240, 160, 160))
		b.box("Brow", Vector3.new(0.35, 0.12, 0.1), Vector3.new(x * 0.7, 4.75, -2.27), dark, nil, Vector3.new(0, 0, x * -15))
	end
	eye(b, Vector3.new(-0.45, 4.45, -2.27), 0.3, 1)
	eye(b, Vector3.new(0.45, 4.45, -2.27), 0.3, 1)
	-- el bate (bonk)
	b.box("Bat", Vector3.new(3.2, 0.35, 0.35), Vector3.new(0.9, 3.45, -2.6), RGB(170, 115, 60), Enum.Material.Wood, Vector3.new(0, 0, 12))
	b.box("BatTip", Vector3.new(0.9, 0.5, 0.5), Vector3.new(2.35, 3.75, -2.6), RGB(150, 100, 50), Enum.Material.Wood, Vector3.new(0, 0, 12))
	b.box("BatGrip", Vector3.new(0.6, 0.4, 0.4), Vector3.new(-0.55, 3.15, -2.6), RGB(200, 40, 40), nil, Vector3.new(0, 0, 12))
end

-- 📈 Señor Stonks: señor trajeado con su flecha verde que solo sube.
builders.Stonks = function(b)
	local suit, skin, shirt = RGB(45, 60, 95), RGB(240, 200, 170), RGB(245, 245, 245)
	for _, x in ipairs({ -0.5, 0.5 }) do
		b.box("Shoe", Vector3.new(0.95, 0.35, 1.25), Vector3.new(x, 0.18, -0.12), RGB(25, 20, 20))
		b.box("Leg", Vector3.new(0.9, 1.9, 0.9), Vector3.new(x, 1.3, 0), suit)
	end
	b.box("Jacket", Vector3.new(2.1, 2.1, 1.05), Vector3.new(0, 3.3, 0), suit)
	b.wedge("ShirtV", Vector3.new(0.1, 1.2, 0.7), Vector3.new(0, 3.85, -0.54), shirt, Vector3.new(0, 90, 180))
	b.box("Tie", Vector3.new(0.3, 1.1, 0.1), Vector3.new(0, 3.5, -0.58), RGB(200, 40, 50))
	b.box("TieKnot", Vector3.new(0.38, 0.25, 0.12), Vector3.new(0, 4.15, -0.58), RGB(170, 30, 40))
	b.box("Button", Vector3.new(0.15, 0.15, 0.08), Vector3.new(0.4, 2.9, -0.55), RGB(220, 200, 120))
	b.box("ArmL", Vector3.new(0.9, 2, 0.9), Vector3.new(-1.5, 3.3, 0), suit)
	b.box("HandL", Vector3.new(0.8, 0.5, 0.8), Vector3.new(-1.5, 2.05, 0), skin)
	-- brazo derecho señalando la flecha
	b.box("ArmR", Vector3.new(0.9, 2, 0.9), Vector3.new(1.7, 4.1, 0), suit, nil, Vector3.new(0, 0, -50))
	b.box("HandR", Vector3.new(0.7, 0.5, 0.7), Vector3.new(2.45, 4.75, 0), skin, nil, Vector3.new(0, 0, -50))
	b.box("Neck", Vector3.new(0.7, 0.3, 0.7), Vector3.new(0, 4.5, 0), skin)
	b.box("Head", Vector3.new(1.6, 1.7, 1.5), Vector3.new(0, 5.4, 0), skin)
	for _, x in ipairs({ -0.85, 0.85 }) do
		b.box("Ear", Vector3.new(0.15, 0.45, 0.3), Vector3.new(x, 5.35, 0), skin)
		b.box("Hair", Vector3.new(0.2, 0.6, 1.2), Vector3.new(x * 0.95, 5.65, 0.1), RGB(120, 110, 100))
	end
	eye(b, Vector3.new(-0.35, 5.55, -0.76), 0.26)
	eye(b, Vector3.new(0.35, 5.55, -0.76), 0.26)
	b.box("Smirk", Vector3.new(0.55, 0.12, 0.08), Vector3.new(0.1, 4.95, -0.76), RGB(120, 60, 50), nil, Vector3.new(0, 0, 8))
	-- flecha verde "stonks" en escalera detrás
	local green = RGB(60, 230, 90)
	local steps = { Vector3.new(-2.6, 1.5, 1.4), Vector3.new(-1.2, 2.6, 1.4), Vector3.new(0.2, 2.1, 1.4), Vector3.new(1.6, 3.9, 1.4), Vector3.new(3.0, 5.5, 1.4) }
	for i = 1, #steps - 1 do
		local a, c = steps[i], steps[i + 1]
		local mid = (a + c) / 2
		local len = (c - a).Magnitude
		local angle = math.deg(math.atan2(c.Y - a.Y, c.X - a.X))
		b.box("Arrow", Vector3.new(len + 0.4, 0.5, 0.4), mid, green, Enum.Material.Neon, Vector3.new(0, 0, angle))
	end
	b.wedge("ArrowHead", Vector3.new(0.4, 1.4, 1.4), Vector3.new(3.4, 6.1, 1.4), green, Vector3.new(0, 90, -45))
end

-- 🤨 El Sospechoso: ceja levantada, mirada de lado y mano en la barbilla.
builders.Sospechoso = function(b)
	local hoodie, skin = RGB(110, 115, 130), RGB(230, 185, 150)
	for _, x in ipairs({ -0.5, 0.5 }) do
		b.box("Shoe", Vector3.new(0.95, 0.35, 1.2), Vector3.new(x, 0.18, -0.1), RGB(240, 240, 240))
		b.box("Leg", Vector3.new(0.9, 1.7, 0.9), Vector3.new(x, 1.2, 0), RGB(40, 50, 80))
	end
	b.box("Hoodie", Vector3.new(2.1, 2, 1.1), Vector3.new(0, 3.05, 0), hoodie)
	b.box("Pocket", Vector3.new(1.3, 0.5, 0.1), Vector3.new(0, 2.5, -0.58), RGB(95, 100, 115))
	b.box("Hood", Vector3.new(2, 0.5, 0.6), Vector3.new(0, 4.05, 0.4), RGB(95, 100, 115))
	b.box("ArmL", Vector3.new(0.9, 1.9, 0.9), Vector3.new(-1.5, 3.05, 0), hoodie)
	-- brazo derecho doblado hacia la barbilla
	b.box("ArmR", Vector3.new(0.9, 1.4, 0.9), Vector3.new(1.45, 3.2, -0.3), hoodie, nil, Vector3.new(-30, 0, 0))
	b.box("Forearm", Vector3.new(0.8, 1.3, 0.8), Vector3.new(0.9, 4.1, -0.9), hoodie, nil, Vector3.new(0, 0, 45))
	b.box("Hand", Vector3.new(0.6, 0.55, 0.6), Vector3.new(0.4, 4.55, -1.05), skin)
	-- cabeza grande (más grande que el cuerpo: es el chiste)
	b.box("Head", Vector3.new(2.3, 2.2, 2), Vector3.new(0, 5.4, 0), skin)
	b.box("Hair", Vector3.new(2.4, 0.6, 2.1), Vector3.new(0, 6.6, 0.05), RGB(60, 40, 30))
	b.box("Fringe", Vector3.new(1.4, 0.35, 0.3), Vector3.new(-0.4, 6.25, -0.95), RGB(60, 40, 30))
	-- ceja izquierda normal, derecha MUY levantada
	b.box("BrowL", Vector3.new(0.6, 0.15, 0.1), Vector3.new(-0.5, 5.85, -1.02), RGB(50, 35, 25), nil, Vector3.new(0, 0, -5))
	b.box("BrowR", Vector3.new(0.6, 0.15, 0.1), Vector3.new(0.5, 6.15, -1.02), RGB(50, 35, 25), nil, Vector3.new(0, 0, 18))
	eye(b, Vector3.new(-0.5, 5.5, -1.02), 0.38, -1)
	eye(b, Vector3.new(0.5, 5.6, -1.02), 0.42, -1)
	b.box("Nose", Vector3.new(0.3, 0.4, 0.25), Vector3.new(0, 5.15, -1.1), RGB(215, 165, 130))
	b.box("Mouth", Vector3.new(0.6, 0.12, 0.08), Vector3.new(-0.1, 4.75, -1.02), RGB(110, 60, 50), nil, Vector3.new(0, 0, -10))
	-- "?" flotando
	b.box("Q1", Vector3.new(0.6, 0.2, 0.2), Vector3.new(1.6, 8, 0), RGB(255, 205, 40), Enum.Material.Neon)
	b.box("Q2", Vector3.new(0.2, 0.5, 0.2), Vector3.new(1.95, 7.7, 0), RGB(255, 205, 40), Enum.Material.Neon)
	b.box("Q3", Vector3.new(0.2, 0.35, 0.2), Vector3.new(1.65, 7.3, 0), RGB(255, 205, 40), Enum.Material.Neon)
	b.box("Q4", Vector3.new(0.2, 0.2, 0.2), Vector3.new(1.65, 6.9, 0), RGB(255, 205, 40), Enum.Material.Neon)
end

-- 🦆 Pato Infinito: pato regordete con un símbolo de infinito girando encima.
builders.PatoInfinito = function(b)
	local yellow, wing, orange = RGB(255, 215, 50), RGB(240, 190, 35), RGB(255, 140, 30)
	for _, x in ipairs({ -0.55, 0.55 }) do
		b.box("Foot", Vector3.new(0.7, 0.2, 0.9), Vector3.new(x, 0.1, -0.3), orange)
		b.box("Leg", Vector3.new(0.25, 0.6, 0.25), Vector3.new(x, 0.45, 0), orange)
	end
	b.box("Body", Vector3.new(2.6, 2, 3), Vector3.new(0, 1.8, 0.2), yellow)
	b.box("BodyTop", Vector3.new(2.2, 0.5, 2.4), Vector3.new(0, 3, 0.4), yellow)
	b.box("Belly", Vector3.new(2, 1.2, 0.3), Vector3.new(0, 1.6, -1.35), RGB(255, 235, 140))
	b.wedge("Tail", Vector3.new(1.4, 0.9, 0.9), Vector3.new(0, 2.9, 1.95), yellow, Vector3.new(0, 180, 0))
	for _, x in ipairs({ -1.4, 1.4 }) do
		b.box("Wing", Vector3.new(0.3, 1.3, 2), Vector3.new(x, 2.1, 0.4), wing, nil, Vector3.new(0, 0, x * -6))
		b.box("WingTip", Vector3.new(0.25, 0.6, 0.8), Vector3.new(x * 1.02, 1.6, 1.4), wing)
	end
	b.box("Neck", Vector3.new(1.2, 0.8, 1.1), Vector3.new(0, 3.3, -0.8), yellow)
	b.box("Head", Vector3.new(1.8, 1.7, 1.7), Vector3.new(0, 4.3, -0.9), yellow)
	b.box("Tuft", Vector3.new(0.3, 0.5, 0.3), Vector3.new(0, 5.35, -0.8), yellow, nil, Vector3.new(0, 0, 20))
	b.box("BeakTop", Vector3.new(1.1, 0.3, 0.8), Vector3.new(0, 4.05, -2.05), orange)
	b.box("BeakBottom", Vector3.new(0.9, 0.2, 0.6), Vector3.new(0, 3.82, -1.95), RGB(230, 115, 20))
	eye(b, Vector3.new(-0.45, 4.5, -1.76), 0.34)
	eye(b, Vector3.new(0.45, 4.5, -1.76), 0.34)
	-- símbolo de infinito: dos anillos de bloques de neón
	local cyan = RGB(80, 220, 255)
	for _, cx in ipairs({ -0.7, 0.7 }) do
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			b.box("Infinity", Vector3.new(0.22, 0.22, 0.22), Vector3.new(cx + math.cos(a) * 0.65, 6.4 + math.sin(a) * 0.45, -0.9), cyan, Enum.Material.Neon)
		end
	end
end

-- 🎹 Gato Pianista: gato atigrado sentado tocando su piano de cola en miniatura.
builders.GatoPianista = function(b)
	local fur, stripe, white = RGB(150, 150, 160), RGB(95, 95, 105), RGB(240, 240, 240)
	-- piano delante del gato
	b.box("PianoBody", Vector3.new(4, 1.3, 1.8), Vector3.new(0, 2.15, -2.1), RGB(20, 20, 25), Enum.Material.Glass)
	b.box("PianoLid", Vector3.new(4, 0.15, 1.8), Vector3.new(0, 3.1, -2.4), RGB(30, 30, 35), nil, Vector3.new(-25, 0, 0))
	for _, x in ipairs({ -1.8, 1.8 }) do
		b.box("PianoLeg", Vector3.new(0.25, 1.5, 0.25), Vector3.new(x, 0.75, -2.6), RGB(20, 20, 25))
	end
	for k = 0, 9 do
		b.box("WhiteKey", Vector3.new(0.34, 0.15, 0.6), Vector3.new(-1.62 + k * 0.36, 2.85, -1.05), white)
	end
	for _, k in ipairs({ 0, 1, 3, 4, 5, 7, 8 }) do
		b.box("BlackKey", Vector3.new(0.2, 0.18, 0.35), Vector3.new(-1.44 + k * 0.36, 2.97, -1.15), RGB(15, 15, 15))
	end
	-- banqueta
	b.box("Stool", Vector3.new(1.8, 0.4, 1.2), Vector3.new(0, 1.4, 0.3), RGB(120, 40, 50))
	b.box("StoolLeg", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 0.6, 0.3), RGB(60, 40, 30))
	-- gato sentado
	b.box("Body", Vector3.new(1.8, 2, 1.6), Vector3.new(0, 2.6, 0.4), fur)
	b.box("Belly", Vector3.new(1.2, 1.4, 0.2), Vector3.new(0, 2.5, -0.42), white)
	for _, y in ipairs({ 2.3, 2.9 }) do
		b.box("Stripe", Vector3.new(1.85, 0.2, 1.65), Vector3.new(0, y, 0.45), stripe)
	end
	for _, x in ipairs({ -0.6, 0.6 }) do
		b.box("Arm", Vector3.new(0.5, 0.5, 1.4), Vector3.new(x, 3.05, -0.7), fur, nil, Vector3.new(-15, 0, 0))
		b.box("Paw", Vector3.new(0.5, 0.35, 0.45), Vector3.new(x, 2.95, -1.4), white)
	end
	b.box("Tail", Vector3.new(0.35, 1.6, 0.35), Vector3.new(0.9, 2.4, 1.3), fur, nil, Vector3.new(30, 0, -20))
	b.box("TailTip", Vector3.new(0.38, 0.5, 0.38), Vector3.new(1.2, 3.15, 1.75), stripe, nil, Vector3.new(30, 0, -20))
	b.box("Head", Vector3.new(1.9, 1.6, 1.6), Vector3.new(0, 4.4, 0.2), fur)
	b.box("HeadStripe", Vector3.new(0.4, 0.3, 0.1), Vector3.new(0, 5.0, -0.62), stripe)
	for _, x in ipairs({ -0.6, 0.6 }) do
		b.wedge("Ear", Vector3.new(0.5, 0.7, 0.5), Vector3.new(x, 5.5, 0.3), fur)
		b.box("EarInner", Vector3.new(0.22, 0.35, 0.1), Vector3.new(x, 5.42, 0.05), RGB(240, 170, 180))
		for _, dy in ipairs({ -0.05, 0.12 }) do
			b.box("Whisker", Vector3.new(0.7, 0.05, 0.05), Vector3.new(x * 1.25, 4.05 + dy, -0.6), white)
		end
	end
	eye(b, Vector3.new(-0.42, 4.55, -0.62), 0.34)
	eye(b, Vector3.new(0.42, 4.55, -0.62), 0.34)
	b.box("Nose", Vector3.new(0.25, 0.18, 0.1), Vector3.new(0, 4.15, -0.64), RGB(240, 140, 160))
	b.box("Muzzle", Vector3.new(0.7, 0.35, 0.15), Vector3.new(0, 3.95, -0.62), white)
	-- notas musicales flotando
	for i, p in ipairs({ Vector3.new(-1.6, 5.8, -1.5), Vector3.new(1.7, 6.4, -1.2) }) do
		b.box("NoteHead" .. i, Vector3.new(0.4, 0.3, 0.2), p, RGB(255, 205, 40), Enum.Material.Neon)
		b.box("NoteStem" .. i, Vector3.new(0.1, 0.8, 0.1), p + Vector3.new(0.17, 0.45, 0), RGB(255, 205, 40), Enum.Material.Neon)
	end
end

-- 🗿 Moai: cabeza de piedra gigante con cejas pesadas, nariz larga y labios apretados.
builders.Moai = function(b)
	local stone, dark, moss = RGB(120, 118, 115), RGB(80, 78, 76), RGB(95, 120, 70)
	local slate = Enum.Material.Slate
	b.box("Base", Vector3.new(3.4, 0.6, 3), Vector3.new(0, 0.3, 0), dark, slate)
	b.box("Body", Vector3.new(3, 2, 2.4), Vector3.new(0, 1.6, 0.1), stone, slate)
	b.box("Head", Vector3.new(2.8, 4.4, 2.4), Vector3.new(0, 4.8, 0), stone, slate)
	b.box("Top", Vector3.new(2.6, 0.5, 2.2), Vector3.new(0, 7.2, 0.1), stone, slate)
	b.box("Brow", Vector3.new(2.9, 0.7, 0.6), Vector3.new(0, 5.9, -1.3), stone, slate)
	for _, x in ipairs({ -0.75, 0.75 }) do
		b.box("EyeSocket", Vector3.new(0.9, 0.5, 0.2), Vector3.new(x, 5.35, -1.15), dark, slate)
		b.box("Ear", Vector3.new(0.35, 2.2, 0.7), Vector3.new(x * 2.05, 5, 0), stone, slate)
		b.box("Cheek", Vector3.new(0.6, 1.4, 0.3), Vector3.new(x * 1.1, 4.3, -1.25), RGB(110, 108, 105), slate)
	end
	b.box("Nose", Vector3.new(0.8, 2.1, 0.7), Vector3.new(0, 4.6, -1.5), stone, slate)
	b.box("NoseTip", Vector3.new(1, 0.5, 0.8), Vector3.new(0, 3.6, -1.55), stone, slate)
	b.box("Lips", Vector3.new(1.6, 0.45, 0.4), Vector3.new(0, 3.05, -1.3), RGB(105, 103, 100), slate)
	b.box("Chin", Vector3.new(2.2, 0.9, 0.5), Vector3.new(0, 2.5, -1.1), stone, slate)
	-- musgo y grietas para que la piedra parezca vieja
	b.box("Moss", Vector3.new(1.2, 0.2, 0.9), Vector3.new(-0.7, 7.5, 0.4), moss, Enum.Material.Grass)
	b.box("Moss", Vector3.new(0.7, 0.6, 0.15), Vector3.new(1.45, 1.3, -1.1), moss, Enum.Material.Grass)
	b.box("Crack", Vector3.new(0.08, 1.2, 0.05), Vector3.new(0.9, 6.4, -1.21), dark, slate, Vector3.new(0, 0, 20))
	b.box("Crack", Vector3.new(0.08, 0.8, 0.05), Vector3.new(-1.1, 3.8, -1.21), dark, slate, Vector3.new(0, 0, -15))
end

-- 💪 GigaChad: hombros enormes, mandíbula cuadrada, abdominales marcados. En blanco y negro.
builders.GigaChad = function(b)
	local skin, shade, hair = RGB(190, 190, 190), RGB(150, 150, 150), RGB(35, 35, 35)
	for _, x in ipairs({ -0.6, 0.6 }) do
		b.box("Shoe", Vector3.new(1.1, 0.4, 1.4), Vector3.new(x, 0.2, -0.1), RGB(20, 20, 20))
		b.box("Leg", Vector3.new(1.1, 2.1, 1.1), Vector3.new(x, 1.45, 0), RGB(40, 40, 45))
	end
	b.box("Waist", Vector3.new(2, 0.8, 1.2), Vector3.new(0, 2.85, 0), skin)
	-- torso en V: más ancho arriba
	b.box("Torso", Vector3.new(2.6, 1.3, 1.4), Vector3.new(0, 3.85, 0), skin)
	b.box("Chest", Vector3.new(3.4, 1.3, 1.6), Vector3.new(0, 4.95, 0), skin)
	for _, x in ipairs({ -0.75, 0.75 }) do
		b.box("Pec", Vector3.new(1.4, 0.9, 0.25), Vector3.new(x, 5.0, -0.85), shade)
	end
	for row = 0, 2 do
		for _, x in ipairs({ -0.35, 0.35 }) do
			b.box("Ab", Vector3.new(0.55, 0.38, 0.15), Vector3.new(x, 4.15 - row * 0.45, -0.72), shade)
		end
	end
	for _, x in ipairs({ -1, 1 }) do
		b.box("Shoulder", Vector3.new(1.3, 1.1, 1.4), Vector3.new(x * 2.15, 5.35, 0), skin)
		b.box("Bicep", Vector3.new(1.1, 1.3, 1.15), Vector3.new(x * 2.3, 4.3, 0), shade)
		b.box("Forearm", Vector3.new(0.95, 1.4, 1), Vector3.new(x * 2.35, 3.0, 0), skin)
		b.box("Fist", Vector3.new(0.9, 0.7, 0.9), Vector3.new(x * 2.35, 2.05, 0), shade)
	end
	b.box("Neck", Vector3.new(1.3, 0.6, 1.1), Vector3.new(0, 5.85, 0), skin)
	b.box("Head", Vector3.new(1.7, 1.7, 1.6), Vector3.new(0, 6.95, 0), skin)
	b.box("Jaw", Vector3.new(1.9, 0.7, 1.6), Vector3.new(0, 6.3, -0.05), skin)
	b.box("Stubble", Vector3.new(1.75, 0.5, 0.1), Vector3.new(0, 6.25, -0.86), RGB(120, 120, 120))
	b.box("Chin", Vector3.new(0.7, 0.25, 0.12), Vector3.new(0, 6.05, -0.9), shade)
	b.box("Hair", Vector3.new(1.85, 0.5, 1.7), Vector3.new(0, 7.95, 0.05), hair)
	b.box("HairSlick", Vector3.new(1.6, 0.4, 0.5), Vector3.new(0.1, 8.15, -0.6), hair, nil, Vector3.new(-15, 0, 0))
	for _, x in ipairs({ -0.38, 0.38 }) do
		b.box("Brow", Vector3.new(0.55, 0.15, 0.1), Vector3.new(x, 7.35, -0.82), hair)
		b.box("Eye", Vector3.new(0.35, 0.15, 0.08), Vector3.new(x, 7.12, -0.82), RGB(30, 30, 30))
	end
	b.box("Nose", Vector3.new(0.3, 0.5, 0.25), Vector3.new(0, 6.85, -0.9), shade)
	b.box("Mouth", Vector3.new(0.6, 0.1, 0.08), Vector3.new(0, 6.5, -0.88), RGB(80, 80, 80))
end

-- Pinta el modelo de oro manteniendo las zonas oscuras (ojos, detalles) para que no pierda la cara.
local function goldify(model: Model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon then
			local _, _, v = p.Color:ToHSV()
			if v > 0.25 then
				p.Color = Color3.fromRGB(255, 195, 50):Lerp(Color3.fromRGB(255, 240, 150), math.clamp(v - 0.5, 0, 0.5))
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0.25
			end
		end
	end
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 220, 90)
	local root = model.PrimaryPart
	if root then
		sparkle.Parent = root
	end
end

function MemeModels.Build(memeId: string, scale: number?, golden: boolean?): Model
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Meme_" .. memeId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local builder = builders[memeId] or builders.NoobFeliz
	builder(newBuilder(model, s))
	if golden then
		goldify(model)
	end
	return model
end

-- Altura aproximada (studs) para colocar etiquetas encima.
function MemeModels.Height(memeId: string, scale: number?): number
	local heights = { Stonks = 6.5, Sospechoso = 8.3, PatoInfinito = 7, GatoPianista = 6.8, Moai = 7.7, GigaChad = 8.4 }
	return (heights[memeId] or 6.3) * (scale or 1)
end

function MemeModels.Has(memeId: string): boolean
	return builders[memeId] ~= nil
end

return MemeModels
