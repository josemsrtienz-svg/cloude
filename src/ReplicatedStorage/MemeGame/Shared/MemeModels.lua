--[[
	MemeGame • MemeModels (ModuleScript)
	ReplicatedStorage > MemeGame > Shared > MemeModels

	Modelos 3D de los memes hechos con Parts (sin assets externos). Se usan en las estatuas del lobby.
	¿Tienes tu propio modelo (Toolbox, Blender...)? Crea ReplicatedStorage > MemeModels y mete un
	Model con el mismo Id del meme (ej. "GigaChad"). Se usa en lugar del procedural.
	Los modelos miran hacia -Z.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemeModels = {}

local RGB = Color3.fromRGB
local SLATE = Enum.Material.Slate
local NEON = Enum.Material.Neon

local function at(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function add(model: Model, className: string, props: { [string]: any }): BasePart
	local part = Instance.new(className) :: any
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = model
	return part
end

local function vcyl(model, name, height, diameter, x, y, z, color, extra)
	local props = {
		Name = name, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter), CFrame = at(x, y, z, 0, 0, 90), Color = color,
	}
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return add(model, "Part", props)
end

local function humanoidBody(m, skin, shirt, pants)
	add(m, "Part", { Name = "LeftLeg", Size = Vector3.new(1, 2, 1), CFrame = at(-0.5, 1, 0), Color = pants })
	add(m, "Part", { Name = "RightLeg", Size = Vector3.new(1, 2, 1), CFrame = at(0.5, 1, 0), Color = pants })
	add(m, "Part", { Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = at(0, 3, 0), Color = shirt })
	add(m, "Part", { Name = "LeftArm", Size = Vector3.new(1, 2, 1), CFrame = at(-1.5, 3, 0), Color = skin })
	add(m, "Part", { Name = "RightArm", Size = Vector3.new(1, 2, 1), CFrame = at(1.5, 3, 0), Color = skin })
	local head = add(m, "Part", { Name = "Head", Size = Vector3.new(2, 1, 1), CFrame = at(0, 4.5, 0), Color = skin })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	return head
end

local function face(head: BasePart, texture: string)
	local d = Instance.new("Decal")
	d.Texture = texture
	d.Face = Enum.NormalId.Front
	d.Parent = head
end

local Builders: { [string]: (Model) -> () } = {}

Builders.NoobFeliz = function(m)
	local head = humanoidBody(m, RGB(245, 205, 48), RGB(13, 105, 172), RGB(40, 127, 71))
	face(head, "rbxasset://textures/face.png")
end

Builders.Sospechoso = function(m)
	local red, dark = RGB(215, 35, 45), RGB(120, 15, 25)
	vcyl(m, "Body", 2, 2.2, 0, 2.2, 0, red)
	add(m, "Part", { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = at(0, 3.2, 0), Color = red })
	add(m, "Part", { Name = "LeftLeg", Size = Vector3.new(0.9, 1.1, 1.6), CFrame = at(-0.55, 0.65, 0), Color = dark })
	add(m, "Part", { Name = "RightLeg", Size = Vector3.new(0.9, 1.1, 1.6), CFrame = at(0.55, 0.65, 0), Color = dark })
	add(m, "Part", { Name = "Backpack", Size = Vector3.new(1.5, 1.6, 0.8), CFrame = at(0, 2.4, 1.25), Color = dark })
	add(m, "Part", { Name = "Visor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.85, 0.85),
		CFrame = at(0, 3.0, -0.95), Color = RGB(150, 215, 235), Reflectance = 0.2 })
end

Builders.PerroBonk = function(m)
	local fur, white, black = RGB(222, 164, 86), RGB(250, 240, 225), RGB(20, 20, 20)
	for _, p in ipairs({ { -0.55, -0.6 }, { 0.55, -0.6 }, { -0.55, 1.2 }, { 0.55, 1.2 } }) do
		add(m, "Part", { Name = "Leg", Size = Vector3.new(0.45, 1, 0.45), CFrame = at(p[1], 0.5, p[2]), Color = fur })
	end
	add(m, "Part", { Name = "Body", Size = Vector3.new(1.6, 1.3, 2.6), CFrame = at(0, 1.6, 0.3), Color = fur })
	add(m, "Part", { Name = "Head", Size = Vector3.new(1.8, 1.6, 1.7), CFrame = at(0, 2.8, -1.2), Color = fur })
	add(m, "Part", { Name = "Cheeks", Size = Vector3.new(1.85, 0.55, 1.0), CFrame = at(0, 2.3, -1.6), Color = white })
	add(m, "Part", { Name = "Snout", Size = Vector3.new(1.0, 0.7, 0.7), CFrame = at(0, 2.45, -2.3), Color = white })
	add(m, "Part", { Name = "Nose", Size = Vector3.new(0.4, 0.3, 0.2), CFrame = at(0, 2.72, -2.68), Color = black })
	add(m, "Part", { Name = "Glasses", Size = Vector3.new(1.7, 0.35, 0.12), CFrame = at(0, 3.05, -2.1), Color = black })
	add(m, "WedgePart", { Name = "LeftEar", Size = Vector3.new(0.5, 0.7, 0.5), CFrame = at(-0.6, 3.95, -1.0), Color = fur })
	add(m, "WedgePart", { Name = "RightEar", Size = Vector3.new(0.5, 0.7, 0.5), CFrame = at(0.6, 3.95, -1.0), Color = fur })
	-- el bate del bonk
	add(m, "Part", { Name = "Bat", Size = Vector3.new(0.35, 2.6, 0.35), CFrame = at(1.1, 2.6, -1.0, 0, 0, -35), Color = RGB(150, 100, 60) })
end

Builders.GatoArcoiris = function(m)
	local grey, tan, pink = RGB(150, 150, 155), RGB(240, 190, 130), RGB(255, 150, 210)
	add(m, "Part", { Name = "Pastry", Size = Vector3.new(0.8, 1.6, 2.2), CFrame = at(0, 2, 0), Color = tan })
	add(m, "Part", { Name = "Frosting", Size = Vector3.new(0.9, 1.3, 1.9), CFrame = at(0, 2, 0), Color = pink })
	add(m, "Part", { Name = "Head", Size = Vector3.new(0.9, 1.0, 1.1), CFrame = at(0, 1.85, -1.45), Color = grey })
	add(m, "WedgePart", { Name = "LeftEar", Size = Vector3.new(0.25, 0.35, 0.3), CFrame = at(-0.3, 2.52, -1.5), Color = grey })
	add(m, "WedgePart", { Name = "RightEar", Size = Vector3.new(0.25, 0.35, 0.3), CFrame = at(0.3, 2.52, -1.5), Color = grey })
	for _, p in ipairs({ { -0.25, -0.8 }, { 0.25, -0.8 }, { -0.25, 0.8 }, { 0.25, 0.8 } }) do
		add(m, "Part", { Name = "Paw", Size = Vector3.new(0.25, 0.35, 0.25), CFrame = at(p[1], 1.05, p[2]), Color = grey })
	end
	local rainbow = { RGB(255, 60, 60), RGB(255, 160, 40), RGB(255, 235, 50), RGB(70, 220, 90), RGB(60, 150, 255), RGB(160, 80, 255) }
	for i, color in ipairs(rainbow) do
		add(m, "Part", { Name = "Rainbow", Size = Vector3.new(0.15, 0.22, 3.0), CFrame = at(0, 2.55 - (i - 1) * 0.22, 2.6), Color = color, Material = NEON })
	end
end

Builders.GigaChad = function(m)
	local skin, hair, shorts = RGB(205, 205, 205), RGB(40, 40, 40), RGB(30, 30, 30)
	add(m, "Part", { Name = "LeftLeg", Size = Vector3.new(0.9, 2.1, 1), CFrame = at(-0.55, 1.05, 0), Color = shorts })
	add(m, "Part", { Name = "RightLeg", Size = Vector3.new(0.9, 2.1, 1), CFrame = at(0.55, 1.05, 0), Color = shorts })
	add(m, "Part", { Name = "Waist", Size = Vector3.new(2.6, 2.0, 1.3), CFrame = at(0, 3.2, 0), Color = skin })
	add(m, "Part", { Name = "Chest", Size = Vector3.new(3.4, 0.9, 1.4), CFrame = at(0, 3.85, 0), Color = skin })
	add(m, "Part", { Name = "LeftShoulder", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = at(-1.75, 4.0, 0), Color = skin })
	add(m, "Part", { Name = "RightShoulder", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = at(1.75, 4.0, 0), Color = skin })
	add(m, "Part", { Name = "LeftArm", Size = Vector3.new(0.9, 2.1, 0.95), CFrame = at(-1.9, 2.85, 0), Color = skin })
	add(m, "Part", { Name = "RightArm", Size = Vector3.new(0.9, 2.1, 0.95), CFrame = at(1.9, 2.85, 0), Color = skin })
	add(m, "Part", { Name = "Neck", Size = Vector3.new(1.0, 0.5, 0.9), CFrame = at(0, 4.5, 0), Color = skin })
	add(m, "Part", { Name = "Head", Size = Vector3.new(1.3, 1.5, 1.25), CFrame = at(0, 5.45, 0), Color = skin })
	add(m, "Part", { Name = "Jaw", Size = Vector3.new(1.5, 0.65, 1.35), CFrame = at(0, 4.95, -0.05), Color = skin })
	add(m, "Part", { Name = "Hair", Size = Vector3.new(1.35, 0.45, 1.3), CFrame = at(0, 6.3, 0.03), Color = hair })
	add(m, "Part", { Name = "Brow", Size = Vector3.new(1.0, 0.12, 0.05), CFrame = at(0, 5.8, -0.64), Color = hair })
end

Builders.Moai = function(m)
	local stone, dark = RGB(128, 124, 118), RGB(70, 66, 62)
	add(m, "Part", { Name = "Body", Size = Vector3.new(2.6, 1.6, 2.0), CFrame = at(0, 0.8, 0), Color = stone, Material = SLATE })
	add(m, "Part", { Name = "Head", Size = Vector3.new(2.0, 3.4, 1.8), CFrame = at(0, 3.3, 0), Color = stone, Material = SLATE })
	add(m, "Part", { Name = "Brow", Size = Vector3.new(2.1, 0.45, 0.5), CFrame = at(0, 4.25, -0.95), Color = stone, Material = SLATE })
	add(m, "WedgePart", { Name = "Nose", Size = Vector3.new(0.7, 1.5, 0.7), CFrame = at(0, 3.35, -1.2), Color = stone, Material = SLATE })
	add(m, "Part", { Name = "Lips", Size = Vector3.new(1.0, 0.3, 0.25), CFrame = at(0, 2.35, -0.95), Color = dark, Material = SLATE })
	add(m, "Part", { Name = "LeftEye", Size = Vector3.new(0.55, 0.18, 0.1), CFrame = at(-0.5, 3.85, -0.92), Color = dark })
	add(m, "Part", { Name = "RightEye", Size = Vector3.new(0.55, 0.18, 0.1), CFrame = at(0.5, 3.85, -0.92), Color = dark })
end

Builders.OgroPantano = function(m)
	local green, vest, shirt, brown = RGB(140, 175, 60), RGB(90, 60, 35), RGB(225, 215, 190), RGB(110, 80, 50)
	add(m, "Part", { Name = "LeftLeg", Size = Vector3.new(1.1, 2, 1.1), CFrame = at(-0.6, 1, 0), Color = brown })
	add(m, "Part", { Name = "RightLeg", Size = Vector3.new(1.1, 2, 1.1), CFrame = at(0.6, 1, 0), Color = brown })
	add(m, "Part", { Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 2.4), CFrame = at(0, 3.2, 0), Color = shirt })
	add(m, "Part", { Name = "Vest", Size = Vector3.new(3.1, 2.2, 1.5), CFrame = at(0, 3.4, 0.4), Color = vest })
	add(m, "Part", { Name = "LeftArm", Size = Vector3.new(1, 2.2, 1), CFrame = at(-2, 3.2, 0), Color = green })
	add(m, "Part", { Name = "RightArm", Size = Vector3.new(1, 2.2, 1), CFrame = at(2, 3.2, 0), Color = green })
	add(m, "Part", { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.9, 1.9, 1.9), CFrame = at(0, 5.4, 0), Color = green })
	vcyl(m, "LeftEarStalk", 0.6, 0.35, -0.95, 6.0, 0, green, { CFrame = at(-0.95, 6.0, 0, 0, 0, 0) })
	vcyl(m, "RightEarStalk", 0.6, 0.35, 0.95, 6.0, 0, green, { CFrame = at(0.95, 6.0, 0, 0, 0, 0) })
	add(m, "Part", { Name = "LeftEye", Size = Vector3.new(0.25, 0.25, 0.1), CFrame = at(-0.35, 5.6, -0.92), Color = RGB(20, 20, 20) })
	add(m, "Part", { Name = "RightEye", Size = Vector3.new(0.25, 0.25, 0.1), CFrame = at(0.35, 5.6, -0.92), Color = RGB(20, 20, 20) })
end

Builders.ChicoTienda = function(m)
	-- dependiente con uniforme rojo y amarillo del MemeMarket (diseño original)
	local head = humanoidBody(m, RGB(204, 142, 105), RGB(220, 30, 40), RGB(40, 40, 50))
	face(head, "rbxasset://textures/face.png")
	add(m, "Part", { Name = "Stripe", Size = Vector3.new(2.05, 0.35, 1.05), CFrame = at(0, 3.3, 0), Color = RGB(255, 200, 0) })
	add(m, "Part", { Name = "Cap", Size = Vector3.new(1.4, 0.35, 1.4), CFrame = at(0, 5.15, 0), Color = RGB(220, 30, 40) })
	add(m, "Part", { Name = "Visor", Size = Vector3.new(1.2, 0.12, 0.7), CFrame = at(0, 5.0, -0.9), Color = RGB(255, 200, 0) })
end

Builders.HeroeCalvo = function(m)
	local head = humanoidBody(m, RGB(250, 215, 175), RGB(70, 80, 110), RGB(70, 80, 110))
	face(head, "rbxasset://textures/face.png")
	add(m, "Part", { Name = "LeftGlove", Size = Vector3.new(1.15, 0.8, 1.15), CFrame = at(-1.5, 2.2, 0), Color = RGB(230, 60, 40) })
	add(m, "Part", { Name = "RightGlove", Size = Vector3.new(1.15, 0.8, 1.15), CFrame = at(1.5, 2.2, 0), Color = RGB(230, 60, 40) })
	add(m, "Part", { Name = "Belt", Size = Vector3.new(2.05, 0.3, 1.05), CFrame = at(0, 2.15, 0), Color = RGB(20, 20, 20) })
end

Builders.Stonks = function(m)
	local head = humanoidBody(m, RGB(230, 200, 170), RGB(30, 40, 80), RGB(30, 30, 40))
	face(head, "rbxasset://textures/face.png")
	add(m, "Part", { Name = "Tie", Size = Vector3.new(0.35, 1.4, 0.1), CFrame = at(0, 3.1, -0.55), Color = RGB(200, 30, 30) })
	-- flecha "stonks" hacia arriba
	add(m, "Part", { Name = "Arrow", Size = Vector3.new(0.4, 4, 0.4), CFrame = at(2.4, 4, 0, 0, 0, -30), Color = RGB(60, 220, 90), Material = NEON })
end

local function fromCustom(id: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("MemeModels")
	local source = folder and folder:FindFirstChild(id)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local clone = source:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy() -- un modelo de exhibición nunca ejecuta código
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	return clone
end

function MemeModels.Has(id: string): boolean
	return Builders[id] ~= nil or fromCustom(id) ~= nil
end

-- Devuelve un Model nuevo (sin Parent) o nil si el meme no tiene modelo.
function MemeModels.Build(id: string): Model?
	local custom = fromCustom(id)
	if custom then
		return custom
	end
	local builder = Builders[id]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	local ok, err = pcall(builder, model)
	if not ok then
		warn(("[MemeGame] No se pudo construir el modelo '%s': %s"):format(id, tostring(err)))
		model:Destroy()
		return nil
	end
	return model
end

return MemeModels
