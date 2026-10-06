--[[
	PescaDeMemes • GearService (ModuleScript, servidor)
	ServerScriptService > PescaServer > Systems > GearService

	Lo que lleva encima el jugador:
	  · La CAÑA como herramienta ("Caña") en la barra de abajo: se saca y se guarda con 1.
	    Solo se puede pescar con ella en la mano. Su color y capacidad dependen de la caña equipada.
	  · La MOCHILA-ACUARIO a la espalda: tanque de cristal con los memes pescados dentro (visual).
	    La capacidad real está en los datos (Inventory.Capacity), no en el tamaño del modelo.
	Si la orientación de la caña en la mano no te gusta, ajusta ROD_GRIP.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Memes = require(Root.Config.Memes)
local Rods = require(Root.Config.Rods)
local Inventory = require(Root.Shared.Inventory)

local PlayerData = require(script.Parent.PlayerData)

local GearService = {}

local TOOL_NAME = GameConfig.RodToolName
GearService.ToolName = TOOL_NAME
local ROD_LENGTH = 6.5
local ROD_TILT = math.rad(35) -- la caña sale hacia delante y hacia arriba
local ROD_GRIP = CFrame.new(0, 0, 0)

local packSignature: { [Player]: string } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- ===== Caña (Tool) =====

local function buildTool(rod: any, broken: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = rod.Name .. " · " .. rod.Capacity .. " kg" .. (if broken then " (ROTA)" else "")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = ROD_GRIP
	tool:SetAttribute("RodId", rod.Id)

	local handle = part({ Name = "Handle", Size = Vector3.new(0.35, 0.35, 1.4), Color = Color3.fromRGB(40, 32, 30),
		Material = Enum.Material.Fabric })
	handle.Parent = tool
	-- el eje de la caña: hacia -Z (delante) e inclinada hacia arriba
	local axis = handle.CFrame * CFrame.Angles(ROD_TILT, 0, 0)
	local shaft = part({ Name = "Shaft", Size = Vector3.new(0.16, 0.16, ROD_LENGTH), Color = rod.Color,
		Material = Enum.Material.SmoothPlastic, CFrame = axis * CFrame.new(0, 0, -ROD_LENGTH / 2 - 0.5) })
	shaft.Parent = tool
	weld(handle, shaft)
	local reel = part({ Name = "Reel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.6, 0.6),
		Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, CFrame = handle.CFrame * CFrame.new(0, -0.35, -0.3) })
	reel.Parent = tool
	weld(handle, reel)
	for i = 1, 3 do
		local guide = part({ Name = "Guide", Size = Vector3.new(0.22, 0.22, 0.1), Color = Color3.fromRGB(220, 220, 220),
			Material = Enum.Material.Metal, CFrame = axis * CFrame.new(0, 0.12, -0.5 - i * ROD_LENGTH / 4) })
		guide.Parent = tool
		weld(handle, guide)
	end
	if broken then
		shaft.Color = Color3.fromRGB(90, 70, 60)
		shaft.Size = Vector3.new(0.16, 0.16, ROD_LENGTH * 0.5)
	end
	local tip = Instance.new("Attachment")
	tip.Name = "RodTip"
	tip.Position = Vector3.new(0, 0, -shaft.Size.Z / 2)
	tip.Parent = shaft
	return tool
end

local function giveRod(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local rod = Rods.Get(data.EquippedRod) or Rods.List[1]
	local broken = data.BrokenRods[rod.Id] == true
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local wasEquipped = false
	for _, container in ipairs({ backpack, character }) do
		if container then
			local old = container:FindFirstChild(TOOL_NAME)
			if old then
				wasEquipped = wasEquipped or old.Parent == character
				old:Destroy()
			end
		end
	end
	if not backpack then
		return
	end
	local tool = buildTool(rod, broken)
	if wasEquipped and character then
		tool.Parent = character
	else
		tool.Parent = backpack
	end
end

-- ===== Mochila-acuario (visual en la espalda) =====

local function buildPack(player: Player)
	local character = player.Character
	local data = PlayerData.Get(player)
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not character or not data or not torso then
		return
	end
	local aquarium = Inventory.Aquarium(data)
	local tier = Rods.GetAquarium(data.AquariumTier) or Rods.Aquariums[1]
	local ids = {}
	for i = 1, math.min(3, #aquarium) do
		ids[i] = aquarium[i].MemeId
	end
	local signature = tier.Tier .. "|" .. table.concat(ids, ",") .. "|" .. #aquarium
	local old = character:FindFirstChild("AquariumPack")
	if old and packSignature[player] == signature then
		return
	end
	if old then
		old:Destroy()
	end
	packSignature[player] = signature

	local pack = Instance.new("Model")
	pack.Name = "AquariumPack"
	local back = torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z / 2 + 0.65)
	local function add(p: BasePart, offset: CFrame)
		p.CFrame = back * offset
		p.Parent = pack
		weld(torso, p)
	end
	add(part({ Name = "Glass", Size = Vector3.new(1.9, 2.2, 1.1), Color = Color3.fromRGB(200, 240, 255),
		Material = Enum.Material.Glass, Transparency = 0.55 }), CFrame.new())
	add(part({ Name = "Water", Size = Vector3.new(1.75, 1.6, 0.95), Color = Color3.fromRGB(60, 170, 230),
		Material = Enum.Material.SmoothPlastic, Transparency = 0.5 }), CFrame.new(0, -0.25, 0))
	add(part({ Name = "Sand", Size = Vector3.new(1.75, 0.2, 0.95), Color = Color3.fromRGB(235, 215, 160),
		Material = Enum.Material.Sand }), CFrame.new(0, -0.95, 0))
	add(part({ Name = "Lid", Size = Vector3.new(2.05, 0.25, 1.25), Color = tier.Color }), CFrame.new(0, 1.2, 0))
	add(part({ Name = "Bottom", Size = Vector3.new(2.05, 0.25, 1.25), Color = tier.Color }), CFrame.new(0, -1.2, 0))
	for _, x in ipairs({ -0.97, 0.97 }) do
		add(part({ Name = "Frame", Size = Vector3.new(0.12, 2.2, 1.2), Color = tier.Color }), CFrame.new(x, 0, 0))
		add(part({ Name = "Strap", Size = Vector3.new(0.25, 0.15, 1.6), Color = Color3.fromRGB(60, 45, 35),
			Material = Enum.Material.Fabric }), CFrame.new(x * 0.55, 1.1, -0.8))
	end
	add(part({ Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.18, Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Glass, Transparency = 0.3 }), CFrame.new(0.5, 0.4, -0.3))

	local water = pack:FindFirstChild("Water") :: BasePart
	for i, memeId in ipairs(ids) do
		local meme = Memes.Get(memeId)
		if meme then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(0.9, 0.9)
			bb.StudsOffsetWorldSpace = Vector3.new(-0.55 + (i - 1) * 0.55, (i % 2) * 0.35 - 0.1, 0)
			bb.MaxDistance = 60
			bb.LightInfluence = 0
			bb.Parent = water
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.TextScaled = true
			label.Text = meme.Emoji
			label.Parent = bb
		end
	end
	pack.Parent = character
end

function GearService.Refresh(player: Player)
	giveRod(player)
	buildPack(player)
end

function GearService.RefreshPack(player: Player)
	buildPack(player)
end

function GearService.Init()
	local function onCharacter(player: Player, character: Model)
		character:WaitForChild("Humanoid")
		packSignature[player] = nil
		task.wait(0.3) -- deja que el avatar termine de montarse
		if player.Character == character and PlayerData.IsLoaded(player) then
			GearService.Refresh(player)
		end
	end
	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		packSignature[player] = nil
	end)
	-- si los datos llegan después que el personaje, la caña y la mochila aparecen al cargar
	PlayerData.Loaded:Connect(function(player)
		if player.Character then
			GearService.Refresh(player)
		end
	end)
	-- la mochila se actualiza cuando cambian las capturas (solo si de verdad cambió algo)
	PlayerData.Changed:Connect(function(player)
		buildPack(player)
	end)
end

return GearService
