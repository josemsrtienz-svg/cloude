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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Memes = require(ReplicatedStorage:WaitForChild("PescaDeMemes").Config.Memes)

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

-- ======================= MÍTICOS =======================

-- 😮 Gato Pop: gato atigrado sentado con la boca abierta en "O" (el ¡POP!). Cabeza grande, bigotes y cola enroscada.
builders.GatoPop = function(b)
	local fur, stripe, cream, pink = RGB(240, 160, 70), RGB(190, 105, 40), RGB(255, 235, 205), RGB(255, 150, 170)
	b.box("Body", Vector3.new(2.4, 2.2, 2.2), Vector3.new(0, 1.3, 0.2), fur, Enum.Material.Fabric)
	b.box("Chest", Vector3.new(1.6, 1.7, 0.3), Vector3.new(0, 1.45, -0.95), cream, Enum.Material.Fabric)
	-- collar con cascabel (identidad de gato doméstico)
	b.box("Collar", Vector3.new(2.2, 0.3, 2.0), Vector3.new(0, 2.45, -0.1), RGB(220, 40, 60), Enum.Material.Fabric)
	b.ball("Bell", 0.45, Vector3.new(0, 2.25, -1.15), RGB(255, 205, 40), Enum.Material.Metal)
	for _, x in ipairs({ -1, 1 }) do
		b.box("Haunch", Vector3.new(0.9, 1.2, 1.6), Vector3.new(x * 1.1, 0.7, 0.4), fur)
		b.box("Paw", Vector3.new(0.7, 0.5, 0.8), Vector3.new(x * 0.55, 0.25, -1.0), cream)
		b.box("Toe", Vector3.new(0.12, 0.12, 0.08), Vector3.new(x * 0.55, 0.3, -1.42), pink)
	end
	for k = 0, 2 do
		b.box("BackStripe", Vector3.new(2.42, 0.25, 1.2), Vector3.new(0, 1.0 + k * 0.6, 0.85), stripe)
	end
	-- cola enroscada hacia arriba
	b.box("Tail", Vector3.new(0.4, 1.6, 0.4), Vector3.new(1.0, 1.6, 1.3), fur, nil, Vector3.new(0, 0, -20))
	b.box("TailTip", Vector3.new(0.42, 0.6, 0.42), Vector3.new(1.35, 2.6, 1.3), stripe, nil, Vector3.new(0, 0, -35))
	b.box("TailStripe", Vector3.new(0.44, 0.2, 0.44), Vector3.new(1.12, 1.9, 1.3), stripe, nil, Vector3.new(0, 0, -20))
	for _, x in ipairs({ -0.55, 0.55 }) do
		b.box("PawPad", Vector3.new(0.35, 0.1, 0.25), Vector3.new(x, 0.02, -1.15), pink)
	end
	-- cabeza grande
	b.box("Head", Vector3.new(2.8, 2.4, 2.2), Vector3.new(0, 3.6, -0.2), fur, Enum.Material.Fabric)
	-- mofletes peludos que rompen el contorno cuadrado de la cabeza
	for _, x in ipairs({ -1, 1 }) do
		b.box("CheekTuft", Vector3.new(0.4, 0.8, 1.2), Vector3.new(x * 1.55, 3.0, -0.6), cream, Enum.Material.Fabric, Vector3.new(0, 0, x * 15))
		b.box("BackHeadStripe", Vector3.new(0.3, 0.9, 0.08), Vector3.new(x * 0.5, 4.0, 0.92), stripe)
	end
	for _, x in ipairs({ -0.5, 0, 0.5 }) do
		b.box("HeadStripe", Vector3.new(0.25, 0.6, 0.08), Vector3.new(x, 4.45, -1.32), stripe)
	end
	for _, x in ipairs({ -1, 1 }) do
		b.wedge("Ear", Vector3.new(0.7, 0.9, 0.5), Vector3.new(x * 0.95, 5.25, -0.1), fur)
		b.box("EarInner", Vector3.new(0.35, 0.45, 0.1), Vector3.new(x * 0.95, 5.15, -0.37), pink)
		b.box("Whisker", Vector3.new(1.0, 0.06, 0.06), Vector3.new(x * 1.35, 3.35, -1.25), RGB(250, 250, 250), nil, Vector3.new(0, 0, x * 10))
		b.box("Whisker", Vector3.new(1.0, 0.06, 0.06), Vector3.new(x * 1.35, 3.1, -1.25), RGB(250, 250, 250), nil, Vector3.new(0, 0, x * -8))
	end
	eye(b, Vector3.new(-0.62, 4.0, -1.31), 0.48)
	eye(b, Vector3.new(0.62, 4.0, -1.31), 0.48)
	b.box("Muzzle", Vector3.new(1.5, 1.1, 0.1), Vector3.new(0, 3.05, -1.3), cream)
	b.box("Nose", Vector3.new(0.3, 0.2, 0.1), Vector3.new(0, 3.62, -1.36), pink)
	-- la boca en O: el ¡POP!
	b.box("MouthO", Vector3.new(0.85, 0.95, 0.12), Vector3.new(0, 2.95, -1.36), RGB(70, 20, 35))
	b.box("Tongue", Vector3.new(0.55, 0.28, 0.14), Vector3.new(0, 2.62, -1.38), RGB(255, 110, 130))
end

-- 🍌 Plátano Bailarín: plátano curvo con guantes blancos y zapatillas, bailando con los brazos arriba.
builders.PlatanoBailarin = function(b)
	local yellow, ridge, brown = RGB(255, 220, 60), RGB(225, 180, 35), RGB(110, 75, 35)
	local segments = {
		{ Vector3.new(0.5, 1.3, 0), 20, 1.2 }, { Vector3.new(0.15, 2.5, 0), 10, 1.45 }, { Vector3.new(0, 3.75, 0), 0, 1.55 },
		{ Vector3.new(0.15, 5.0, 0), -10, 1.45 }, { Vector3.new(0.5, 6.2, 0), -20, 1.2 },
	}
	for _, seg in ipairs(segments) do
		local w = seg[3]
		b.box("Peel", Vector3.new(w, 1.4, w), seg[1], yellow, nil, Vector3.new(0, 0, seg[2]))
		b.box("Ridge", Vector3.new(0.12, 1.3, 0.1), seg[1] + Vector3.new(0, 0, -w / 2 - 0.02), ridge, nil, Vector3.new(0, 0, seg[2]))
		b.box("Spot", Vector3.new(0.2, 0.2, 0.06), seg[1] + Vector3.new(w * 0.3, 0.3, -w / 2 - 0.03), brown)
		-- manchas también por detrás y una costura lateral: la cáscara no es solo la cara de delante
		b.box("BackSpot", Vector3.new(0.3, 0.25, 0.06), seg[1] + Vector3.new(-w * 0.2, -0.2, w / 2 + 0.03), brown)
		b.box("SideRidge", Vector3.new(0.08, 1.3, 0.12), seg[1] + Vector3.new(w / 2 + 0.02, 0, 0), ridge, nil, Vector3.new(0, 0, seg[2]))
	end
	b.box("Stem", Vector3.new(0.45, 0.7, 0.45), Vector3.new(0.85, 7.1, 0), brown, nil, Vector3.new(0, 0, -30))
	b.box("StemTip", Vector3.new(0.5, 0.25, 0.5), Vector3.new(1.05, 7.45, 0), RGB(70, 50, 25), nil, Vector3.new(0, 0, -30))
	-- cara
	eye(b, Vector3.new(-0.32, 4.75, -0.8), 0.36)
	eye(b, Vector3.new(0.38, 4.75, -0.8), 0.36)
	b.box("Smile", Vector3.new(0.7, 0.15, 0.08), Vector3.new(0.05, 4.15, -0.8), RGB(60, 30, 20))
	b.box("SmileL", Vector3.new(0.14, 0.22, 0.08), Vector3.new(-0.33, 4.25, -0.8), RGB(60, 30, 20))
	b.box("SmileR", Vector3.new(0.14, 0.22, 0.08), Vector3.new(0.43, 4.25, -0.8), RGB(60, 30, 20))
	b.box("Blush", Vector3.new(0.25, 0.14, 0.06), Vector3.new(-0.62, 4.35, -0.79), RGB(255, 150, 120))
	b.box("Blush", Vector3.new(0.25, 0.14, 0.06), Vector3.new(0.7, 4.35, -0.79), RGB(255, 150, 120))
	-- brazos bailando con guantes blancos
	b.box("ArmL", Vector3.new(0.28, 1.4, 0.28), Vector3.new(-1.0, 4.6, 0), brown, nil, Vector3.new(0, 0, 30))
	b.box("GloveL", Vector3.new(0.55, 0.55, 0.55), Vector3.new(-1.4, 5.35, 0), RGB(250, 250, 250))
	b.box("CuffL", Vector3.new(0.6, 0.15, 0.6), Vector3.new(-1.27, 5.05, 0), RGB(230, 230, 235), nil, Vector3.new(0, 0, 30))
	b.box("BottomTip", Vector3.new(0.6, 0.35, 0.6), Vector3.new(0.85, 0.75, 0), RGB(70, 50, 25), nil, Vector3.new(0, 0, 30))
	b.box("ArmR", Vector3.new(0.28, 1.4, 0.28), Vector3.new(1.35, 4.3, 0), brown, nil, Vector3.new(0, 0, -55))
	b.box("GloveR", Vector3.new(0.55, 0.55, 0.55), Vector3.new(2.0, 4.75, 0), RGB(250, 250, 250))
	b.box("CuffR", Vector3.new(0.6, 0.15, 0.6), Vector3.new(1.78, 4.6, 0), RGB(230, 230, 235), nil, Vector3.new(0, 0, -55))
	-- piernas y zapatillas rojas
	for _, x in ipairs({ 0.1, 0.8 }) do
		b.box("Leg", Vector3.new(0.25, 0.7, 0.25), Vector3.new(x, 0.5, 0), brown)
		b.box("Shoe", Vector3.new(0.55, 0.3, 0.8), Vector3.new(x, 0.15, -0.12), RGB(230, 50, 60))
		b.box("ShoeToe", Vector3.new(0.56, 0.12, 0.25), Vector3.new(x, 0.08, -0.45), RGB(250, 250, 250))
	end
end

-- 🐹 Hámster Dramático: hámster gordito girando la cabeza con mirada intensa (cejas, ojos de lado, mofletes).
builders.HamsterDramatico = function(b)
	local tan, white, pink = RGB(220, 160, 95), RGB(250, 240, 225), RGB(255, 165, 175)
	b.box("Body", Vector3.new(2.6, 2.4, 2.8), Vector3.new(0, 1.4, 0.2), tan, Enum.Material.Fabric)
	b.box("BellyLine", Vector3.new(0.1, 1.2, 0.05), Vector3.new(0, 1.3, -1.36), RGB(235, 220, 200))
	b.box("Belly", Vector3.new(1.8, 1.7, 0.2), Vector3.new(0, 1.35, -1.25), white)
	b.box("BackPatch", Vector3.new(1.6, 0.9, 1.6), Vector3.new(0, 2.5, 0.6), RGB(190, 130, 75))
	for _, x in ipairs({ -1, 1 }) do
		b.box("Foot", Vector3.new(0.6, 0.3, 0.8), Vector3.new(x * 0.7, 0.15, -0.8), pink)
		b.box("Hand", Vector3.new(0.45, 0.35, 0.45), Vector3.new(x * 0.5, 2.15, -1.45), pink)
		b.box("Ear", Vector3.new(0.6, 0.6, 0.3), Vector3.new(x * 0.9, 4.45, -0.15), tan)
		b.box("EarInner", Vector3.new(0.3, 0.32, 0.1), Vector3.new(x * 0.9, 4.42, -0.32), pink)
		b.box("Cheek", Vector3.new(0.85, 0.85, 0.85), Vector3.new(x * 1.05, 2.95, -0.95), white)
		-- cejas dramáticas, muy inclinadas
		b.box("Brow", Vector3.new(0.5, 0.12, 0.08), Vector3.new(x * 0.55, 4.0, -1.33), RGB(110, 70, 40), nil, Vector3.new(0, 0, x * 22))
	end
	b.box("Head", Vector3.new(2.4, 2.1, 2.0), Vector3.new(0, 3.3, -0.3), tan, Enum.Material.Fabric)
	-- mechón despeinado y bigotes
	b.box("Tuft", Vector3.new(0.3, 0.5, 0.3), Vector3.new(-0.15, 4.5, -0.6), tan, Enum.Material.Fabric, Vector3.new(0, 0, 20))
	b.box("Tuft", Vector3.new(0.3, 0.4, 0.3), Vector3.new(0.2, 4.45, -0.5), RGB(190, 130, 75), Enum.Material.Fabric, Vector3.new(0, 0, -25))
	for _, x in ipairs({ -1, 1 }) do
		b.box("Whisker", Vector3.new(0.8, 0.05, 0.05), Vector3.new(x * 0.75, 3.05, -1.5), RGB(90, 70, 50), nil, Vector3.new(0, 0, x * 12))
	end
	b.box("Face", Vector3.new(1.4, 0.9, 0.1), Vector3.new(0, 2.95, -1.31), white)
	b.box("Snout", Vector3.new(0.8, 0.5, 0.35), Vector3.new(0, 3.0, -1.45), white)
	b.box("Nose", Vector3.new(0.26, 0.18, 0.1), Vector3.new(0, 3.2, -1.65), pink)
	b.box("Teeth", Vector3.new(0.3, 0.22, 0.08), Vector3.new(0, 2.65, -1.62), RGB(255, 255, 250))
	-- mirada de reojo
	eye(b, Vector3.new(-0.55, 3.55, -1.31), 0.55, 1)
	eye(b, Vector3.new(0.55, 3.55, -1.31), 0.55, 1)
	b.box("Tail", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 0.9, 1.65), tan)
end

-- ======================= SECRETOS =======================

-- 🦈 Tiburón Zapatillero: tiburón tumbado sobre dos piernas con zapatillas de deporte enormes.
builders.TiburonZapatillero = function(b)
	local skin, belly, dark = RGB(90, 135, 180), RGB(240, 245, 250), RGB(55, 90, 125)
	b.box("Body", Vector3.new(2.2, 2.2, 4.6), Vector3.new(0, 3.3, 0.2), skin)
	b.box("Belly", Vector3.new(1.8, 0.7, 4.0), Vector3.new(0, 2.35, -0.1), belly)
	for k = 0, 3 do
		b.box("BellyGroove", Vector3.new(1.82, 0.06, 0.08), Vector3.new(0, 2.25, -1.4 + k * 0.8), RGB(205, 215, 225))
		b.box("BackSpot", Vector3.new(0.35, 0.08, 0.35), Vector3.new((k % 2 - 0.5) * 0.9, 4.42, -1 + k * 0.8), dark)
	end
	b.box("Scar", Vector3.new(0.6, 0.08, 0.06), Vector3.new(0.5, 4.0, -3.31), RGB(220, 230, 240), nil, Vector3.new(0, 0, 35))
	b.box("Head", Vector3.new(1.9, 1.8, 1.4), Vector3.new(0, 3.25, -2.6), skin)
	b.wedge("Snout", Vector3.new(1.8, 1.0, 0.9), Vector3.new(0, 3.65, -3.65), skin)
	b.box("Jaw", Vector3.new(1.7, 0.5, 1.3), Vector3.new(0, 2.55, -2.9), belly)
	b.box("Mouth", Vector3.new(1.4, 0.25, 0.1), Vector3.new(0, 2.85, -3.56), RGB(120, 30, 40))
	for k = -2, 2 do
		b.wedge("Tooth", Vector3.new(0.18, 0.2, 0.1), Vector3.new(k * 0.28, 2.95, -3.58), RGB(255, 255, 255), Vector3.new(0, 0, 180))
	end
	eye(b, Vector3.new(-0.55, 3.75, -3.31), 0.36, -1)
	eye(b, Vector3.new(0.55, 3.75, -3.31), 0.36, 1)
	for _, x in ipairs({ -1, 1 }) do
		b.box("Gill", Vector3.new(0.05, 0.6, 0.08), Vector3.new(x * 1.11, 3.3, -1.6), dark)
		b.box("Gill", Vector3.new(0.05, 0.6, 0.08), Vector3.new(x * 1.11, 3.3, -1.35), dark)
		b.box("Fin", Vector3.new(1.4, 0.2, 1.0), Vector3.new(x * 1.5, 2.8, -0.8), dark, nil, Vector3.new(0, 0, x * -25))
	end
	b.wedge("Dorsal", Vector3.new(0.35, 1.6, 1.6), Vector3.new(0, 5.15, 0.4), dark)
	b.box("TailBase", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 3.4, 2.9), skin)
	b.wedge("TailTop", Vector3.new(0.35, 1.6, 1.0), Vector3.new(0, 4.6, 3.6), dark, Vector3.new(0, 180, 0))
	b.wedge("TailBottom", Vector3.new(0.35, 1.0, 0.8), Vector3.new(0, 2.5, 3.6), dark, Vector3.new(180, 0, 0))
	-- piernas y zapatillas de deporte (la firma del personaje)
	for _, x in ipairs({ -0.65, 0.65 }) do
		b.box("Leg", Vector3.new(0.6, 1.5, 0.6), Vector3.new(x, 1.2, -0.3), skin)
		b.box("Sock", Vector3.new(0.65, 0.35, 0.65), Vector3.new(x, 0.65, -0.3), RGB(250, 250, 250))
		b.box("Shoe", Vector3.new(0.95, 0.55, 1.7), Vector3.new(x, 0.32, -0.55), RGB(250, 250, 250))
		b.box("Sole", Vector3.new(1.0, 0.16, 1.75), Vector3.new(x, 0.06, -0.55), RGB(70, 70, 80))
		b.box("Swoosh", Vector3.new(0.97, 0.14, 0.9), Vector3.new(x, 0.38, -0.5), RGB(40, 140, 255), nil, Vector3.new(15, 0, 0))
		b.box("Lace", Vector3.new(0.5, 0.06, 0.06), Vector3.new(x, 0.62, -0.9), RGB(40, 40, 50))
		b.box("Lace", Vector3.new(0.5, 0.06, 0.06), Vector3.new(x, 0.62, -0.65), RGB(40, 40, 50))
		b.box("Tongue", Vector3.new(0.55, 0.35, 0.3), Vector3.new(x, 0.75, -0.25), RGB(40, 140, 255))
		b.box("HeelTab", Vector3.new(0.4, 0.3, 0.12), Vector3.new(x, 0.6, 0.32), RGB(40, 140, 255))
	end
end

-- 🐋 Ballena Sigma (DIOS · Jefe del río): ballena enorme y chulísima. Silueta larga con cabeza cuadrada
-- (mandíbula marcada), gafas de sol con montura dorada, una ceja arqueada, cadena de oro con colgante Σ,
-- pliegues en la tripa, percebes repartidos, aletas, cola en dos lóbulos, espiráculo con chorro y halo dorado.
builders.BallenaSigma = function(b)
	local skin, dark, belly = RGB(45, 90, 165), RGB(30, 60, 120), RGB(215, 230, 245)
	local gold = RGB(255, 200, 50)
	-- cuerpo en tres bloques que se estrechan hacia la cola (silueta de ballena, no un ladrillo)
	b.box("Body", Vector3.new(3.4, 3.0, 4.2), Vector3.new(0, 2.2, 0.4), skin)
	b.box("BodyBack", Vector3.new(2.8, 2.4, 2.2), Vector3.new(0, 2.25, 3.4), skin)
	b.box("TailStock", Vector3.new(1.6, 1.5, 1.8), Vector3.new(0, 2.5, 5.2), dark)
	b.box("Back", Vector3.new(3.0, 0.3, 5.6), Vector3.new(0, 3.82, 1.4), dark)
	-- cabeza cuadrada con mandíbula de sigma
	b.box("Head", Vector3.new(3.6, 2.6, 2.4), Vector3.new(0, 2.5, -2.8), skin)
	b.box("Jaw", Vector3.new(3.7, 0.9, 2.5), Vector3.new(0, 1.05, -2.85), belly)
	b.box("JawEdgeL", Vector3.new(0.2, 1.0, 2.5), Vector3.new(-1.86, 1.1, -2.85), dark)
	b.box("JawEdgeR", Vector3.new(0.2, 1.0, 2.5), Vector3.new(1.86, 1.1, -2.85), dark)
	b.box("Chin", Vector3.new(2.6, 0.5, 0.3), Vector3.new(0, 0.85, -4.12), belly)
	b.box("Smirk", Vector3.new(1.6, 0.14, 0.1), Vector3.new(0.35, 1.55, -4.03), RGB(25, 30, 50), nil, Vector3.new(0, 0, -8))
	-- tripa con pliegues (las rayas típicas de las ballenas)
	b.box("Belly", Vector3.new(2.9, 0.5, 5.6), Vector3.new(0, 0.75, 0.6), belly)
	for k = 0, 6 do
		b.box("Pleat", Vector3.new(2.92, 0.06, 0.09), Vector3.new(0, 0.62, -1.6 + k * 0.8), RGB(170, 190, 215))
	end
	-- gafas de sol: dos cristales negros con montura dorada y puente
	for _, x in ipairs({ -0.85, 0.85 }) do
		b.box("Lens", Vector3.new(1.2, 0.7, 0.12), Vector3.new(x, 2.95, -4.03), RGB(15, 15, 20), Enum.Material.Glass)
		b.box("LensShine", Vector3.new(0.3, 0.12, 0.13), Vector3.new(x - 0.3, 3.15, -4.05), RGB(200, 220, 255))
		b.box("Frame", Vector3.new(1.3, 0.12, 0.14), Vector3.new(x, 3.33, -4.03), gold, Enum.Material.Metal)
		b.box("Temple", Vector3.new(0.1, 0.1, 1.2), Vector3.new(x * 2.12, 3.2, -3.4), gold, Enum.Material.Metal)
	end
	b.box("Bridge", Vector3.new(0.5, 0.1, 0.14), Vector3.new(0, 3.1, -4.03), gold, Enum.Material.Metal)
	b.box("Brow", Vector3.new(1.1, 0.16, 0.14), Vector3.new(0.85, 3.7, -4.0), dark, nil, Vector3.new(0, 0, 14)) -- ceja arqueada
	b.box("Brow", Vector3.new(1.1, 0.16, 0.14), Vector3.new(-0.85, 3.55, -4.0), dark)
	-- cadena de oro con colgante Σ
	for k = -3, 3 do
		b.box("Chain", Vector3.new(0.3, 0.12, 0.12), Vector3.new(k * 0.45, 1.78 - math.abs(k) * 0.06, -4.08), gold, Enum.Material.Metal)
	end
	b.box("Pendant", Vector3.new(0.6, 0.7, 0.12), Vector3.new(0, 1.35, -4.12), gold, Enum.Material.Metal)
	b.box("SigmaTop", Vector3.new(0.4, 0.08, 0.14), Vector3.new(0, 1.6, -4.15), RGB(30, 30, 40))
	b.box("SigmaMid", Vector3.new(0.3, 0.08, 0.14), Vector3.new(0, 1.35, -4.15), RGB(30, 30, 40), nil, Vector3.new(0, 0, 45))
	b.box("SigmaBottom", Vector3.new(0.4, 0.08, 0.14), Vector3.new(0, 1.1, -4.15), RGB(30, 30, 40))
	-- aletas pectorales y cola en dos lóbulos
	for _, x in ipairs({ -1, 1 }) do
		b.box("Flipper", Vector3.new(1.8, 0.25, 1.0), Vector3.new(x * 2.3, 1.2, -1.0), dark, nil, Vector3.new(0, x * 20, x * -20))
		b.wedge("Fluke", Vector3.new(0.3, 1.0, 1.8), Vector3.new(x * 1.2, 2.6, 6.6), dark, Vector3.new(0, 0, x * 90))
	end
	b.box("FlukeCenter", Vector3.new(0.6, 0.3, 0.8), Vector3.new(0, 2.6, 6.3), dark)
	-- percebes repartidos por TODO el cuerpo (lomo, lados y cola), con tamaños distintos
	local spots = { Vector3.new(-1.2, 3.4, 0.2), Vector3.new(1.0, 3.5, 1.6), Vector3.new(-0.6, 3.6, 2.9), Vector3.new(1.71, 2.6, -0.4),
		Vector3.new(-1.71, 2.2, 1.9), Vector3.new(1.41, 2.9, 3.6), Vector3.new(-0.81, 2.9, 5.0), Vector3.new(0.5, 3.75, -2.2) }
	for i, p in ipairs(spots) do
		b.box("Barnacle", Vector3.one * (0.22 + (i % 3) * 0.07), p, RGB(200, 200, 190), Enum.Material.Slate)
	end
	-- espiráculo y chorro (piezas; las partículas las pone el efecto de rareza)
	b.box("Blowhole", Vector3.new(0.5, 0.1, 0.3), Vector3.new(0, 4.0, -1.6), RGB(20, 40, 80))
	b.box("Spout", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 4.7, -1.6), RGB(170, 220, 255), Enum.Material.Glass)
	b.ball("SpoutTop", 0.9, Vector3.new(0, 5.4, -1.6), RGB(200, 235, 255), Enum.Material.Glass)
	-- halo de DIOS: 10 segmentos dorados en anillo
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		b.box("Halo", Vector3.new(0.4, 0.14, 0.2), Vector3.new(math.cos(a) * 1.1, 6.3, -1.6 + math.sin(a) * 1.1), gold, Enum.Material.Neon,
			Vector3.new(0, -math.deg(a), 0))
	end
end

-- 🍊 Capibara Zen: capibara sentada meditando con una naranja en la cabeza y los ojos cerrados.
builders.CapibaraZen = function(b)
	local fur, dark, light = RGB(150, 100, 60), RGB(105, 70, 40), RGB(180, 130, 85)
	b.box("Body", Vector3.new(2.6, 2.0, 3.2), Vector3.new(0, 1.3, 0.3), fur, Enum.Material.Fabric)
	-- pelo más oscuro por el lomo (variación de color en toda la superficie, no solo delante)
	b.box("BackFur", Vector3.new(1.8, 0.2, 2.6), Vector3.new(0, 2.38, 0.5), dark, Enum.Material.Fabric)
	b.box("SideFur", Vector3.new(0.08, 0.8, 1.6), Vector3.new(1.32, 1.5, 0.6), dark, Enum.Material.Fabric)
	b.box("SideFur", Vector3.new(0.08, 0.8, 1.6), Vector3.new(-1.32, 1.5, 0.6), dark, Enum.Material.Fabric)
	-- nenúfar zen bajo la capibara
	b.box("LilyPad", Vector3.new(4.2, 0.15, 4.6), Vector3.new(0, 0.05, 0.1), RGB(70, 160, 70))
	b.box("LilyNotch", Vector3.new(0.6, 0.17, 1.2), Vector3.new(1.5, 0.06, -1.9), RGB(50, 130, 55), nil, Vector3.new(0, 30, 0))
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		b.box("Petal", Vector3.new(0.5, 0.25, 0.8), Vector3.new(-1.6 + math.cos(a) * 0.35, 0.25, -1.7 + math.sin(a) * 0.35), RGB(255, 150, 200), nil, Vector3.new(0, math.deg(a), 20))
	end
	b.box("Rump", Vector3.new(2.4, 1.6, 1.0), Vector3.new(0, 1.1, 1.8), fur)
	b.box("Chest", Vector3.new(1.9, 1.4, 0.4), Vector3.new(0, 1.5, -1.3), light)
	for _, x in ipairs({ -0.75, 0.75 }) do
		b.box("FrontLeg", Vector3.new(0.5, 0.8, 0.5), Vector3.new(x, 0.4, -1.1), dark)
		b.box("BackLeg", Vector3.new(0.7, 0.6, 1.0), Vector3.new(x * 1.3, 0.3, 1.4), dark)
	end
	b.box("Head", Vector3.new(1.8, 1.6, 2.0), Vector3.new(0, 2.7, -1.5), fur, Enum.Material.Fabric)
	b.box("Snout", Vector3.new(1.6, 1.1, 0.9), Vector3.new(0, 2.4, -2.8), light)
	b.box("NoseTop", Vector3.new(1.0, 0.15, 0.1), Vector3.new(0, 2.85, -3.26), dark)
	for _, x in ipairs({ -1, 1 }) do
		b.box("Nostril", Vector3.new(0.15, 0.12, 0.08), Vector3.new(x * 0.3, 2.65, -3.27), RGB(50, 30, 20))
		-- ojos cerrados (meditando)
		b.box("ClosedEye", Vector3.new(0.4, 0.08, 0.08), Vector3.new(x * 0.6, 3.05, -2.52), RGB(40, 25, 15), nil, Vector3.new(0, 0, x * -8))
		b.box("Ear", Vector3.new(0.35, 0.3, 0.25), Vector3.new(x * 0.65, 3.6, -1.1), dark)
	end
	b.box("Mouth", Vector3.new(0.5, 0.06, 0.06), Vector3.new(0, 2.05, -3.26), RGB(60, 40, 25))
	-- la naranja con su hoja
	b.ball("Orange", 1.0, Vector3.new(0, 4.0, -1.5), RGB(255, 145, 30))
	b.box("OrangeStem", Vector3.new(0.12, 0.25, 0.12), Vector3.new(0, 4.55, -1.5), RGB(90, 60, 30))
	b.box("Leaf", Vector3.new(0.5, 0.08, 0.3), Vector3.new(0.25, 4.6, -1.5), RGB(60, 160, 60), nil, Vector3.new(0, 0, 20))
end

-- 🐊 Cocodrilo Aviador: cocodrilo con alas de avioneta, gafas de piloto, bufanda y hélice en el morro.
builders.CocodriloAviador = function(b)
	local green, belly, metal, red = RGB(80, 140, 70), RGB(200, 210, 150), RGB(170, 175, 185), RGB(210, 50, 50)
	b.box("Body", Vector3.new(2.2, 1.5, 4.2), Vector3.new(0, 2.3, 0.4), green, Enum.Material.Slate)
	b.box("Belly", Vector3.new(1.8, 0.4, 3.8), Vector3.new(0, 1.45, 0.4), belly)
	for k = 0, 3 do
		b.box("Scute", Vector3.new(0.5, 0.25, 0.5), Vector3.new(0, 3.15, -0.8 + k * 0.9), RGB(60, 110, 55))
	end
	b.box("Head", Vector3.new(1.6, 1.1, 1.4), Vector3.new(0, 2.5, -2.3), green)
	b.box("Snout", Vector3.new(1.3, 0.6, 1.8), Vector3.new(0, 2.25, -3.8), green)
	b.box("Jaw", Vector3.new(1.25, 0.35, 1.7), Vector3.new(0, 1.8, -3.7), belly)
	for _, x in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			b.wedge("Tooth", Vector3.new(0.1, 0.2, 0.15), Vector3.new(x * 0.6, 2.0, -3.0 - k * 0.4), RGB(255, 255, 245), Vector3.new(0, 0, 180))
		end
		-- ojos saltones con gafas de aviador
		b.box("EyeBump", Vector3.new(0.5, 0.45, 0.5), Vector3.new(x * 0.45, 3.2, -2.2), green)
		b.box("GoggleLens", Vector3.new(0.45, 0.4, 0.1), Vector3.new(x * 0.45, 3.25, -2.5), RGB(120, 200, 255), Enum.Material.Glass)
		b.box("GoggleRim", Vector3.new(0.55, 0.5, 0.08), Vector3.new(x * 0.45, 3.25, -2.47), RGB(120, 80, 40))
		-- alas de avioneta con franja roja y motor
		b.box("Wing", Vector3.new(2.6, 0.22, 1.5), Vector3.new(x * 2.4, 2.5, 0), metal, Enum.Material.Metal)
		b.box("WingStripe", Vector3.new(0.4, 0.24, 1.52), Vector3.new(x * 3.2, 2.5, 0), red)
		b.box("Engine", Vector3.new(0.5, 0.5, 0.9), Vector3.new(x * 1.9, 2.15, -0.5), RGB(80, 80, 90), Enum.Material.Metal)
		b.box("Exhaust", Vector3.new(0.2, 0.2, 0.4), Vector3.new(x * 1.9, 2.0, 0.1), RGB(50, 50, 55), Enum.Material.Metal)
		for k = 0, 2 do
			b.box("Rivet", Vector3.new(0.12, 0.05, 0.12), Vector3.new(x * (1.5 + k * 0.8), 2.63, 0.55), RGB(120, 125, 135), Enum.Material.Metal)
		end
		b.box("Leg", Vector3.new(0.5, 1.0, 0.6), Vector3.new(x * 0.75, 0.6, -1.0), green)
		b.box("Leg", Vector3.new(0.5, 1.0, 0.6), Vector3.new(x * 0.75, 0.6, 1.6), green)
		b.box("Claw", Vector3.new(0.6, 0.15, 0.4), Vector3.new(x * 0.75, 0.08, -1.25), RGB(240, 235, 210))
	end
	b.box("Strap", Vector3.new(1.65, 0.15, 0.3), Vector3.new(0, 3.25, -2.1), RGB(120, 80, 40))
	b.box("Scarf", Vector3.new(1.7, 0.35, 1.5), Vector3.new(0, 2.6, -1.4), red)
	b.box("ScarfTail", Vector3.new(0.35, 0.8, 0.12), Vector3.new(0.6, 2.4, -0.55), red, nil, Vector3.new(-35, 0, 15))
	-- cola con timón de avión
	b.box("Tail", Vector3.new(1.2, 0.9, 1.8), Vector3.new(0, 2.25, 3.3), green, Enum.Material.Slate)
	for k = 0, 2 do
		b.box("TailScute", Vector3.new(0.35, 0.25, 0.35), Vector3.new(0, 2.8, 2.7 + k * 0.5), RGB(60, 110, 55))
	end
	b.box("Rudder", Vector3.new(0.2, 1.3, 0.9), Vector3.new(0, 3.2, 3.9), red)
	b.box("Stabilizer", Vector3.new(2.2, 0.15, 0.7), Vector3.new(0, 2.55, 3.9), metal, Enum.Material.Metal)
	-- hélice en el morro
	b.box("PropHub", Vector3.new(0.4, 0.4, 0.3), Vector3.new(0, 2.25, -4.85), RGB(60, 60, 70), Enum.Material.Metal)
	b.box("PropBlade", Vector3.new(0.22, 2.2, 0.08), Vector3.new(0, 2.25, -5.02), RGB(110, 75, 40), Enum.Material.Wood, Vector3.new(0, 0, 20))
	b.box("PropBlade", Vector3.new(2.2, 0.22, 0.08), Vector3.new(0, 2.25, -5.02), RGB(110, 75, 40), Enum.Material.Wood, Vector3.new(0, 0, 20))
end

-- ======================= Efectos por rareza =======================
-- Míticos: chispas de su color + luz. Secretos: aura arcoíris, luz fuerte y un efecto propio de cada uno.
-- El tamaño de las partículas sigue la escala del modelo.

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, RGB(255, 80, 80)), ColorSequenceKeypoint.new(0.2, RGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, RGB(90, 230, 110)), ColorSequenceKeypoint.new(0.6, RGB(70, 200, 255)),
	ColorSequenceKeypoint.new(0.8, RGB(170, 90, 255)), ColorSequenceKeypoint.new(1, RGB(255, 90, 200)),
})

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LockedToPart = false
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local SPECIAL_FX: { [string]: (Attachment, number) -> () } = {
	-- burbujas azules (estela de nado)
	TiburonZapatillero = function(att, s)
		emitter(att, { Name = "Bubbles", Rate = 8, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1, 3),
			Size = NumberSequence.new(0.35 * s), Color = ColorSequence.new(RGB(150, 220, 255)), Transparency = NumberSequence.new(0.3),
			SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top })
	end,
	-- anillos dorados que suben (meditación)
	CapibaraZen = function(att, s)
		emitter(att, { Name = "ZenRings", Rate = 2, Lifetime = NumberRange.new(2, 2.5), Speed = NumberRange.new(1.5, 2),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * s), NumberSequenceKeypoint.new(1, 3 * s) }),
			Color = ColorSequence.new(RGB(255, 210, 90)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(0, 0) })
	end,
	-- humo de motor
	CocodriloAviador = function(att, s)
		emitter(att, { Name = "Smoke", Rate = 6, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1, 2),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 2 * s) }),
			Color = ColorSequence.new(RGB(170, 170, 175)), LightEmission = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
			EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(20, 20) })
	end,
}

local function addRarityFx(model: Model, memeId: string, s: number)
	local meme = Memes.Get(memeId)
	local rarity = meme and Memes.Rarities[meme.Rarity]
	local root = model.PrimaryPart
	if not rarity or not root or rarity.Order < 5 then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "FX"
	att.Position = Vector3.new(0, MemeModels.Height(memeId, s) * 0.5, 0)
	att.Parent = root
	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 10 * s
	light.Brightness = if rarity.Order >= 7 then 2 else 1.2
	light.Parent = root
	emitter(att, { Name = "Sparkles", Rate = if rarity.Order >= 7 then 14 else 7, Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.3 * s),
		Color = if rarity.Order >= 7 then RAINBOW else ColorSequence.new(rarity.Color),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
	if rarity.Order >= 7 then
		-- aura arcoíris en el suelo
		emitter(att, { Name = "Aura", Rate = 4, Lifetime = NumberRange.new(1.5, 2), Speed = NumberRange.new(0, 0.3),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * s), NumberSequenceKeypoint.new(1, 4 * s) }),
			Color = RAINBOW, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }) })
		local special = SPECIAL_FX[memeId]
		if special then
			special(att, s)
		end
	end
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

-- MUTACIONES (clima, Config/Weather): se ven en el propio meme, no solo en el nombre.
-- (particles = false en iconos y miniaturas: solo la geometría y el brillo, sin partículas ni luces)
--   Wet      gotas azules que caen + brillo húmedo en la superficie
--   Electric chispas amarillas rápidas + luz parpadeante + dos rayos de neón en la cabeza
--   Lunar    destellos morados lentos + luz violeta + una luna creciente flotando encima
local function addMutationFx(model: Model, memeId: string, s: number, mutation: string, particles: boolean)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local h = MemeModels.Height(memeId, s)
	local att = Instance.new("Attachment")
	att.Name = "MutationFX"
	att.Position = Vector3.new(0, h * 0.55, 0)
	att.Parent = root
	if mutation == "Wet" then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.5 then
				d.Reflectance = math.max(d.Reflectance, 0.12)
			end
		end
		if not particles then
			return
		end
		emitter(att, { Name = "Drips", Rate = 10, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.5, 1.5),
			Acceleration = Vector3.new(0, -14 * s, 0), SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new(0.14 * s),
			Color = ColorSequence.new(Color3.fromRGB(110, 200, 255)), Transparency = NumberSequence.new(0.2) })
	elseif mutation == "Electric" then
		if particles then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 235, 90)
			light.Range = 9 * s
			light.Brightness = 1.6
			light.Parent = root
			emitter(att, { Name = "Sparks", Rate = 16, Lifetime = NumberRange.new(0.15, 0.35), Speed = NumberRange.new(4 * s, 8 * s),
				SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.12 * s),
				Color = ColorSequence.new(Color3.fromRGB(255, 250, 150), Color3.fromRGB(255, 200, 40)) })
		end
		for _, side in ipairs({ -1, 1 }) do
			local bolt = Instance.new("Part")
			bolt.Name = "Bolt"
			bolt.Size = Vector3.new(0.18, 0.9, 0.18) * s
			bolt.Color = Color3.fromRGB(255, 235, 60)
			bolt.Material = Enum.Material.Neon
			bolt.Anchored, bolt.CanCollide, bolt.CanQuery, bolt.CanTouch, bolt.Massless, bolt.CastShadow = true, false, false, false, true, false
			bolt.CFrame = root.CFrame * CFrame.new(side * 0.6 * s, h * 0.95, 0) * CFrame.Angles(0, 0, side * 0.5)
			bolt.Parent = model
		end
	elseif mutation == "Lunar" then
		if particles then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(190, 130, 255)
			light.Range = 11 * s
			light.Brightness = 1.8
			light.Parent = root
			emitter(att, { Name = "MoonDust", Rate = 8, Lifetime = NumberRange.new(1.4, 2.2), Speed = NumberRange.new(0.3, 0.8),
				SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * s), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(Color3.fromRGB(210, 170, 255), Color3.fromRGB(140, 90, 255)) })
		end
		local moonCf = root.CFrame * CFrame.new(0, h + 1.2 * s, 0)
		for k, props in ipairs({ { 0.9, Color3.fromRGB(230, 210, 255), Enum.Material.Neon, Vector3.zero },
			{ 0.8, Color3.fromRGB(35, 25, 70), Enum.Material.SmoothPlastic, Vector3.new(0.28, 0.1, 0.12) } }) do
			local p = Instance.new("Part")
			p.Name = if k == 1 then "Moon" else "MoonShadow"
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.one * props[1] * s
			p.Color = props[2]
			p.Material = props[3]
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = true, false, false, false, true, false
			p.CFrame = moonCf * CFrame.new(props[4] * s)
			p.Parent = model
		end
	end
end

-- fx = false para iconos y miniaturas (las partículas no se ven en un ViewportFrame y en miniatura molestan)
function MemeModels.Build(memeId: string, scale: number?, golden: boolean?, fx: boolean?, mutation: string?): Model
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
	if fx ~= false then
		addRarityFx(model, memeId, s)
	end
	if mutation then
		addMutationFx(model, memeId, s, mutation, fx ~= false)
	end
	-- rendimiento: los detalles pequeños (ojos, botones, pelo…) no proyectan sombra
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Size.Magnitude < 1.5 then
			d.CastShadow = false
		end
	end
	return model
end

-- Altura aproximada (studs) para colocar etiquetas encima.
function MemeModels.Height(memeId: string, scale: number?): number
	local heights = { Stonks = 6.5, Sospechoso = 8.3, PatoInfinito = 7, GatoPianista = 6.8, Moai = 7.7, GigaChad = 8.4,
		GatoPop = 5.7, PlatanoBailarin = 7.6, HamsterDramatico = 4.8, TiburonZapatillero = 6, CapibaraZen = 4.7, CocodriloAviador = 4.2, BallenaSigma = 6.5 }
	return (heights[memeId] or 6.3) * (scale or 1)
end

function MemeModels.Has(memeId: string): boolean
	return builders[memeId] ~= nil
end

return MemeModels
