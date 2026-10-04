--[[
	MemeGame • Teleport (ModuleScript)
	ServerScriptService > MemeGameServer > Systems > Teleport

	Mueve físicamente a los personajes (lobby ↔ cabina ↔ mapa) y controla dónde reaparecen.
	También prepara el teletransporte real entre places (TeleportService) para cuando un mapa
	tenga PlaceId propio en el juego publicado.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local WorldBuilder = require(script.Parent.WorldBuilder)

local Teleport = {}

local respawnResolver: ((Player) -> CFrame?)? = nil

local function getHumanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- Coloca al personaje en un CFrame (si está vivo).
function Teleport.To(player: Player, cf: CFrame): boolean
	local char = player.Character
	local hum = getHumanoid(player)
	if not char or not hum or hum.Health <= 0 or not char.PrimaryPart then
		return false
	end
	hum.Sit = false
	char:PivotTo(cf)
	local root = char.PrimaryPart
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

function Teleport.ToLobby(player: Player): boolean
	local cf = WorldBuilder.GetSpawnCFrame()
	local jitter = Vector3.new(math.random(-5, 5), 0, math.random(-3, 3))
	return Teleport.To(player, cf + jitter)
end

-- Congela/descongela el movimiento (cuenta regresiva de cabina).
function Teleport.Freeze(player: Player, frozen: boolean)
	local hum = getHumanoid(player)
	if not hum then
		return
	end
	if frozen then
		if hum:GetAttribute("BaseWalkSpeed") == nil then
			hum:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
			hum:SetAttribute("BaseJumpHeight", hum.JumpHeight)
			hum:SetAttribute("BaseJumpPower", hum.JumpPower)
		end
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
		hum.JumpPower = 0
	else
		Teleport.ResetMovement(player)
	end
end

-- Devuelve velocidad y salto a sus valores base (tras congelar o tras habilidades).
function Teleport.ResetMovement(player: Player)
	local hum = getHumanoid(player)
	if not hum then
		return
	end
	local ws = hum:GetAttribute("BaseWalkSpeed")
	if ws ~= nil then
		hum.WalkSpeed = ws
		hum.JumpHeight = hum:GetAttribute("BaseJumpHeight")
		hum.JumpPower = hum:GetAttribute("BaseJumpPower")
		hum:SetAttribute("BaseWalkSpeed", nil)
		hum:SetAttribute("BaseJumpHeight", nil)
		hum:SetAttribute("BaseJumpPower", nil)
	end
end

-- Lo usa MatchService para que, si mueres en partida, reaparezcas en el mapa.
function Teleport.SetRespawnResolver(fn: (Player) -> CFrame?)
	respawnResolver = fn
end

-- Teletransporte real a otro place (solo funciona en el juego publicado).
function Teleport.ToPlace(placeId: number, players: { Player }, teleportData: any): (boolean, string?)
	if RunService:IsStudio() then
		return false, "TeleportService no funciona en Studio"
	end
	local okReserve, code = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)
	if not okReserve then
		return false, tostring(code)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(teleportData)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, players, options)
	end)
	return ok, if ok then nil else tostring(err)
end

local function onCharacterAdded(player: Player, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.1)
	local target = respawnResolver and respawnResolver(player)
	if target then
		Teleport.To(player, target)
		return
	end
	-- Si el place tiene otros SpawnLocations, nos aseguramos de aparecer en el lobby del juego.
	local lobby = WorldBuilder.GetSpawnCFrame()
	if (root.Position - lobby.Position).Magnitude > 120 then
		Teleport.ToLobby(player)
	end
end

function Teleport.Init()
	local function setup(player: Player)
		player:SetAttribute("GameState", "Lobby")
		local spawnLocation = WorldBuilder.GetSpawnLocation()
		if spawnLocation then
			player.RespawnLocation = spawnLocation
		end
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end
end

return Teleport
