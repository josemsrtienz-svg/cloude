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
local Rods = require(Root.Config.Rods)
local Inventory = require(Root.Shared.Inventory)
local GearModels = require(Root.Shared.GearModels)

local PlayerData = require(script.Parent.PlayerData)

local GearService = {}

local TOOL_NAME = GameConfig.RodToolName
GearService.ToolName = TOOL_NAME
local ROD_GRIP = CFrame.new(0, 0, 0)

local packSignature: { [Player]: string } = {}

-- ===== Caña (Tool) =====

local function buildTool(rod: any, broken: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = rod.Name .. " · " .. rod.Capacity .. " kg" .. (if broken then " (ROTA)" else "")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = ROD_GRIP
	tool:SetAttribute("RodId", rod.Id)
	-- el mismo modelo que se ve en la tienda; el Handle es la pieza principal
	local model = GearModels.Rod(rod, broken)
	local handle = model.PrimaryPart :: BasePart
	handle.Anchored = false
	for _, child in ipairs(model:GetChildren()) do
		child.Parent = tool
	end
	model:Destroy()
	for _, d in ipairs(tool:GetChildren()) do
		if d:IsA("BasePart") and d ~= handle then
			d.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = d
			w.Parent = d
		end
	end
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

-- ===== Mochila-acuario (visual en la espalda, con mini memes dentro) =====

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
	local signature = tier.Tier .. "|" .. table.concat(ids, ",")
	local old = character:FindFirstChild("AquariumPack")
	if old and packSignature[player] == signature then
		return
	end
	if old then
		old:Destroy()
	end
	packSignature[player] = signature

	local pack = GearModels.Tank(tier, ids)
	pack.Name = "AquariumPack"
	pack:PivotTo(torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z / 2 + 0.65))
	GearModels.WeldTo(pack, torso)
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
